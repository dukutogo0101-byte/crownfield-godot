/* Constants come from prepare_web.py; keep the registration URL stable. */
const CACHE_VERSION = __CACHE_VERSION__;
const CACHE_PREFIX = 'CROWNFIELD — 四国の-sw-cache-';
const CACHE_NAME = CACHE_PREFIX + CACHE_VERSION;
const CACHED_FILES = __CACHED_FILES__;
const CACHEABLE_FILES = __CACHEABLE_FILES__;
const scope = new URL(self.registration.scope);
const absolute = path => new URL(path, scope).href;
const home = absolute('./');
const assets = new Set([...CACHED_FILES, ...CACHEABLE_FILES].map(absolute));

// A cached followed redirect cannot be replayed for a manual-mode navigation.
// Accept only our actual entry page, never a redirected sign-in page.
const isEntry = response => response.ok && response.url === home &&
  response.headers.get('Content-Type')?.includes('text/html');
const navigationResponse = response => new Response(response.body, {
  status: response.status, statusText: response.statusText, headers: response.headers
});

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    try {
      // Canonical / returns 200; /index.html redirects on the production host.
      const response = await fetch(new Request(home, {credentials: 'same-origin', cache: 'reload'}));
      if (!isEntry(response)) throw new Error('Game entry page is unavailable');
      await cache.put(home, navigationResponse(response));
      await cache.addAll(CACHED_FILES.filter(path => absolute(path) !== home)
        .map(path => new Request(absolute(path), {credentials: 'same-origin', cache: 'reload'})));
    } catch (error) {
      await caches.delete(CACHE_NAME);
      throw error;
    }
    // Do not reload or replace an ongoing game's worker.
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    await Promise.all((await caches.keys()).filter(key =>
      key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});

async function navigate(request, cache) {
  // Both the new launch URL and previously installed /index.html use the same
  // non-redirected entry. A cold start has no referrer, so use registration.scope.
  const cached = await cache.match(home);
  if (cached) return navigationResponse(cached);
  try {
    // Preserve redirect mode: the browser must handle host/auth redirects itself.
    return await fetch(request);
  } catch (_) {
    const offline = await cache.match(absolute('index.offline.html'));
    if (offline) return navigationResponse(offline);
    return new Response('通信を確認して、もう一度ゲームを開いてください。', {
      status: 503, headers: {'Content-Type': 'text/plain; charset=utf-8'}
    });
  }
}

self.addEventListener('fetch', event => {
  const request = event.request, url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== scope.origin) return;
  const navigation = request.mode === 'navigate';
  const entry = url.pathname === scope.pathname || url.pathname === scope.pathname + 'index.html';
  // Leave authentication routes and unrelated navigation to the browser.
  if (navigation ? !entry : !assets.has(url.href)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    if (navigation) return navigate(request, cache);
    const cached = await cache.match(request);
    if (cached) return cached;
    const response = await fetch(request);
    if (response.ok && !response.redirected) {
      event.waitUntil(cache.put(request, response.clone()).catch(() => {}));
    }
    return response;
  })());
});

// Preserve Godot's existing worker message protocol.
self.addEventListener('message', event => {
  if (event.origin !== scope.origin || !event.source?.id) return;
  event.waitUntil((async () => {
    const client = await self.clients.get(event.source.id);
    if (!client) return;
    if (event.data === 'clear') await caches.delete(CACHE_NAME);
    if (event.data === 'claim' || event.data === 'update') {
      await self.skipWaiting();
      await self.clients.claim();
      if (event.data === 'update') {
        await Promise.all((await self.clients.matchAll()).map(client => client.navigate(client.url)));
      }
    }
  })());
});
