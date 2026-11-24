#!/usr/bin/env python3
"""Prepare the official Godot Web export for static hosting and PWA caching."""
import gzip
import hashlib
import json
import pathlib
import re
import shutil
import sys
from PIL import Image

root = pathlib.Path(__file__).resolve().parents[1]
source = root / 'builds/web'
destination = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else source
if destination != source.resolve():
    destination.mkdir(parents=True, exist_ok=True)
    for item in source.iterdir():
        if item.is_file() and not item.name.endswith('.import'): shutil.copy2(item, destination / item.name)
for metadata in destination.glob('*.import'): metadata.unlink()
wasm = destination / 'index.wasm'
raw = wasm.read_bytes() if wasm.exists() else gzip.decompress((destination / 'index.wasm.gz').read_bytes())
(destination / 'index.wasm.gz').write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))
wasm.unlink(missing_ok=True)
shutil.copy2(root / 'web/compressed_wasm.js', destination / 'compressed_wasm.js')
shutil.copy2(root / 'web/viewport.js', destination / 'viewport.js')
shutil.copy2(root / 'web/pwa.js', destination / 'pwa.js')
for asset in ['assets/title_chart.svg','assets/interface/wordmark.svg']:
    shutil.copy2(root / asset, destination / pathlib.Path(asset).name)
with Image.open(destination / 'index.512x512.png') as icon:
    icon.resize((192, 192), Image.Resampling.LANCZOS).save(destination / 'index.192x192.png')
build_version = hashlib.sha256((destination / 'index.pck').read_bytes() + (root / 'web/shell.html').read_bytes() + (root / 'web/viewport.js').read_bytes() + (root / 'web/compressed_wasm.js').read_bytes() + (root / 'web/pwa.js').read_bytes() + (root / 'web/service_worker.js').read_bytes() + pathlib.Path(__file__).read_bytes()).hexdigest()[:16]
html = destination / 'index.html'
old_html = html.read_text()
config = json.loads(re.search(r'const GODOT_CONFIG=(.*?);\n', old_html).group(1))
if 'fileSizes' in config: config['fileSizes']['index.pck'] = (destination / 'index.pck').stat().st_size
config = json.dumps(config,ensure_ascii=False,separators=(',', ':'))
# The owner-private host authenticates the manifest too. Chrome omits cookies
# for manifest requests unless use-credentials is explicit, even on this origin.
head = '<link rel="icon" href="index.icon.png">\n<link rel="apple-touch-icon" href="index.apple-touch-icon.png">\n' + f'<link rel="manifest" href="index.manifest.json?v={build_version}" crossorigin="use-credentials">'
s = (root / 'web/shell.html').read_text().replace('$GODOT_HEAD_INCLUDE', head).replace('$GODOT_CONFIG', config).replace('$GODOT_URL', 'index.js')
s = re.sub(r'<script>window.CROWNFIELD_BUILD_VERSION=.*?</script>\n?', '', s)
s = re.sub(r'src="index.js[^"\s]*"', f'src="index.js?v={build_version}"', s)
if 'src="compressed_wasm.js' not in s:
    s = s.replace('<script src="index.js', '<script src="compressed_wasm.js"></script>\n<script src="index.js')
s = re.sub(r'src="compressed_wasm.js[^"\s]*"', f'src="compressed_wasm.js?v={build_version}"', s)
s = re.sub(r'src="pwa.js[^"\s]*"', f'src="pwa.js?v={build_version}"', s)
s = re.sub(r'src="viewport.js[^"\s]*"', f'src="viewport.js?v={build_version}"', s)
s = s.replace('<script src="compressed_wasm.js', f'<script>window.CROWNFIELD_BUILD_VERSION="{build_version}";</script>\n<script src="compressed_wasm.js')
html.write_text(s)
worker = destination / 'index.service.worker.js'
s = (root / 'web/service_worker.js').read_text().replace('__CACHE_VERSION__', json.dumps(build_version))
export_worker = worker.read_text().replace('"index.wasm"', '"index.wasm.gz"')
for array in ['CACHED_FILES', 'CACHEABLE_FILES']:
    pattern = r'const ' + array + r' = (\[.*?\]);'
    match = re.search(pattern, export_worker)
    names = [name.split('?')[0] for name in json.loads(match.group(1))]
    if array == 'CACHED_FILES':
        names = ['./' if name == 'index.html' else name for name in names]
        for extra in ['compressed_wasm.js', 'viewport.js', 'pwa.js', 'index.manifest.json', 'index.192x192.png', 'index.512x512.png', 'title_chart.svg', 'wordmark.svg']:
            if extra not in names: names.append(extra)
    names = [name + '?v=' + build_version if name in ['index.js', 'compressed_wasm.js', 'viewport.js', 'pwa.js', 'index.pck', 'index.wasm.gz', 'index.manifest.json'] else name for name in names]
    s = s.replace('__' + array + '__', json.dumps(names))
worker.write_text(s)
manifest_path = destination / 'index.manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest.update({'short_name': 'CROWNFIELD', 'theme_color': '#0c1722', 'background_color': '#0c1722', 'scope': './', 'orientation': 'landscape', 'id': './index.html', 'start_url': './', 'display': 'standalone', 'prefer_related_applications': False, 'icons': [{'src': 'index.192x192.png', 'sizes': '192x192', 'type': 'image/png', 'purpose': 'any'}, {'src': 'index.512x512.png', 'sizes': '512x512', 'type': 'image/png', 'purpose': 'any'}]})
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False))
assert gzip.decompress((destination / 'index.wasm.gz').read_bytes()) == raw
for item in destination.iterdir():
    if item.is_file() and item.stat().st_size >= 25 * 1024 * 1024:
        raise SystemExit(f'Hosting asset exceeds 25 MiB: {item.name}')
files = {p.name: {'size_bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(destination.iterdir()) if p.is_file() and p.name != 'build.json'}
(destination / 'build.json').write_text(json.dumps({'godot': '4.5.2.stable', 'mode': 'single-threaded web/PWA', 'wasm_sha256_uncompressed': hashlib.sha256(raw).hexdigest(), 'files': files}, indent=2)+'\n')
print(json.dumps({'files': len(files), 'compressed_engine_bytes': (destination / 'index.wasm.gz').stat().st_size, 'directory': str(destination)}))
