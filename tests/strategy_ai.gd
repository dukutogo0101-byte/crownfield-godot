extends SceneTree
const Core = preload("res://core/simulation.gd")
const Strategy = preload("res://core/strategic_ai.gd")
const Paths = preload("res://core/pathfinder.gd")
var failures: Array = []
var checks: int = 0
var experiments: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)

func board():
	var sim = Core.new(); sim.new_game()
	sim.state.w = 17; sim.state.h = 9; sim.state.cells = []
	for _p in range(153): sim.state.cells.append({"terrain": 0, "owner": -1, "bridge": 0, "bridge_built": false, "fence": 0})
	sim.state.units = []; sim.state.bases = []; sim.state.next_id = 1000
	for team in range(4):
		var home: int = [16, 68, 0, 152][team]
		sim.state.factions[team].home = home
		sim.state.factions[team].funds = 1000
		sim.state.factions[team].tax = 10
		sim.state.factions[team].alive = team < 2
		sim.state.leaders[team].pos = home; sim.state.leaders[team].target = home
		sim.state.leaders[team].power = 10000 if team == 0 else 100
		sim.state.leaders[team].alive = team < 2
		sim.state.leaders[team].order = "wait"
	sim.rules.ai_development_bases = 1
	sim.rules.ai_builder_max = 1
	return sim

func unit(sim, id: int, team: int, pos: int, power: int, mode: String = "auto") -> Dictionary:
	var u: Dictionary = {"id": id, "team": team, "pos": pos, "power": power, "order": mode, "target": pos, "manual": false, "king": false, "auto_mode": mode}
	sim.state.units.append(u)
	return u

func base(sim, id: int, team: int, pos: int, pop: int = 32) -> Dictionary:
	var b: Dictionary = {"id": id, "team": team, "pos": pos, "pop": pop}
	sim.state.bases.append(b)
	return b

func river(sim) -> void:
	for y in range(9): sim.state.cells[y * 17 + 8].terrain = 2

func accrue(sim, ticks: int) -> void:
	for _tick in range(ticks): sim.state.tick += 1; sim._economy()

func _initialize() -> void: call_deferred("run")

func run() -> void:
	test_paths()
	test_tax()
	test_engineering()
	test_defense()
	test_intent_and_saves()
	var report: Dictionary = {"checks": checks, "passed": checks - failures.size(), "failed": failures, "experiments": experiments, "scope": "Deterministic Godot simulation and economic experiments; no human difficulty rating or phone browser test"}
	FileAccess.open("res://tests/strategy_ai_results.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("STRATEGY AI ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)

func test_paths() -> void:
	var tree: Dictionary = Paths.cost_tree(0, 3, 3, func(p): return 100 if p == 1 else 10)
	check(Paths.route(tree, 2) == [3, 4, 5, 2], "weighted routing chooses cheap detour over expensive shortcut")
	check(tree.distance[2] == 40, "weighted route total includes every entered cell")
	check(Paths.route(Paths.cost_tree(0, 3, 3, func(_p): return 1), 8) == [1, 2, 5, 8], "weighted routing has stable ties")
	check(Paths.route(Paths.cost_tree(0, 3, 3, func(p): return -1 if p in [1, 3] else 1), 8).is_empty(), "weighted routing cannot cross blocked terrain")

