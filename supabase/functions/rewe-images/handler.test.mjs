import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from './handler.mjs';

const request = (params, init) => new Request(`https://example.test/rewe-images?${new URLSearchParams(params)}`, init);

test('CORS preflight works without fetching REWE', async () => {
  const handler = createHandler(() => assert.fail('Unexpected upstream call'));
  const response = await handler(request({}, { method: 'OPTIONS' }));
  assert.equal(response.status, 204);
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
});

test('encodes searches and forwards no client credentials', async () => {
  const handler = createHandler(async (url, options) => {
    assert.equal(url.origin, 'https://www.rewe.de');
    assert.equal(url.pathname, '/suche/uebersicht');
    assert.equal(url.searchParams.get('searchTerm'), 'Äpfel & Birnen');
    assert.equal(options.headers.Authorization, undefined);
    assert.equal(options.headers.Cookie, undefined);
    assert.equal(options.redirect, 'error');
    return new Response('<article data-product-tile></article>', { headers: { 'Content-Type': 'text/html' } });
  });
  const response = await handler(request({ query: ' Äpfel & Birnen ' }, { headers: { Authorization: 'private', Cookie: 'private' } }));
  assert.equal(response.status, 200);
  assert.match(await response.text(), /data-product-tile/);
});

test('rejects arbitrary image targets, redirects and oversized queries', async () => {
  const handler = createHandler(() => assert.fail('Unexpected upstream call'));
  for (const image of [
    'http://img.rewe-static.de/123/test.png',
    'https://img.rewe-static.de.evil.test/123/test.png',
    'https://127.0.0.1/123/test.png',
    'https://img.rewe-static.de:444/123/test.png',
    'https://name:secret@img.rewe-static.de/123/test.png',
    'https://img.rewe-static.de/123/test.svg',
    'https://img.rewe-static.de/123/test.png?imwidth=99999',
  ]) assert.equal((await handler(request({ image }))).status, 400);
  for (const params of [{}, { query: ' ' }, { query: 'a'.repeat(121) }, { query: 'Pfirsich', image: 'x' }]) {
    assert.equal((await handler(request(params))).status, 400);
  }
});

test('proxies image bytes with CORS and normalizes transform parameters', async () => {
  const bytes = new Uint8Array([137, 80, 78, 71]);
  const handler = createHandler(async (url) => {
    assert.equal(url.search, '?impolicy=s-offers&imwidth=400');
    return new Response(bytes, { headers: { 'Content-Type': 'image/png', 'Set-Cookie': 'never-forward' } });
  });
  const response = await handler(request({ image: 'https://img.rewe-static.de/3011172/40022249_digital-image.png?imwidth=400&unexpected=value' }));
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), bytes);
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
  assert.equal(response.headers.get('set-cookie'), null);
});

test('reports REWE blocks and bad responses rather than fake empty results', async () => {
  for (const status of [403, 429, 500]) {
    const response = await createHandler(async () => new Response('blocked', { status }))(request({ query: 'Pfirsich' }));
    assert.equal(response.status, status === 500 ? 502 : status);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal(response.headers.get('access-control-allow-origin'), '*');
  }
  const wrongType = createHandler(async () => new Response('html', { headers: { 'Content-Type': 'text/html' } }));
  assert.equal((await wrongType(request({ image: 'https://img.rewe-static.de/123/image.png' }))).status, 502);
  const tooLarge = createHandler(async () => new Response('html', { headers: { 'Content-Type': 'text/html', 'Content-Length': '5000000' } }));
  assert.equal((await tooLarge(request({ query: 'Pfirsich' }))).status, 502);
  const timeout = createHandler(async () => { throw new Error('timeout'); });
  assert.equal((await timeout(request({ query: 'Pfirsich' }))).status, 502);
});
