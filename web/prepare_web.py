#!/usr/bin/env python3
"""Prepare the official Godot Web export for static hosting and PWA caching."""
import gzip
import hashlib
import json
import pathlib
import shutil
import sys

root = pathlib.Path(__file__).resolve().parents[1]
source = root / 'builds/web'
destination = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else source
if destination != source.resolve():
    destination.mkdir(parents=True, exist_ok=True)
    for item in source.iterdir():
        if item.is_file(): shutil.copy2(item, destination / item.name)
wasm = destination / 'index.wasm'
raw = wasm.read_bytes() if wasm.exists() else gzip.decompress((destination / 'index.wasm.gz').read_bytes())
(destination / 'index.wasm.gz').write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))
wasm.unlink(missing_ok=True)
shutil.copy2(root / 'web/compressed_wasm.js', destination / 'compressed_wasm.js')
html = destination / 'index.html'
s = html.read_text()
if 'src="compressed_wasm.js"' not in s:
    s = s.replace('<script src="index.js">', '<script src="compressed_wasm.js"></script>\n<script src="index.js">')
html.write_text(s)
worker = destination / 'index.service.worker.js'
s = worker.read_text().replace('"index.wasm"', '"index.wasm.gz"')
if '"compressed_wasm.js"' not in s:
    s = s.replace('const CACHED_FILES = [', 'const CACHED_FILES = ["compressed_wasm.js",')
worker.write_text(s)
manifest_path = destination / 'index.manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest.update({'short_name': 'CROWNFIELD', 'theme_color': '#0c1722', 'background_color': '#0c1722', 'scope': './'})
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False))
assert gzip.decompress((destination / 'index.wasm.gz').read_bytes()) == raw
for item in destination.iterdir():
    if item.is_file() and item.stat().st_size >= 25 * 1024 * 1024:
        raise SystemExit(f'Hosting asset exceeds 25 MiB: {item.name}')
files = {p.name: {'size_bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(destination.iterdir()) if p.is_file() and p.name != 'build.json'}
(destination / 'build.json').write_text(json.dumps({'godot': '4.5.2.stable', 'mode': 'single-threaded web/PWA', 'wasm_sha256_uncompressed': hashlib.sha256(raw).hexdigest(), 'files': files}, indent=2)+'\n')
print(json.dumps({'files': len(files), 'compressed_engine_bytes': (destination / 'index.wasm.gz').stat().st_size, 'directory': str(destination)}))
