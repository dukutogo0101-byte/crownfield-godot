extends SceneTree
const Core = preload("res://core/simulation.gd")
var checks: int = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)
func fixture():
	var sim = Core.new(); sim.new_game()
	sim.state.w = 9; sim.state.h = 9; sim.state.cells = []
	for _i in range(81): sim.state.cells.append({"terrain": 0, "owner": -1, "bridge": 0, "fence": 0, "bridge_built": false})
	sim.state.bases = []; sim.state.units = []; sim.state.next_id = 100
	for team in range(4):
		var home: int = [0, 8, 72, 80][team]
		sim.state.factions[team].home = home
		sim.state.factions[team].funds = 1000
		sim.state.leaders[team].pos = home
		sim.state.leaders[team].target = home
		sim.state.leaders[team].power = 100
		sim.state.bases.append({"id": 80 + team, "team": team, "pos": home, "pop": 32})
	sim.state.units.append({"id": 91, "team": 0, "pos": 20, "power": 400, "order": "wait", "target": 20, "manual": true, "king": false, "auto_mode": ""})
	return sim
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var sim = fixture()
	var u: Dictionary = sim.get_unit(91)
	sim.state.tick = 5
	sim.step([sim.issue("develop", [91])])
	check(sim.state.tick == 6 and sim.state.tick % sim.rules.ai_period != 0, "completion occurs between scheduled AI decisions")
	check(not sim.get_base(20).is_empty(), "housing command starts first construction immediately")
	check(u.order == "build_base" and u.target != 20, "completed village immediately selects the next construction site")
	check(sim.state.bases.size() == 5 and sim.state.factions[0].funds == 900, "one work phase builds and charges for exactly one village")
	sim.step(); sim.step()
	check(u.pos != 20, "builder departs on first movement period after completion")
	while sim.state.tick < 12: sim.step()
	check(sim.state.bases.size() >= 6, "second village completes before the next AI decision")
	check(u.auto_mode == "develop", "continuous housing intent survives chained construction")
	var copy = Core.new()
	check(copy.restore(sim.snapshot()), "mid-chain save restores")
	for _tick in range(12): sim.step(); copy.step()
	check(copy.state_hash() == sim.state_hash(), "restored chain continues deterministically")
	# Multiple completions reserve their next sites together, using all new villages.
	sim = fixture(); u = sim.get_unit(91)
	u.order = "build_base"; u.manual = false; u.auto_mode = "develop"; u["ai_job"] = "develop"
	var second: Dictionary = u.duplicate(true)
	second.id = 92; second.pos = 24; second.target = 24
	sim.state.units.append(second)
	sim._work()
	check(sim.state.bases.size() == 6, "simultaneous workers each finish one village")
	check(u.order == "build_base" and second.order == "build_base", "both workers chain immediately")
	check(u.target != second.target and second.target not in sim.around(u.target), "chained destinations are distinct and nonadjacent")
	# Resource costs, explicit orders and reclamation keep their contracts.
	sim = fixture(); u = sim.get_unit(91)
	u.order = "build_base"; u.manual = false; u.auto_mode = "develop"; u["ai_job"] = "develop"
	sim.state.factions[0].funds = 100
	sim._work()
	check(sim.state.factions[0].funds == 0 and u.order != "build_base", "insufficient funds prevents another construction")
	check(u.auto_mode == "develop", "poor worker retains persistent housing intent")
	sim = fixture(); u = sim.get_unit(91)
	u.order = "build_base"; u.manual = false; u.auto_mode = "develop"; u["ai_job"] = "develop"; u.power = 64
	sim._work()
	check(u.power == 32 and u.order != "build_base", "construction still needs more than 32 available people")
	sim = fixture(); u = sim.get_unit(91)
	u.order = "build_base"
	sim._work()
	check(u.order == "wait" and sim.state.bases.size() == 5, "explicit single village order stays a single order")
	sim = fixture(); u = sim.get_unit(91)
	u.order = "reclaim"; u.manual = false; u.auto_mode = "develop"; u["ai_job"] = "develop"
	sim.state.cells[20].terrain = 1
	sim._work()
	check(sim.state.cells[20].terrain == 0 and u.order == "build_base" and u.target == 20, "reclamation immediately schedules housing on the reclaimed site")
	sim = fixture(); u = sim.get_unit(91)
	sim.step([sim.issue("develop", [91]), sim.issue("wait", [91])])
	check(u.manual and u.order == "wait", "later manual cancellation overrides immediate planning")
	var report: Dictionary = {"checks": checks, "passed": checks - failures.size(), "failed": failures, "scope": "Godot core construction completion, periods, simultaneous reservations and save/resume"}
	var file = FileAccess.open("res://tests/construction_chaining_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CONSTRUCTION CHAINING ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)
