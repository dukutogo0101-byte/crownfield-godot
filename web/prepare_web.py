#!/usr/bin/env python3
"""Prepare the official Godot Web export for static hosting and PWA caching."""
import gzip
import hashlib
import json
import pathlib
import re
import shutil
import sys

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
build_version = hashlib.sha256((destination / 'index.pck').read_bytes()).hexdigest()[:16]
html = destination / 'index.html'
s = html.read_text()
s = re.sub(r'<script>window.CROWNFIELD_BUILD_VERSION=.*?</script>\n?', '', s)
s = re.sub(r'src="index.js[^"\s]*"', f'src="index.js?v={build_version}"', s)
if 'src="compressed_wasm.js' not in s:
    s = s.replace('<script src="index.js', '<script src="compressed_wasm.js"></script>\n<script src="index.js')
s = re.sub(r'src="compressed_wasm.js[^"\s]*"', f'src="compressed_wasm.js?v={build_version}"', s)
s = s.replace('<script src="compressed_wasm.js', f'<script>window.CROWNFIELD_BUILD_VERSION="{build_version}";</script>\n<script src="compressed_wasm.js')
html.write_text(s)
worker = destination / 'index.service.worker.js'
s = worker.read_text().replace('"index.wasm"', '"index.wasm.gz"')
for array in ['CACHED_FILES', 'CACHEABLE_FILES']:
    pattern = r'const ' + array + r' = (\[.*?\]);'
    match = re.search(pattern, s)
    names = [name.split('?')[0] for name in json.loads(match.group(1))]
    if array == 'CACHED_FILES' and 'compressed_wasm.js' not in names: names.append('compressed_wasm.js')
    names = [name + '?v=' + build_version if name in ['index.js', 'compressed_wasm.js', 'index.pck', 'index.wasm.gz'] else name for name in names]
    s = re.sub(pattern, 'const ' + array + ' = ' + json.dumps(names) + ';', s)
worker.write_text(s)
manifest_path = destination / 'index.manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest.update({'short_name': 'CROWNFIELD', 'theme_color': '#0c1722', 'background_color': '#0c1722', 'scope': './', 'orientation': 'landscape'})
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False))
assert gzip.decompress((destination / 'index.wasm.gz').read_bytes()) == raw
for item in destination.iterdir():
    if item.is_file() and item.stat().st_size >= 25 * 1024 * 1024:
        raise SystemExit(f'Hosting asset exceeds 25 MiB: {item.name}')
files = {p.name: {'size_bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(destination.iterdir()) if p.is_file() and p.name != 'build.json'}
(destination / 'build.json').write_text(json.dumps({'godot': '4.5.2.stable', 'mode': 'single-threaded web/PWA', 'wasm_sha256_uncompressed': hashlib.sha256(raw).hexdigest(), 'files': files}, indent=2)+'\n')
print(json.dumps({'files': len(files), 'compressed_engine_bytes': (destination / 'index.wasm.gz').stat().st_size, 'directory': str(destination)}))
