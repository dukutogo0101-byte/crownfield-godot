extends SceneTree
var failures: Array = []
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._close_modal()
	scene.selected = [4]
	scene._choose_order("develop")
	check(scene.pending.size() == 1, "housing button queues exactly one core command")
	check(scene.sim.state.tick == 0, "paused UI does not advance simulation")
	scene._step_game()
	check(scene.sim.get_unit(4).get("auto_mode", "") == "develop", "queued housing button command is applied")
	scene._show_tax()
	var buttons: Array = []
	collect_buttons(scene.modal, buttons)
	for button in buttons:
		if button.text == "25%": button.pressed.emit(); break
	scene._step_game()
	check(scene.sim.state.factions[0].tax == 25, "tax dialog writes the selected tax rate")
	scene._save_game()
	scene._load_game()
	check(scene.sim.get_unit(4).get("auto_mode", "") == "develop", "UI save and load retain persistent housing mode")
	scene._new_recording()
	for _tick in range(6): scene._step_game()
	var replay: Dictionary = scene._replay_document()
	scene._start_playback(replay)
	check(scene.replay_playback, "UI replay initial hash matches the restored initial state")
	while scene.sim.state.tick < replay.final_tick and scene.replay_playback: scene._step_game()
	check(scene.sim.state_hash() == replay.final_hash, "UI replay reproduces the final hash")
	check(scene.order_buttons.has("develop"), "continuous housing command is visible")
	var report: Dictionary = {"checks": checks, "passed": checks - failures.size(), "failed": failures, "scope": "Godot headless UI interactions; browser and phone not tested"}
	var file = FileAccess.open("res://tests/ui_smoke_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("UI SMOKE ", checks - failures.size(), "/", checks)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
func collect_buttons(node: Node, out: Array) -> void:
	if node is Button: out.append(node)
	for child in node.get_children(): collect_buttons(child, out)