func test_tax() -> void:
	var sim = board(); var b: Dictionary = base(sim, 200, 0, 20, 128)
	var start: int = sim.state.factions[0].funds
	accrue(sim, 24)
	check(sim.state.factions[0].funds - start == 12, "128 residents at 10% pay 12 with fractional carry")
	check(b.tax_credit == 1920, "fractional tax is preserved, not discarded per collection")
	accrue(sim, 96)
	check(sim.state.factions[0].funds - start == 64, "five collections preserve exactly 64 coins")
	sim = board(); b = base(sim, 200, 0, 20, 1); sim.state.factions[0].tax = 1
	start = sim.state.factions[0].funds; accrue(sim, 24)
	check(sim.state.factions[0].funds == start, "tiny villages do not receive an artificial minimum coin")
	accrue(sim, 24 * 99)
	check(sim.state.factions[0].funds == start + 1, "small fractional taxes eventually become one coin")
	sim = board(); b = base(sim, 200, 0, 20, 100); start = sim.state.factions[0].funds
	accrue(sim, 12); b.pop = 1; accrue(sim, 12)
	check(sim.state.factions[0].funds - start == 5, "sortie before collection cannot erase the tax earned before it")
	sim = board(); base(sim, 200, 0, 20, 100); sim.state.factions[0].tax = 0
	start = sim.state.factions[0].funds; accrue(sim, 12); sim.state.factions[0].tax = 20; accrue(sim, 12)
	check(sim.state.factions[0].funds - start == 10, "mid-period slider change affects only subsequent ticks")
	sim = board(); b = base(sim, 200, 0, 20, 100); sim.state.leaders[0].pos = 15
	start = sim.state.factions[0].funds; accrue(sim, 24)
	check(sim.state.factions[0].funds == start and b.get("tax_credit", 0) == 0, "away king stops new tax accrual")
	check(sim.economy_forecast(0).reason.contains("王"), "forecast explains why away king stops tax")
	sim.state.leaders[0].pos = 16
	check(sim.population_growth(b, 0) > sim.population_growth(b, 30), "tax explicitly trades population growth for revenue")
	check(sim.economy_forecast(0, 30).income > sim.economy_forecast(0, 5).income, "tax forecast changes with the proposed rate")
	river(sim); b.pos = 70
	check(sim.economy_forecast(0).connected == 0, "disconnected tax village is excluded from forecast")
	check(sim.economy_forecast(0).reason.contains("税路"), "forecast explains disconnected supply routes")
	# Same real population/sortie simulation, different tax rates, no AI decisions.
	var cases: Array = []
	for rate in [0, 10, 20, 30]:
		sim = Core.new(); sim.new_game(); sim.rules.ai_period = 100000
		sim.state.factions[0].tax = rate
		for _tick in range(480): sim.step()
		cases.append({"tax": rate, "funds": sim.state.factions[0].funds, "population": sim.population(0)})
	for i in range(1, cases.size()):
		check(cases[i].funds > cases[i-1].funds, "higher tax increases real 480-tick revenue " + str(cases[i].tax))
		check(cases[i].population < cases[i-1].population, "higher tax lowers real 480-tick population " + str(cases[i].tax))
	experiments.append({"tax_480_ticks": cases})

