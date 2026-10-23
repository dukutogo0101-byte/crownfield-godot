import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import path from 'node:path';
const root = path.resolve(import.meta.dirname, '..');
const output = path.join(root, 'builds/web');
const manifest = JSON.parse(fs.readFileSync(path.join(output, 'index.manifest.json'), 'utf8'));
assert.equal(manifest.id, './index.html');
assert.equal(manifest.start_url, './');
assert.equal(manifest.display, 'standalone');
assert.equal(manifest.orientation, 'landscape');
assert.ok(manifest.icons.some(i => i.sizes === '192x192'));
assert.ok(manifest.icons.some(i => i.sizes === '512x512'));
for (const icon of manifest.icons) {
  const bytes = fs.readFileSync(path.join(output, icon.src));
  const [width, height] = icon.sizes.split('x').map(Number);
  assert.equal(bytes.readUInt32BE(16), width);
  assert.equal(bytes.readUInt32BE(20), height);
}
const html = fs.readFileSync(path.join(output, 'index.html'), 'utf8');
// Private Sites requires the browser's authenticated cookies on its manifest
// request. A valid JSON file alone does not make that request succeed.
const manifestLink = html.match(/<link\b[^>]*rel="manifest"[^>]*>/g) || [];
assert.equal(manifestLink.length, 1);
assert.match(manifestLink[0], /crossorigin="use-credentials"/);
const manifestURL = new URL(manifestLink[0].match(/href="([^"]+)"/)[1], 'https://example.test/');
assert.equal(manifestURL.pathname, '/index.manifest.json');
const buildVersion = html.match(/window.CROWNFIELD_BUILD_VERSION="([^"]+)"/)[1];
assert.equal(manifestURL.searchParams.get('v'), buildVersion);
assert.ok(html.includes('id="app-dialog"') && html.includes('id="app-open"'));
const events = {}, elements = {}, registered = [];
let installed = false, focused = false;
for (const id of ['app-dialog','app-description','app-install','app-status','app-open','app-close','canvas']) {
  elements[id] = {hidden: false, open: false, callbacks: {}, addEventListener(k, fn) { this.callbacks[k] = fn; }, showModal() { this.open = true; }, close() { this.open = false; this.callbacks.close?.(); }, focus() { focused = true; }};
}
vm.runInNewContext(fs.readFileSync(path.join(output, 'pwa.js'), 'utf8'), {
  window: {addEventListener(k, fn) { events[k] = fn; }},
  document: {getElementById(id) { return elements[id]; }},
  navigator: {userAgent: 'Android Chrome', serviceWorker: {register(...args) { registered.push(args); return Promise.resolve({}); }}},
  matchMedia() { return {matches: installed}; }
});
elements['app-open'].callbacks.click();
assert.ok(elements['app-dialog'].open && elements['app-install'].hidden);
assert.ok(elements['app-description'].textContent.includes('Chrome'));
let prompted = 0, prevented = false;
events.beforeinstallprompt({preventDefault() { prevented = true; }, async prompt() { prompted++; }, userChoice: Promise.resolve({outcome: 'accepted'})});
assert.equal(prevented, false);
assert.equal(elements['app-install'].hidden, false);
await elements['app-install'].callbacks.click();
assert.equal(prompted, 1);
assert.ok(elements['app-status'].textContent.includes('受け付けました'));
await elements['app-install'].callbacks.click();
assert.equal(prompted, 1);
installed = true;
events.appinstalled();
assert.ok(elements['app-install'].hidden);
assert.ok(elements['app-description'].textContent.includes('アプリとして起動'));
elements['app-close'].callbacks.click();
assert.ok(focused && !elements['app-dialog'].open);
events.load();
assert.equal(registered.length, 1);
assert.equal(registered[0][0], './index.service.worker.js');
assert.equal(registered[0][1].scope, './');
const worker = fs.readFileSync(path.join(output, 'index.service.worker.js'), 'utf8');
assert.ok(worker.includes(`const CACHE_VERSION = "${buildVersion}";`));
assert.ok(worker.includes(`"index.manifest.json?v=${buildVersion}"`));
for (const asset of ['pwa.js?v=', 'index.manifest.json', 'index.192x192.png', 'index.512x512.png']) assert.ok(worker.includes(asset), asset);
console.log('PWA manifest, real PNG sizes, install dialog/prompt/standalone and worker registration passed (Node mock).');
