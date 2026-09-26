import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const resources = ['index.html', 'main.dart.js', 'sqlite3.wasm', 'sqflite_sw.js',
  'canvaskit/canvaskit.wasm', 'canvaskit/skwasm.wasm', 'assets/fonts/Roboto.ttf'];
const scope = 'https://example.org/plu/';
const prefix = `rewe-plu-shell-${scope}-`;
const template = readFileSync(new URL('../tool/offline_service_worker.js', import.meta.url), 'utf8');

function worker({failResource, windows = [{id: 'current', url: scope}]} = {}) {
  const handlers = {};
  const storage = new Map();
  const fetched = [];
  let claimed = false;
  let activated = false;
  const context = {
    URL, Request, Set,
    self: {
      registration: {scope},
      addEventListener: (name, handler) => { handlers[name] = handler; },
      clients: {
        claim: async () => { claimed = true; },
        matchAll: async () => windows,
      },
      skipWaiting: async () => { activated = true; },
    },
    caches: {
      keys: async () => [...storage.keys()],
      delete: async (name) => storage.delete(name),
      open: async (name) => {
        if (!storage.has(name)) storage.set(name, new Map());
        const cache = storage.get(name);
        return {
          addAll: async (requests) => {
            for (const request of requests) {
              assert.equal(request.cache, 'reload');
              if (request.url.endsWith(failResource || '!')) throw new Error('Download failed');
              cache.set(request.url, `cached: ${request.url}`);
            }
          },
          match: async (key) => cache.get(key),
        };
      },
    },
    fetch: async (request) => {
      fetched.push(request.url);
      return 'network';
    },
  };
  vm.runInNewContext(template.replace('__BUILD_REVISION__', 'v2')
    .replace('__PRECACHE_RESOURCES__', JSON.stringify(resources)), context);
  return {
    storage, fetched,
    get claimed() { return claimed; },
    get activated() { return activated; },
    async message(type, source = {id: 'current', url: scope}) {
      let pending;
      let reply;
      handlers.message({
        data: {type}, source,
        ports: [{postMessage: (value) => { reply = value; }}],
        waitUntil: (promise) => { pending = promise; },
      });
      await pending;
      return reply;
    },
    lifecycle(name) {
      let pending;
      handlers[name]({waitUntil: (promise) => { pending = promise; }});
      return pending;
    },
    request(path, options = {}) {
      let response;
      handlers.fetch({
        request: {url: new URL(path, scope).href, method: 'GET', mode: 'cors', ...options},
        respondWith: (promise) => { response = promise; },
      });
      return response;
    },
  };
}

test('complete shell includes Safari, Android and SQLite resources', async () => {
  const sw = worker();
  await sw.lifecycle('install');
  for (const resource of resources) {
    assert.equal(await sw.request(resource), `cached: ${scope}${resource}`);
  }
  assert.deepEqual(sw.fetched, []);
});

test('failed install keeps previous version and removes incomplete new cache', async () => {
  const sw = worker({failResource: 'sqlite3.wasm'});
  sw.storage.set(prefix + 'v1', new Map([['data', 'old release']]));
  await assert.rejects(sw.lifecycle('install'), /Download failed/);
  assert.equal(sw.storage.has(prefix + 'v2'), false);
  assert.equal(sw.storage.get(prefix + 'v1').get('data'), 'old release');
});

test('activation only deletes older shell caches in this scope', async () => {
  const sw = worker();
  for (const name of [prefix + 'v1', 'rewe-plu-shell-https://example.org/other/-v1', 'product-images']) {
    sw.storage.set(name, new Map());
  }
  await sw.lifecycle('install');
  await sw.lifecycle('activate');
  assert.equal(sw.storage.has(prefix + 'v1'), false);
  assert.equal(sw.storage.has(prefix + 'v2'), true);
  assert.equal(sw.storage.has('product-images'), true);
  assert.equal(sw.storage.has('rewe-plu-shell-https://example.org/other/-v1'), true);
  assert.equal(sw.claimed, true);
});

test('offline navigation works at root, with queries and in subpaths', async () => {
  const sw = worker();
  await sw.lifecycle('install');
  for (const path of ['./', './?source=homescreen', 'products/123']) {
    assert.equal(await sw.request(path, {mode: 'navigate'}), `cached: ${scope}index.html`);
  }
  assert.equal(await sw.request('main.dart.js?v=2'), `cached: ${scope}main.dart.js`);
  assert.deepEqual(sw.fetched, []);
});

test('API, cross-origin, other apps and non-GET requests are not intercepted', async () => {
  const sw = worker();
  await sw.lifecycle('install');
  for (const path of ['api/products', 'https://example.supabase.co/rest/v1/products', '/other/index.html']) {
    assert.equal(sw.request(path), undefined);
  }
  assert.equal(sw.request('index.html', {method: 'POST'}), undefined);
});

test('only explicit activation from the app skips waiting', async () => {
  const sw = worker();
  await sw.lifecycle('install');
  assert.equal(sw.activated, false);
  await sw.message('UNKNOWN');
  await sw.message('ACTIVATE_UPDATE', {id: 'foreign', url: 'https://other.org/'});
  assert.equal(sw.activated, false);
  assert.equal((await sw.message('ACTIVATE_UPDATE')).ok, true);
  assert.equal(sw.activated, true);
});

test('activation protects other app windows, including uncontrolled ones', async () => {
  const sw = worker({windows: [
    {id: 'current', url: scope}, {id: 'editing', url: scope + '?tab=2'},
  ]});
  const reply = await sw.message('ACTIVATE_UPDATE');
  assert.equal(reply.reason, 'OTHER_WINDOWS');
  assert.equal(sw.activated, false);
});

test('unrelated same-origin apps do not block activation', async () => {
  const sw = worker({windows: [
    {id: 'current', url: scope}, {id: 'other-app', url: 'https://example.org/other/'},
  ]});
  assert.equal((await sw.message('ACTIVATE_UPDATE')).ok, true);
  assert.equal(sw.activated, true);
});