func test_engineering() -> void:
	var sim = board(); river(sim)
	base(sim, 200, 1, 52); base(sim, 201, 0, 78)
	unit(sim, 300, 1, 53, 80, "develop")
	var army: Dictionary = unit(sim, 301, 1, 70, 800)
	sim._ai()
	check(army.get("ai_job") == "engineer" and army.order == "build_bridge", "enemy plans a crossing to reach an enemy objective")
	var crossing: int = army.target
	check(crossing % 17 == 8, "crossing is placed on the actual river")
	check(sim.can_order(1, "build_bridge", [army.id], crossing), "enemy engineering uses shared command legality")
	check(not sim.can_order(0, "build_bridge", [army.id], crossing), "shared legality enforces army ownership")
	check(not sim.can_order(1, "build_bridge", [sim.state.leaders[1].id], crossing), "king cannot receive a worker-only order")
	var start: int = sim.state.factions[1].funds
	sim.get_unit(300).order = "wait" # Isolate bridge costs from the separate housing worker.
	for _tick in range(40): sim._movement(); sim._work()
	check(sim.state.cells[crossing].bridge == 4, "engineering finishes planned bridge durability without AI-period waits")
	check(sim.state.factions[1].funds == start - 36, "enemy pays the same 30 plus three 2-coin repairs as player")
	check(sim._land(army.pos) and army.pos in sim.neighbors(crossing), "enemy builds from adjacent land throughout")
	check(not army.has("ai_task"), "completed construction frees its worker")
	sim._ai()
	check(army.get("ai_job") == "attack", "completed crossing leads into an offensive order")
	for _move in range(24): sim._movement(); sim._work()
	check(sim.get_base(78).is_empty(), "enemy actually crosses the new bridge and destroys the target village")
	# An existing bridge's repair price is the exact remaining work.
	var planner = Strategy.new(sim); planner.team = 1
	sim.state.cells[crossing].bridge = 3
	check(planner._work_price("build_bridge", crossing) == 2, "three-point bridge only needs one paid repair")
	# A narrow hostile fence or cave is breached with the same bank-work rules.
	for action in ["destroy_fence", "seal_cave"]:
		sim = board()
		for pos in range(153):
			if pos / 17 != 4: sim.state.cells[pos].terrain = 3
		base(sim, 200, 1, 69); base(sim, 201, 0, 82)
		army = unit(sim, 301, 1, 70, 800)
		sim.state.factions[1].funds = 0
		if action == "destroy_fence": sim.state.cells[76].fence = 8
		else: sim.state.cells[76].terrain = 3
		sim._ai()
		check(army.order == action, "enemy plans " + action + " to clear a blocked route")
		for _tick in range(24): sim._movement(); sim._work()
		check(sim._passable(76), "shared work actually completes " + action)
	# Impassable double-width river cannot be cheated by working from a bridge.
	sim = board(); river(sim)
	for y in range(9): sim.state.cells[y * 17 + 9].terrain = 2
	base(sim, 200, 1, 52); base(sim, 201, 0, 78)
	unit(sim, 300, 1, 53, 80, "develop"); army = unit(sim, 301, 1, 70, 800)
	sim._ai()
	check(not army.has("ai_task"), "unreachable far bank prevents an impossible double-width river shortcut")
	# Superior defenders must stop both the army and its engineering project.
	sim = board(); river(sim); base(sim, 200, 1, 52); base(sim, 201, 0, 78)
	unit(sim, 300, 1, 53, 80, "develop"); army = unit(sim, 301, 1, 70, 800)
	unit(sim, 302, 0, 78, 5000, "wait")
	sim._ai()
	check(not army.has("ai_task"), "engineer is not sent to a crossing guarded by overwhelming force")
	# Broken taxes get priority over a speculative offensive shortcut.
	sim = board(); river(sim); base(sim, 200, 1, 52); base(sim, 201, 1, 78)
	sim.state.leaders[0].power = 10000
	unit(sim, 300, 1, 53, 80, "develop"); army = unit(sim, 301, 1, 70, 200)
	sim._ai()
	check(army.get("ai_task", {}).get("purpose") == "supply", "AI reconnects a tax village across a broken river route")
	# Exercise the normal tick phases, not just direct planner/work calls.
	sim = board(); river(sim); base(sim, 200, 1, 52); base(sim, 201, 0, 78)
	sim.rules.base_period = 100000
	sim.state.leaders[0].pos = 15; sim.state.leaders[0].target = 15; sim.state.leaders[0].manual = true
	unit(sim, 300, 1, 53, 1000, "develop"); army = unit(sim, 301, 1, 70, 800)
	var crossed: bool = false; var engineered: bool = false
	for _tick in range(180):
		sim.step()
		engineered = engineered or army.has("ai_task")
		crossed = crossed or army.pos % 17 > 8
	check(engineered, "normal tick loop assigns an engineering role")
	check(crossed, "normal tick loop completes bridge work and crosses into enemy territory")
	check(sim.get_base(78).is_empty(), "normal tick loop turns engineering into a completed village attack")

