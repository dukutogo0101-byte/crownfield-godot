extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ",what)
func _initialize() -> void: call_deferred("run")
func finger(board: Control, id: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id; event.position = pos; event.pressed = pressed
	board._touch(event)
func drag(board: Control, id: int, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id; event.position = pos
	board._touch_drag(event)
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for dims in [Vector2i(740,360),Vector2i(915,412),Vector2i(2745,1236)]:
		root.size = dims
		for f in 5: await process_frame
		scene._reset_game(scene.MAPS[7].path)
		scene.selected = [4]; scene._refresh()
		for f in 5: await process_frame
		var board = scene.board
		var home: int = scene.sim.state.factions[0].home
		var local_scale: float = board.cell_size()
		check(local_scale >= 26 and board.usable_rect().has_point(board.cell_point(home)), "readable home framing")
		check(not scene.selection_bar.get_global_rect().intersects(scene.bottom.get_global_rect()), "left and right touch docks stay separate with a selection")
		for button in [scene.menu_button,scene.pause_button,scene.overview_button,scene.initial_menu,scene.auto_menu,scene.command_menu]:
			check(button.get_global_rect().size.y >= 44, "touchable control " + str(button.tooltip_text))
		scene.overview_button.pressed.emit()
		await process_frame; await process_frame
		check(board.is_overview() and board.cell_size() < local_scale, "one press reaches the full map")
		var mini: Vector2 = board._minimap.get_center()
		scene._choose_order("build_bridge")
		finger(board,0,mini,true); drag(board,0,mini+Vector2(5,1)); finger(board,0,mini,false)
		check(not board.is_overview() and scene.active_order == "build_bridge" and scene.pending.is_empty(), "minimap tap and drag change camera only")
		var start: Vector2 = board.usable_rect().get_center()
		var before := Vector2(board.pan)
		finger(board,0,start,true); drag(board,0,start+Vector2(-26,-13)); finger(board,0,start+Vector2(-26,-13),false)
		check(before.distance_to(board.pan) > 1 and scene.pending.is_empty() and scene.active_order == "build_bridge","one-finger pan never issues or cancels a command")
		finger(board,0,start,true); finger(board,1,start+Vector2(40,0),true)
		drag(board,1,start+Vector2(65,0)); finger(board,0,start,false); finger(board,1,start+Vector2(65,0),false)
		check(scene.active_order == "build_bridge" and scene.pending.is_empty(),"pinch preserves targeting without issuing command")
		scene.overview_button.pressed.emit(); scene.overview_button.pressed.emit()
		check(board.usable_rect().has_point(board.cell_point(home)), "second toggle returns to home")
	scene.queue_free(); await process_frame
	print("FIELD CAMERA ",checks-failures,"/",checks)
	quit(1 if failures else 0)
