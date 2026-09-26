'use strict';

// Filled by generate_offline_cache.py after Flutter has built all resources.
const CACHE_PREFIX = `rewe-plu-shell-${self.registration.scope}-`;
const CACHE_NAME = CACHE_PREFIX + '__BUILD_REVISION__';
const RESOURCES = __PRECACHE_RESOURCES__;
const resourceUrls = new Set(
  RESOURCES.map((path) => new URL(path, self.registration.scope).href),
);
const indexUrl = new URL('index.html', self.registration.scope).href;

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    try {
      // Installation succeeds only when the complete app can start offline,
      // including both renderers, fonts and the SQLite worker/Wasm module.
      await cache.addAll([...resourceUrls].map(
        (url) => new Request(url, {cache: 'reload'}),
      ));
    } catch (error) {
      await caches.delete(CACHE_NAME);
      throw error;
    }
    // Let an update wait until existing app windows close. Activating it here
    // could mix the running app with resources from a different release.
  })());
});

self.addEventListener('message', (event) => {
  if (event.data?.type !== 'ACTIVATE_UPDATE' || !event.ports[0]) return;
  event.waitUntil((async () => {
    const scope = new URL(self.registration.scope);
    const belongsToApp = (client) => {
      const url = new URL(client.url);
      return url.origin === scope.origin && url.pathname.startsWith(scope.pathname);
    };
    // Only a window in this app may request activation. Other open windows
    // could contain unsaved forms or still be using the previous app version.
    if (!event.source || !belongsToApp(event.source)) return;
    const windows = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    if (windows.some((client) => client.id !== event.source.id && belongsToApp(client))) {
      event.ports[0].postMessage({ok: false, reason: 'OTHER_WINDOWS'});
      return;
    }
    await self.skipWaiting();
    event.ports[0].postMessage({ok: true});
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME) {
        await caches.delete(name);
      }
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  const scope = new URL(self.registration.scope);
  if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) {
    return;
  }
  url.search = '';
  const key = request.mode === 'navigate' ? indexUrl : url.href;
  // Never cache market/API responses or modify the product-image cache.
  if (!resourceUrls.has(key)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    return await cache.match(key) || fetch(request);
  })());
});
