// Test the shell's size contract against the ACTUAL exported Godot display code.
// This is a Node logic test, not a real browser/device test.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = process.argv[2] || path.join(root, 'builds/web');
const windowEvents = {}, documentEvents = {}, visualEvents = {}, frames = [];
const canvas = {width: 300, height: 150, style: {}};
const context = {
  window: {innerWidth: 412, innerHeight: 915, devicePixelRatio: 3,
    addEventListener: (event, fn) => windowEvents[event] = fn,
    visualViewport: {addEventListener: (event, fn) => visualEvents[event] = fn}},
  document: {getElementById: () => canvas,
    addEventListener: (event, fn) => documentEvents[event] = fn},
  requestAnimationFrame: fn => frames.push(fn),
  GodotConfig: {canvas, canvas_resize_policy: 0},
  _emscripten_webgl_get_current_context: () => 0,
  GL: {getContext: () => null},
};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(output, 'viewport.js'), 'utf8'), context);
const engine = fs.readFileSync(path.join(output, 'index.js'), 'utf8');
const begin = engine.indexOf('var GodotDisplayScreen=');
const end = engine.indexOf(';var GodotDisplayVK=', begin);
assert.ok(begin >= 0 && end > begin, 'export contains Godot display implementation');
vm.runInContext(engine.slice(begin, end) + ';', context);
const screen = context.GodotDisplayScreen;
screen.isFullscreen = () => false;
screen.desired_size = [1280, 800];
let checks = 0;
function verify(width, height, ratio, event) {
  Object.assign(context.window, {innerWidth: width, innerHeight: height, devicePixelRatio: ratio});
  event();
  while (frames.length) frames.shift()();
  // Godot's policy 0 reads the same dimensions, without overwriting CSS sizes.
  screen.updateSize();
  assert.equal(canvas.style.width, `${width}px`);
  assert.equal(canvas.style.height, `${height}px`);
  assert.equal(canvas.width, Math.round(width * ratio));
  assert.equal(canvas.height, Math.round(height * ratio));
  assert.equal(screen.desired_size[0], canvas.width);
  assert.equal(screen.desired_size[1], canvas.height);
  assert.ok(Math.abs(canvas.width / canvas.height - width / height) < 0.002);
  // Multiple stable frames must not resize/reset the live WebGL canvas.
  assert.equal(screen.updateSize(), 0);
  checks += 8;
}
verify(412, 915, 3, windowEvents.resize);
verify(915, 412, 3, windowEvents.orientationchange);
verify(1536, 709, 1, documentEvents.fullscreenchange);
verify(740, 360, 2.625, visualEvents.resize);
verify(360, 740, 2.625, windowEvents.orientationchange);
verify(740, 360, 2.625, windowEvents.resize);
verify(915, 360, 3, visualEvents.resize);
verify(915, 412, 3, windowEvents.pageshow);
const html = fs.readFileSync(path.join(output, 'index.html'), 'utf8');
assert.ok(html.includes('GODOT_CONFIG.canvasResizePolicy=0'));
assert.ok(html.indexOf('src="viewport.js') < html.indexOf('const engine='));
const worker = fs.readFileSync(path.join(output, 'index.service.worker.js'), 'utf8');
assert.ok(worker.includes('viewport.js?v='));
console.log(`WEB VIEWPORT ${checks + 3}/${checks + 3} (Node mocked DOM + exported Godot display; device not tested)`);
