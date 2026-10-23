// Execute the shipped worker with real Fetch responses from a redirecting host.
// This verifies redirect metadata and lifecycle behavior, not an Android install.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import vm from 'node:vm';
const server = http.createServer((request, response) => {
  if (request.url === '/index.html' || request.url === '/index.offline.html') {
    response.writeHead(307, {Location: request.url === '/index.html' ? '/' : '/index.offline'}).end();
  } else if (request.url === '/' || request.url === '/index.offline') {
    response.writeHead(200, {'Content-Type': 'text/html'}).end('<title>CROWNFIELD</title>');
  } else {
    response.writeHead(200, {'Content-Type': 'application/octet-stream'}).end('asset');
  }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
try {
  const redirected = await fetch(origin + '/index.html');
  assert.equal(redirected.redirected, true, 'production-like redirect keeps its Fetch metadata');
  const events = {}, storage = new Map();
  const key = request => typeof request === 'string' ? new URL(request, origin).href : request.url;
  let offline = false, denied = false, authRedirect = false, claims = 0, skips = 0;
  const caches = {
    async open(name) {
      if (!storage.has(name)) storage.set(name, new Map());
      const entries = storage.get(name);
      return {
        async put(request, response) { entries.set(key(request), response.clone()); },
        async match(request) { return entries.get(key(request))?.clone(); },
        async addAll(requests) {
          for (const request of requests) {
            const response = await network(request);
            if (!response.ok) throw new Error('precache failed');
            entries.set(key(request), response.clone());
          }
        }
      };
    },
    async keys() { return [...storage.keys()]; },
    async delete(name) { return storage.delete(name); }
  };
  async function network(request) {
    if (offline) throw new TypeError('offline');
    if (denied) return new Response('denied', {status: 403});
    if (authRedirect) {
      const response = new Response('<title>Sign in</title>', {headers: {'Content-Type': 'text/html'}});
      Object.defineProperty(response, 'url', {value: origin + '/login'});
      return response;
    }
    return fetch(request instanceof Request ? request : key(request));
  }
  vm.runInNewContext(fs.readFileSync(new URL('../builds/web/index.service.worker.js', import.meta.url), 'utf8'), {
    URL, Request, Response, Set, caches, fetch: network,
    self: {registration: {scope: origin + '/'}, addEventListener(type, handler) { events[type] = handler; },
      clients: {async claim() { claims++; }, async get() { return {}; }}, async skipWaiting() { skips++; }}
  });
  async function lifecycle(type) {
    const pending = [];
    events[type]({waitUntil(promise) { pending.push(promise); }});
    await Promise.all(pending);
  }
  async function request(path, options = {}) {
    let result;
    const pending = [];
    events.fetch({request: {url: new URL(path, origin).href, method: 'GET', mode: 'navigate', redirect: 'manual', referrer: '', ...options},
      respondWith(promise) { result = promise; }, waitUntil(promise) { pending.push(promise); }});
    const response = await result;
    await Promise.all(pending);
    return response;
  }
  await lifecycle('install');
  assert.equal(skips, 0, 'install never interrupts another game');
  const current = (await caches.keys())[0];
  const cache = await caches.open(current);
  assert.equal((await cache.match(origin + '/')).redirected, false);
  assert.equal(await cache.match(origin + '/index.html'), undefined);
  assert.equal((await cache.match(origin + '/index.offline.html')).redirected, true);
  offline = true;
  for (const path of ['/', '/index.html', '/?v=recovery']) {
    const response = await request(path);
    assert.equal(response.status, 200);
    assert.equal(response.redirected, false, 'manual navigation must never replay followed redirects');
    assert.match(await response.text(), /CROWNFIELD/);
  }
  assert.equal((await request('/index.icon.png', {mode: 'no-cors'})).status, 200, 'cold asset request needs no referrer');
  assert.equal(await request('/login'), undefined);
  assert.equal(await request('https://other.example/'), undefined);
  assert.equal(await request('/', {method: 'POST'}), undefined);
  // An old redirected response is safe even if it ends up under the home key.
  await cache.put(origin + '/', redirected);
  assert.equal((await request('/index.html')).redirected, false);
  storage.get(current).delete(origin + '/');
  assert.equal((await request('/index.html')).redirected, false, 'offline fallback is also navigation-safe');
  storage.get(current).delete(origin + '/index.offline.html');
  assert.equal((await request('/index.html')).status, 503, 'empty cache produces a response, never undefined');
  offline = false; denied = true;
  const source = fs.readFileSync(new URL('../builds/web/index.service.worker.js', import.meta.url), 'utf8');
  const engine = JSON.parse(source.match(/const CACHEABLE_FILES = (\[.*?\]);/)[1])[0];
  assert.equal((await request('/' + engine, {mode: 'cors'})).status, 403);
  assert.equal(await cache.match(origin + '/' + engine), undefined, 'error responses are not cached');
  storage.set('another-app', new Map());
  await assert.rejects(lifecycle('install'), /entry page is unavailable/);
  assert.equal(storage.has(current), false, 'failed installation removes its partial cache');
  denied = false; authRedirect = true;
  await assert.rejects(lifecycle('install'), /entry page is unavailable/, 'sign-in HTML must not replace the game');
  authRedirect = false;
  await lifecycle('install');
  storage.set('CROWNFIELD — 四国の-sw-cache-old', new Map());
  await lifecycle('activate');
  assert.equal(storage.has('another-app'), true);
  assert.equal(storage.has('CROWNFIELD — 四国の-sw-cache-old'), false);
  assert.equal(claims, 1);
  console.log('PWA worker: real HTTP redirects, cold installed launch, canonical/legacy URLs, offline fallback, auth failures and cache lifecycle passed.');
} finally {
  server.closeAllConnections();
  await new Promise(resolve => server.close(resolve));
}
