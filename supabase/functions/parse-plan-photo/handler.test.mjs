import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from './handler.ts';

const market = '11111111-1111-4111-8111-111111111111';
const azure = 'https://example.cognitiveservices.azure.com';
const operation = `${azure}/documentintelligence/documentModels/prebuilt-layout/analyzeResults/1234?api-version=2024-11-30`;
const image = new Uint8Array([255, 216, 255, 0]);
const json = (body, status = 200) => new Response(JSON.stringify(body), { status });
const env = {
  SUPABASE_URL: 'https://example.supabase.co', SUPABASE_ANON_KEY: 'public-test-key',
  AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT: azure, AZURE_DOCUMENT_INTELLIGENCE_KEY: 'private-test-key',
};
function request({ headers = {}, body = image, method = 'POST' } = {}) {
  return new Request('https://example.supabase.co/functions/v1/parse-plan-photo', {
    method, headers: { authorization: 'Bearer user-token', 'x-market-id': market, ...headers },
    body: method === 'POST' ? body : undefined,
  });
}
function harness({ customEnv = {}, userStatus = 200, level = 'editor', targetMarket = market, start, result } = {}) {
  const calls = [];
  const handler = createHandler({
    env: (name) => ({ ...env, ...customEnv })[name],
    sleep: async () => {},
    fetch: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith('/auth/v1/user')) return json({ id: 'user-id' }, userStatus);
      if (url.endsWith('/rest/v1/rpc/current_market_access')) return json([{ market_id: targetMarket, access_level: level }]);
      if (url.includes(':analyze?')) return start?.() ?? new Response(null, { status: 202, headers: { 'operation-location': operation } });
      if (url === operation) return result?.() ?? json({ status: 'succeeded', analyzeResult: {
        content: 'KW 41 / 2026', pages: [{ words: ['unused'] }],
        tables: [{ cells: [{ rowIndex: 0, columnIndex: 0, content: 'Name', boundingRegions: ['unused'] }] }],
      } });
      throw new Error(`Unexpected request: ${url}`);
    },
  });
  return { handler, calls };
}

test('authorized editor sends image to Layout and returns a minimal result', async () => {
  const { handler, calls } = harness();
  const response = await handler(request());
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body, { content: 'KW 41 / 2026', tables: [{ cells: [{ rowIndex: 0, columnIndex: 0, content: 'Name' }] }] });
  const start = calls.find((call) => call.url.includes(':analyze?'));
  assert.equal(start.options.headers['Ocp-Apim-Subscription-Key'], env.AZURE_DOCUMENT_INTELLIGENCE_KEY);
  assert.deepEqual(JSON.parse(start.options.body), { base64Source: Buffer.from(image).toString('base64') });
  assert.equal(calls[1].options.headers.authorization, 'Bearer user-token');
  assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('missing/expired login, viewer and other market never reach Azure', async () => {
  for (const [settings, expected] of [[{ userStatus: 401 }, 401], [{ level: 'viewer' }, 403], [{ targetMarket: 'another-market' }, 403]]) {
    const { handler, calls } = harness(settings);
    assert.equal((await handler(request())).status, expected);
    assert.equal(calls.some((call) => call.url.startsWith(azure)), false);
  }
  const { handler, calls } = harness();
  assert.equal((await handler(request({ headers: { authorization: '' } }))).status, 401);
  assert.equal(calls.length, 0);
});

test('wrong file type and oversized uploads never reach Azure', async () => {
  for (const [body, expected] of [[new TextEncoder().encode('<script>'), 415], [new Uint8Array(4 * 1024 * 1024 + 1), 413]]) {
    const { handler, calls } = harness();
    assert.equal((await handler(request({ body }))).status, expected);
    assert.equal(calls.some((call) => call.url.startsWith(azure)), false);
  }
});

test('unconfigured service explains setup and does not upload', async () => {
  const { handler, calls } = harness({ customEnv: { AZURE_DOCUMENT_INTELLIGENCE_KEY: '' } });
  assert.equal((await handler(request())).status, 503);
  assert.equal(calls.some((call) => call.url.startsWith(azure)), false);
});

test('operation URL cannot forward the Azure key to another host', async () => {
  const { handler, calls } = harness({ start: () => new Response(null, { status: 202, headers: { 'operation-location': 'https://untrusted.invalid/leak' } }) });
  assert.equal((await handler(request())).status, 502);
  assert.equal(calls.length, 3);
});

test('quota and no-table results return actionable errors without secret details', async () => {
  const quota = harness({ start: () => json({ internal: 'private-test-key' }, 429) });
  const response = await quota.handler(request());
  assert.equal(response.status, 429);
  assert.equal((await response.text()).includes('private-test-key'), false);
  const empty = harness({ result: () => json({ status: 'succeeded', analyzeResult: {} }) });
  assert.equal((await empty.handler(request())).status, 422);
});

test('running requests are polled, failures and preflight are handled', async () => {
  let polls = 0;
  const running = harness({ result: () => json(++polls === 1 ? { status: 'running' } : { status: 'succeeded', analyzeResult: { tables: [] } }) });
  assert.equal((await running.handler(request())).status, 200);
  assert.equal(polls, 2);
  const failed = harness({ result: () => json({ status: 'failed' }) });
  assert.equal((await failed.handler(request())).status, 422);
  const preflight = harness();
  const response = await preflight.handler(request({ method: 'OPTIONS' }));
  assert.equal(response.status, 200);
  assert.ok(response.headers.get('access-control-allow-headers').includes('x-market-id'));
  assert.equal(preflight.calls.length, 0);
});
