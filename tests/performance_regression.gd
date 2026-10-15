extends SceneTree
const Core = preload("res://core/simulation.gd")
const Board = preload("res://ui/board.gd")
const Paths = preload("res://core/pathfinder.gd")
var checks: int = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	query_tests()
	await presentation_tests()
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame; await process_frame
	scene._close_modal(); scene.paused = false
	var tick: int = scene.sim.state.tick
	scene._process(5.0)
	check(scene.sim.state.tick - tick <= 2, "long frame never performs the old twenty-tick catch-up burst")
	check(scene.accumulator <= 0.4, "suspended browser does not accumulate an unbounded time debt")
	scene.paused = true; scene._refresh()
	check(not scene.board.animation_enabled, "pause freezes presentation interpolation")
	scene.sim.get_unit(4).pos += 1; scene._refresh()
	scene.board.animation_enabled = true; scene.board._process(0.1)
	scene._save_game(); scene._load_game()
	check(scene.board.entity_point(scene.sim.get_unit(4)).is_equal_approx(scene.board.cell_point(scene.sim.get_unit(4).pos)), "same-tick save load resets an unfinished visual transition")
	scene.audio_player.stop(); scene.audio_player.stream = null
	scene.queue_free(); await process_frame
	FileAccess.open("res://tests/performance_regression_results.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failed": failures, "scope": "Headless cache correctness, deterministic prior-state hashes, interpolation, hit testing, draw invalidation and frame budget; not device FPS"}, "\t"))
	print("PERFORMANCE REGRESSION ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)

func same_routes(sim, label: String) -> void:
	var cached: Dictionary = sim._economy_networks()
	for faction in sim.state.factions:
		if not faction.alive: continue
		var fresh: Dictionary = sim.tax_network(faction.id)
		check(cached[faction.id] == fresh and cached[faction.id].keys() == fresh.keys(), label + " exact routes " + str(faction.id))

func query_tests() -> void:
	var sim = Core.new(); sim.new_game()
	same_routes(sim, "cold cache"); same_routes(sim, "warm cache")
	var bridge: int = -1
	for pos in range(sim.state.cells.size()):
		if sim.state.cells[pos].bridge > 0: bridge = pos; break
	sim.state.cells[bridge].bridge = 0; same_routes(sim, "bridge destroyed")
	sim.state.cells[bridge].bridge = 1; same_routes(sim, "bridge repaired")
	sim.state.cells[165].owner = 1; same_routes(sim, "territory changes")
	sim.state.cells[166].fence = 4; same_routes(sim, "fence built")
	sim.state.cells[166].fence = 0; same_routes(sim, "fence removed")
	sim.state.leaders[0].pos += 1; same_routes(sim, "king away")
	sim.state.leaders[0].pos = sim.state.factions[0].home; same_routes(sim, "king returns")
	sim.state.bases[0].team = 1; same_routes(sim, "village changes team")
	sim.rules.path_neighbor_order = ["down", "right", "left", "up"]; same_routes(sim, "neighbor order changed")
	check(sim.restore(sim.snapshot()), "derived caches never leak into saved state")
	same_routes(sim, "restored world")
	var calls: Dictionary = {"n": 0}
	var cost: Callable = func(p): calls.n += 1; return 10 + p % 3
	var full: Dictionary = Paths.cost_tree(0, 12, 12, cost)
	check(calls.n <= 144, "weighted cost is evaluated once per cell rather than once per incoming edge")
	check(Paths.route(full, 137) == Paths.route(Paths.cost_tree(0, 12, 12, cost, ["up", "left", "right", "down"], 137), 137), "targeted retreat search keeps the same chosen route")
	# Frozen independent pre-optimization states, not regenerated on test runs.
	sim = Core.new(); sim.new_game()
	for _tick in range(120): sim.step()
	check(sim.state_hash() == "c0cf784419194b7eb7d593f7197c6c3279184f90bfda6d6a4d4dfd5a458919a2", "fresh game matches pre-optimization state at tick 120")
	sim = Core.new()
	var saved = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pre_ai_fix_stalemate.json"))
	check(sim.restore(saved), "late fixture loads")
	for _tick in range(120): sim.step()
	check(sim.state_hash() == "57ce12068d9fa832317ee831fdc4ee37587dacab4945f3d3124ff7677621b1b4", "late game matches pre-optimization future state")

func presentation_tests() -> void:
	var sim = Core.new(); sim.new_game()
	var board = Board.new(); root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.set_process(false); board.set_state(sim.state)
	await process_frame; await process_frame
	var worker: Dictionary = sim.get_unit(4)
	var from: Vector2 = board.entity_point(worker)
	worker.pos += 1; board.animation_enabled = true; board.set_state(sim.state)
	var goal: Vector2 = board.cell_point(worker.pos)
	check(board.entity_point(worker).is_equal_approx(from), "movement starts at its previously rendered point")
	board._process(0.1)
	check(board.entity_point(worker).is_equal_approx(from.lerp(goal, 0.25)), "unit moves a fractional cell without changing logical position")
	var snapshot: String = sim.state_hash()
	var tapped: Dictionary = {"cell": -1}
	board.cell_tapped.connect(func(cell, _additive): tapped.cell = cell)
	board._emit_tap(board.entity_point(worker), false)
	check(tapped.cell == worker.pos, "tap selects the visibly interpolated unit")
	board.prefer_actor_taps = false; board._emit_tap(board.entity_point(worker), false)
	check(tapped.cell == board.cell_at(board.entity_point(worker)), "building target taps retain true map coordinates")
	board.animation_enabled = false
	var paused_position: Vector2 = board.entity_point(worker)
	board._process(0.2)
	check(board.entity_point(worker) == paused_position, "paused interpolation does not move")
	board.animation_enabled = true; board._process(0.3)
	check(board.entity_point(worker).is_equal_approx(goal), "interpolation finishes exactly on the logical cell")
	check(sim.state_hash() == snapshot, "animation never writes simulation or replay state")
	var requests: Dictionary = {"n": 0}
	board.path_provider = func(_id, _target): requests.n += 1; return [worker.pos, worker.pos + 1]
	board.selected = [worker.id]; board.target_preview = worker.pos + 1
	board.queue_redraw(); await process_frame; await process_frame
	var searches: int = requests.n; var map_passes: int = board.render_stats.map_passes
	var actor_passes: int = board.render_stats.actor_passes
	for _frame in range(8): board._actor_layer.queue_redraw(); await process_frame
	check(board.render_stats.actor_passes > actor_passes, "moving layer is independently redrawn")
	check(board.render_stats.map_passes == map_passes, "actor frames do not repaint every terrain tile")
	check(requests.n == searches, "actor frames do not repeat path-preview searches")
	worker.pos += 4; board.set_state(sim.state)
	check(board.entity_point(worker).is_equal_approx(board.cell_point(worker.pos)), "teleports or restores snap rather than animate through obstacles")
	sim.state.tick = 100; board.set_state(sim.state)
	sim.state.tick = 0; board.set_state(sim.state)
	check(board._display_tick == 0, "load/restart resets interpolation time")
	board.queue_free(); await process_frame
