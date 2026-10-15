extends SceneTree
var checks: int = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)
func _initialize() -> void:
	call_deferred("run")
func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found: Button = find_button(child, title)
		if found != null: return found
	return null
func run() -> void:
	root.size = Vector2i(915, 412)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for _frame in range(4): await process_frame
	check(scene.map_selector.item_count == 4, "title offers original and three Grok maps")
	for index in range(scene.MAPS.size()):
		var entry: Dictionary = scene.MAPS[index]
		scene._show_title()
		var before: String = scene.sim.state_hash()
		scene.map_selector.select(index)
		scene.map_selector.item_selected.emit(index)
		for _frame in range(4): await process_frame
		check(scene.selected_map_index == index, "selection signal updates chosen map " + entry.id)
		check(scene.sim.state_hash() == before, "preview never replaces ongoing world " + entry.id)
		check(scene.map_description.text == entry.description, "map description follows selection " + entry.id)
		var rect: Rect2 = scene.map_start_button.get_global_rect()
		check(rect.position.y >= 0 and rect.end.y <= scene.size.y, "start button is visible on landscape phone " + entry.id)
		scene.map_start_button.pressed.emit()
		check(not scene.paused and scene.modal == null, "start button closes title and starts game " + entry.id)
		scene.paused = true
		check(scene.sim.state.id == entry.id and scene.sim.state.tick == 0, "selected JSON starts at tick zero " + entry.id)
		check(scene.board.state.id == entry.id and scene.board.state.cells.size() == 1040, "board displays selected terrain " + entry.id)
		check(scene.pending.is_empty() and scene.command_log.is_empty(), "new map has no commands from previous game " + entry.id)
		scene.selected = [4]
		scene._choose_order("develop")
		for _tick in range(6): scene._step_game()
		check(scene.sim.state.tick == 6 and scene.sim.get_unit(4).get("auto_mode", "") == "develop", "selected map accepts actual housing commands " + entry.id)
		scene._save_game()
		var saved: String = scene.sim.state_hash()
		scene._reset_game(scene.MAPS[0].path)
		scene._show_title()
		var load_button: Button = find_button(scene.modal, "保存したゲームを読込")
		check(load_button != null, "title exposes saved game load " + entry.id)
		if load_button != null: load_button.pressed.emit()
		check(scene.sim.state_hash() == saved and scene.modal == null, "title restores the saved map and world " + entry.id)
		scene._restart()
		check(scene.sim.state.id == entry.id and scene.sim.state.tick == 0, "retry restarts same map " + entry.id)
		check(scene.map_selector.selected == index, "map picker remembers loaded or retried map " + entry.id)
		scene._close_modal()
	scene._on_game_menu(10)
	check(scene.modal != null and scene.map_selector.item_count == 4, "game menu opens map selection")
	var original: String = scene.sim.state_hash()
	scene.map_selector.item_selected.emit(0)
	scene._close_modal()
	check(scene.sim.state_hash() == original, "closing map picker preserves current game")
	check(not scene._reset_game("res://data/maps/not_present.json") and scene.sim.state_hash() == original, "missing map cannot destroy ongoing game")
	var file = FileAccess.open("res://tests/map_selection_ui_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failed": failures, "scope": "Godot headless map picker, game input, save/load/retry and landscape geometry; phone/browser not tested"}, "\t"))
	print("MAP SELECTION UI ", checks - failures.size(), "/", checks)
	scene.audio_player.stop(); scene.audio_player.stream = null
	await create_timer(0.1).timeout
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
