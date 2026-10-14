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
	scene.tax_slider.value = 20
	scene.tax_slider.value = 25
	var tax_commands: int = 0
	for command in scene.pending:
		if command.action == "tax": tax_commands += 1
	check(tax_commands == 1, "slider drag reserves only its latest tax rate")
	scene._step_game()
	check(scene.sim.state.factions[0].tax == 25, "tax slider writes the selected tax rate")
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
	# Landscape dimensions include common phone/browser and desktop sizes.
	scene._restart()
	scene._close_modal()
	for dimensions in [Vector2i(915, 412), Vector2i(740, 360), Vector2i(1280, 720)]:
		root.size = dimensions
		for _frame in range(4): await process_frame
		scene._adaptive_layout()
		scene._refresh()
		for _frame in range(4): await process_frame
		check(scene.board.size.is_equal_approx(scene.size), "board fills landscape viewport " + str(dimensions))
		check(scene.top_bar.size.y <= 64, "top HUD remains one compact row " + str(dimensions))
		check(not scene.command_cluster.visible, "no command clutter without selection " + str(dimensions))
		scene.selected = [4]
		scene._refresh()
		for _frame in range(4): await process_frame
		check(scene.bottom.size.y <= 64, "selected command bar stays a single compact row " + str(dimensions))
		check(scene.bottom.position.x >= 0 and scene.bottom.position.x + scene.bottom.size.x <= scene.size.x, "command bar fits within landscape width " + str(dimensions))
		scene.selected.clear()
	# Rotate the same running game, including a phone's DPR=3 backing store.
	for dimensions in [Vector2i(412, 915), Vector2i(915, 412), Vector2i(2745, 1236), Vector2i(1236, 2745), Vector2i(2745, 1236), Vector2i(1536, 709), Vector2i(740, 360)]:
		root.size = dimensions
		for _frame in range(8): await process_frame
		var transform: Transform2D = root.get_final_transform()
		var physical_rect: Rect2 = transform * Rect2(Vector2.ZERO, scene.size)
		check(root.content_scale_size == Vector2i(720, 320), "rotation never mutates reference size " + str(dimensions))
		check(absf(transform.x.length() / transform.y.length() - 1.0) < 0.005, "rotation keeps map cells square " + str(dimensions))
		check(physical_rect.position.length() <= 2 and physical_rect.size.distance_to(Vector2(dimensions)) <= 2, "rotation fills physical viewport without black bars " + str(dimensions))
		var position: Vector2 = scene.board.cell_point(84)
		check((transform.affine_inverse() * (transform * position)).distance_to(position) < 0.01, "rotated screen coordinate maps back to tapped cell " + str(dimensions))
	scene.pending.clear()
	scene._refresh()
	var unit: Dictionary = scene.sim.get_unit(4)
	scene._on_cell_tapped(unit.pos, false)
	check(scene.selected.has(4), "tap selects unit without selecting a movement command")
	var target: int = -1
	for pos in scene.sim.neighbors(unit.pos):
		if scene.sim._passable(pos) and scene.sim.get_base(pos).is_empty(): target = pos; break
	scene._on_cell_tapped(target, false)
	check(scene.pending.size() == 1 and scene.pending[0].action == "move" and scene.pending[0].target == target, "destination tap immediately queues movement")
	check(scene.sim.state.tick == 0, "destination tap while paused does not advance game time")
	scene._step_game()
	check(scene.sim.get_unit(4).order == "move", "direct movement command applies without pressing a move button")
	scene.pending.clear()
	scene._choose_order("defend")
	scene._on_cell_tapped(84, false)
	check(scene.pending.size() == 1 and scene.pending[0].action == "defend", "explicit special order takes precedence over direct movement")
	scene.pending.clear()
	scene._cancel_order()
	var first_touch = InputEventScreenTouch.new()
	first_touch.index = 0; first_touch.position = scene.board.cell_point(target); first_touch.pressed = true
	scene.board._touch(first_touch)
	var second_touch = InputEventScreenTouch.new()
	second_touch.index = 1; second_touch.position = first_touch.position + Vector2(40, 0); second_touch.pressed = true
	scene.board._touch(second_touch)
	first_touch.pressed = false; second_touch.pressed = false
	scene.board._touch(first_touch); scene.board._touch(second_touch)
	check(scene.pending.is_empty(), "releasing a two-finger gesture never queues direct movement")
	scene.pause_button.pressed.emit()
	check(not scene.paused and scene.pause_button.text == "Ⅱ", "single pause button resumes")
	scene.pause_button.pressed.emit()
	check(scene.paused and scene.pause_button.text == "▶", "same pause button pauses")
	scene._on_game_menu(0)
	check(scene.speed == 2, "rare speed control lives in dropdown menu")
	check(scene.menu_button.get_popup().item_count >= 10, "game menu exposes save/load, view and help commands")
	var report: Dictionary = {"checks": checks, "passed": checks - failures.size(), "failed": failures, "scope": "Godot headless UI interactions; browser and phone not tested"}
	var file = FileAccess.open("res://tests/ui_smoke_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("UI SMOKE ", checks - failures.size(), "/", checks)
	scene.audio_player.stop()
	scene.audio_player.stream = null
	# Allow the audio server to release its final playback before fixture teardown.
	await create_timer(0.1).timeout
	first_touch = null
	second_touch = null
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
func collect_buttons(node: Node, out: Array) -> void:
	if node is Button: out.append(node)
	for child in node.get_children(): collect_buttons(child, out)