func test_defense() -> void:
	var sim = board(); river(sim)
	sim.state.cells[76].bridge = 4; sim.state.cells[76].bridge_built = true
	sim.state.factions[1].home = 72; sim.state.leaders[1].pos = 72
	base(sim, 200, 1, 52)
	var worker: Dictionary = unit(sim, 300, 1, 74, 20)
	unit(sim, 301, 1, 70, 500)
	unit(sim, 302, 0, 80, 6000, "wait")
	sim._ai()
	check(worker.order == "destroy_bridge", "outmatched country chooses a defensive bridge cut")
	for _tick in range(4): sim._movement(); sim._work()
	check(sim.state.cells[76].bridge == 0, "defensive bridge cut is performed from the safe bank")
	check(sim.state.factions[1].get("ai_cut", {}).get("pos") == 76, "defensive cut has a cooldown against immediate rebuilding")
	check(sim._reachable(72).has(worker.pos) and not sim._reachable(72).has(80), "cut protects king without stranding its worker")
	# The same defensive decision must refuse to strand an allied village.
	sim.state.cells[76].bridge = 4
	base(sim, 203, 1, 82)
	var planner = Strategy.new(sim)
	planner.team = 1; planner.actors = sim._actors(); planner.units = [worker, sim.get_unit(301)]
	check(planner._defensive_work(sim.get_unit(302)).is_empty(), "defensive engineer refuses a cut that strands a friendly village")
	# A one-cell land choke can be fenced under the same constraints.
	sim = board()
	for pos in range(153):
		if pos / 17 != 4: sim.state.cells[pos].terrain = 3
	sim.state.factions[1].home = 72; sim.state.leaders[1].pos = 72
	base(sim, 200, 1, 69)
	worker = unit(sim, 300, 1, 74, 20)
	unit(sim, 301, 1, 70, 500); unit(sim, 302, 0, 80, 6000, "wait")
	sim._ai()
	check(worker.order == "build_fence", "outmatched country can fence a narrow land approach")
	var gate: int = worker.target; var funds: int = sim.state.factions[1].funds
	sim.get_unit(301).order = "wait" # Keep the independent housing budget out of this cost check.
	for _tick in range(4): sim._movement(); sim._work()
	check(sim.state.cells[gate].fence == 4 and sim.state.factions[1].funds == funds - 1, "defensive fence consumes the same one coin as player construction")
	check(sim.state.factions[1].get("ai_cut", {}).get("pos") == gate, "defensive fence is not immediately cleared by the next route plan")
	# An army inside the radius-three threat map must be able to escape it.
	sim = board(); base(sim, 200, 1, 69)
	worker = unit(sim, 300, 1, 74, 40)
	unit(sim, 302, 0, 77, 1000, "wait")
	sim._ai()
	check(worker.get("ai_job") == "retreat", "overmatched army selects retreat rather than a frozen rally path")
	var before: int = sim._distance(worker.pos, 77)
	sim._movement()
	check(sim._distance(worker.pos, 77) > before, "retreat can leave its current danger bubble")
	# A manual order stays authoritative.
	worker.manual = true; worker.order = "wait"; worker.target = worker.pos
	sim._ai()
	check(worker.order == "wait" and worker.target == worker.pos, "strategic planning preserves manual unit commands")

func test_intent_and_saves() -> void:
	var sim = board(); river(sim); base(sim, 200, 1, 52); base(sim, 201, 0, 78)
	unit(sim, 300, 1, 53, 80, "develop"); var army: Dictionary = unit(sim, 301, 1, 70, 800)
	sim._ai()
	var copy = Core.new()
	check(copy.restore(sim.snapshot()), "engineering intention and fractional taxes survive save/restore")
	for _tick in range(48): sim.step(); copy.step()
	check(copy.state_hash() == sim.state_hash(), "restored engineering game continues deterministically")
	var corrupt: Dictionary = sim.snapshot()
	corrupt.state.units[0]["ai_task"] = {"action": "build_bridge", "target": 999999}
	corrupt.checksum = sim.snapshot_hash(corrupt)
	check(not copy.restore(corrupt), "invalid saved engineering target is rejected atomically")
	corrupt = sim.snapshot(); corrupt.state.bases[0]["tax_credit"] = -1; corrupt.checksum = sim.snapshot_hash(corrupt)
	check(not copy.restore(corrupt), "negative accrued tax is rejected")
	# Autonomous CPU taxes never overwrite the user's slider or own standing order.
	sim = board(); sim.state.factions[0].tax = 23; sim.state.factions[1].funds = 0
	sim._ai()
	check(sim.state.factions[0].tax == 23, "player tax remains entirely under player control")
	check(sim.state.factions[1].tax > 10, "cash-starved CPU raises tax to restore building funds")
	var tax: int = sim.state.factions[1].tax
	sim.state.factions[1].funds = 10000; sim._ai()
	check(sim.state.factions[1].tax == tax, "economic policy has a cooldown instead of flipping every AI pass")
	sim.state.tick += 120; sim._ai()
	check(sim.state.factions[1].tax < tax, "rich CPU lowers taxes to rebuild population")
