#!/usr/bin/env bash
set -euo pipefail
CROWNFIELD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
"$GODOT_BIN" --headless --editor --path "$CROWNFIELD_ROOT" --quit
"$GODOT_BIN" --headless --path "$CROWNFIELD_ROOT" --script res://tests/test_runner.gd
"$GODOT_BIN" --headless --path "$CROWNFIELD_ROOT" --script res://tests/strategy_ai.gd
"$GODOT_BIN" --headless --path "$CROWNFIELD_ROOT" --script res://tests/test_construction_chaining.gd
"$GODOT_BIN" --headless --path "$CROWNFIELD_ROOT" --script res://tests/ui_smoke.gd
"$GODOT_BIN" --headless --path "$CROWNFIELD_ROOT" --script res://tests/map_selection_ui.gd
"$GODOT_BIN" --headless --path "$CROWNFIELD_ROOT" --script res://tests/map_grok_three.gd
"$GODOT_BIN" --headless --path "$CROWNFIELD_ROOT" --script res://tests/map_original_grammar.gd
"$GODOT_BIN" --headless --path "$CROWNFIELD_ROOT" --script res://tests/sim_stats.gd
