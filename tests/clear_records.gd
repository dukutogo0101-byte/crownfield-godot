extends SceneTree
const Records = preload("res://core/clear_records.gd")
var checks: int = 0
var failures: Array = []
var fixture_path: String = "user://test_clear_records.json"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func clean() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path + suffix))

func write_text(path: String, value: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func run() -> void:
	clean()
	var store = Records.new()
	store.path = fixture_path
	store.use_web_storage = false
	check(store.load_records() and store.clears.is_empty(), "missing file begins uncleared")
	check(store.describe("four_rivers") == "未クリア", "uncleared summary")
	var state: Dictionary = {"id": "four_rivers", "result": "playing", "winner": -1, "tick": 120}
	var rules: Dictionary = {"day_ticks": 6}
	check(store.record_victory("a", state, rules, "四つの川") == "ignored", "playing cannot clear")
	state.result = "defeat"
	check(store.record_victory("a", state, rules, "四つの川") == "ignored", "defeat cannot clear")
	state.result = "victory"; state.winner = 0
	check(store.record_victory("a", state, rules, "四つの川", true) == "ignored", "replay cannot clear")
	check(store.record_victory("a", state, rules, "四つの川") == "added", "victory persists")
	check(store.summary("four_rivers").count == 1, "first clear counted")
	check(store.record_victory("a", state, rules, "四つの川") == "duplicate", "same run is idempotent")
	var reopened = Records.new()
	reopened.path = fixture_path; reopened.use_web_storage = false
	check(reopened.load_records() and reopened.summary("four_rivers").count == 1, "fresh instance restores durable record")
	check(reopened.record_victory("a", state, rules, "四つの川") == "duplicate", "reloaded run never double counts")
	state.tick = 60
	check(reopened.record_victory("b", state, rules, "四つの川") == "added", "new attempt counted separately")
	check(reopened.summary("four_rivers").best.ticks == 60 and reopened.summary("four_rivers").count == 2, "faster clear replaces best")
	state.tick = 180
	store.record_victory("c", state, rules, "四つの川")
	check(store.summary("four_rivers").best.ticks == 60 and store.summary("four_rivers").count == 3, "slower clear retains best; fresh records merged")
	check(not store.summary("four_rivers").latest.completed_at.is_empty(), "completion timestamp retained")
	check(store.describe("four_rivers").contains("最短 10.0日"), "best time uses simulation ticks")
	state.id = "shop_crossing"
	store.record_victory("d", state, rules, "店先の踏切")
	check(store.summary("shop_crossing").count == 1 and store.summary("four_rivers").count == 3, "maps have independent records")
	check(store.new_run_id() != store.new_run_id(), "attempt identities differ")
	write_text(fixture_path, "")
	check(store.load_records() and store.summary("four_rivers").count == 3, "empty/truncated file recovers validated backup")
	write_text(fixture_path, "corrupt")
	check(store.load_records() and store.summary("four_rivers").count == 3, "validated backup recovers interrupted/corrupt write")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path + ".bak"))
	check(not store.load_records() and not store.last_error.is_empty(), "unrecoverable corruption reported")
	check(store.record_victory("e", state, rules, "店先の踏切") == "error" and FileAccess.get_file_as_string(fixture_path) == "corrupt", "invalid records never silently overwritten")
	clean()
	store.clears = []; store.load_records()
	var scene = load("res://main.tscn").instantiate()
	root.size = Vector2i(740, 360)
	root.add_child(scene)
	await process_frame; await process_frame
	scene.clear_records = store
	scene._reset_game(scene.MAPS[-1].path)
	var first_run: String = scene.run_id
	var initial_hash: String = scene.sim.state_hash()
	scene._save_game()
	scene._reset_game(scene.MAPS[0].path)
	check(scene.run_id != first_run, "starting another game creates a fresh attempt")
	check(scene._load_game() and scene.run_id == first_run, "save restores attempt identity")
	check(scene.sim.state_hash() == initial_hash, "achievement metadata never changes deterministic hash")
	# A one-tick fixture triggers the actual core outcome and the UI finish hook.
	for team in range(1, 4):
		scene.sim.state.factions[team].alive = false
		scene.sim.state.leaders[team].alive = false
	scene.sim.state.tick = 119
	scene._step_game()
	check(scene.sim.state.result == "victory" and scene.end_shown, "real finish hook sees victory")
	check(store.summary("shop_crossing").count == 1, "victory automatically writes map record")
	await process_frame; await process_frame
	check(scene.clear_status.contains("保存しました"), "outcome confirms persistence")
	scene._save_game()
	scene._load_game()
	scene._show_outcome()
	check(store.summary("shop_crossing").count == 1, "finished-save load/outcome cannot inflate count")
	var end_hash: String = scene.sim.state_hash()
	scene._on_game_menu(11)
	check(scene.modal != null and scene.sim.state_hash() == end_hash, "records menu preserves the ongoing world")
	scene._show_title()
	check(scene.map_selector.get_item_text(7).contains("✓"), "cleared map has a selection check mark")
	scene._on_map_selected(7)
	check(scene.map_record_label.text.contains("クリア 1回"), "selected map shows saved achievement")
	scene._restart()
	check(scene.run_id != first_run and scene.sim.state.id == "shop_crossing", "retry creates another attempt on same map")
	check(store.summary("shop_crossing").count == 1, "retry retains achievements")
	var legacy_id: String = scene._run_id_from_save({})
	check(legacy_id == scene._run_id_from_save({}) and legacy_id.begins_with("legacy-"), "old saves receive repeatable fallback identity")
	# Playback of an already victorious snapshot, then save/load of that playback.
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://crownfield_save.json"))
	var replay: Dictionary = {"initial_snapshot": saved.snapshot, "initial_hash": scene.sim.snapshot_state_hash(saved.snapshot), "commands": [], "checkpoints": [], "final_tick": saved.snapshot.state.tick, "final_hash": end_hash}
	scene._start_playback(replay)
	scene._step_game()
	await process_frame; await process_frame
	check(scene.replay_playback and store.summary("shop_crossing").count == 1, "winning replay excluded")
	scene._save_game()
	scene._load_game()
	scene._record_clear()
	check(not scene.record_eligible and store.summary("shop_crossing").count == 1, "saving/loading playback cannot turn it into a clear")
	scene._reset_game(scene.MAPS[0].path)
	check(scene.record_eligible, "new game after playback is eligible again")
	scene._web_import_json([JSON.stringify(saved)])
	check(scene.run_id == first_run and store.summary("shop_crossing").count == 1, "JSON import preserves identity and deduplication")
	var report: Dictionary = {"checks": checks, "passed": checks - failures.size(), "failed": failures, "scope": "Native persistence, recovery, UI finish/save/load/import/replay dedup; actual browser storage not tested"}
	var output = FileAccess.open("res://tests/clear_records_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t")); output.close()
	print("CLEAR RECORDS ", checks - failures.size(), "/", checks)
	scene.audio_player.stop(); scene.audio_player.stream = null
	await create_timer(0.1).timeout
	scene.queue_free(); await process_frame
	clean()
	quit(0 if failures.is_empty() else 1)
