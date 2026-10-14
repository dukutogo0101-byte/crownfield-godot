#!/usr/bin/env bash
set -euo pipefail
CROWNFIELD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p "$CROWNFIELD_ROOT/builds/web"
: > "$CROWNFIELD_ROOT/builds/.gdignore"
"$GODOT_BIN" --headless --editor --path "$CROWNFIELD_ROOT" --quit
"$GODOT_BIN" --headless --path "$CROWNFIELD_ROOT" --export-release Web "$CROWNFIELD_ROOT/builds/web/index.html"
python3 "$CROWNFIELD_ROOT/web/prepare_web.py" "${1:-$CROWNFIELD_ROOT/builds/web}"
