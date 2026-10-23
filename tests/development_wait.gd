extends SceneTree
const Core = preload("res://core/simulation.gd")
var checks: int = 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)

func fixture(mode: String = "develop"):
	var sim = Core.new()
	sim.new_game()
	sim.state.w = 9; sim.state.h = 9; sim.state.cells = []
	for _cell in range(81): sim.state.cells.append({"terrain": 0, "owner": -1, "bridge": 0, "fence": 0, "bridge_built": false})
	sim.state.units = []; sim.state.bases = []; sim.state.next_id = 100
	for team in range(4):
		var home: int = [0, 8, 72, 80][team]
		sim.state.factions[team].home = home
		sim.state.factions[team].funds = 1000
		sim.state.leaders[team].pos = home; sim.state.leaders[team].target = home
		sim.state.leaders[team].power = 100
		sim.state.bases.append({"id": 80 + team, "team": team, "pos": home, "pop": 32})
	sim.state.units.append({"id": 91, "team": 0, "pos": 20, "target": 20, "power": 800, "order": mode, "auto_mode": mode, "manual": false, "king": false, "ai_job": "develop"})
	return sim

func _initialize() -> void: call_deferred("run")

func run() -> void:
	# Include the ordinary auto worker: lack of money used to remove it from the
	# builder budget and let the combat planner take ownership of the unit.
	for mode in ["develop", "auto"]:
		var sim = fixture(mode)
		var worker: Dictionary = sim.get_unit(91)
		sim.state.factions[0].funds = 0
		for _pass in range(3): sim._ai(); sim._movement(); sim._work()
		check(worker.pos == 20 and worker.target == 20 and worker.order == "wait", mode + " waits in place without money")
		check(worker.ai_job == "develop" and worker.auto_mode == mode, mode + " retains construction assignment")
		check(sim.state.bases.size() == 4, mode + " cannot construct for free")
		var copy = Core.new()
		check(copy.restore(sim.snapshot()), mode + " waiting save restores")
		sim.state.factions[0].funds = 200; copy.state.factions[0].funds = 200
		sim._ai(); copy._ai()
		check(worker.order == "build_base" and worker.ai_job == "develop", mode + " automatically resumes building when money returns")
		check(sim.state_hash() == copy.state_hash(), mode + " restored intention resumes identically")
		for _pass in range(5): sim._movement(); sim._work()
		check(sim.state.bases.size() > 4, mode + " resumed worker actually builds")
	var sim = fixture()
	var worker: Dictionary = sim.get_unit(91)
	worker.power = sim.rules.build_population
	sim._ai(); sim._movement()
	check(worker.pos == 20 and worker.order == "wait" and worker.ai_job == "develop", "insufficient people waits without a rally or attack")
	worker.power = 100
	sim._ai()
	check(worker.order == "build_base", "recovered manpower resumes construction")
	sim = fixture(); worker = sim.get_unit(91)
	worker.order = "build_base"; sim.state.factions[0].funds = sim.rules.build_cost
	sim._work()
	check(sim.state.factions[0].funds == 0 and worker.pos == 20 and worker.order == "wait", "last paid construction immediately waits when funds run out")
	sim._ai(); sim._movement()
	check(worker.pos == 20 and worker.order == "wait", "waiting completion never turns into a combat assignment")
	# A blocked / full building region must not trigger a rally either.
	sim = fixture(); worker = sim.get_unit(91)
	for cell in sim.state.cells: cell.terrain = 2
	sim.state.cells[20].terrain = 0
	sim.state.bases[0].pos = 20
	sim._ai(); sim._movement()
	check(worker.order == "wait" and worker.pos == 20, "no reachable building site waits in place")
	# Legacy saves can still contain the old explicit-development rally movement.
	sim = fixture(); worker = sim.get_unit(91)
	worker.order = "move"; worker.target = 0; worker.ai_job = "rally"
	sim._movement()
	check(worker.order == "wait" and worker.pos == 20 and worker.ai_job == "develop", "legacy housing rally is stopped before the next AI tick")
	# Manual single-site commands retain their exact destination while blocked.
	sim = fixture(); worker = sim.get_unit(91)
	worker.manual = true; worker.auto_mode = ""; worker.order = "build_base"; worker.target = 22
	sim.state.factions[0].funds = 0
	sim._ai(); sim._movement()
	check(worker.pos == 20 and worker.order == "build_base" and worker.target == 22, "manual construction waits and retains its destination")
	sim.state.factions[0].funds = 100
	sim._movement()
	check(worker.pos != 20 and worker.target == 22, "manual construction resumes toward the same destination")
	# Explicitly replacing the order still releases the worker.
	sim = fixture(); worker = sim.get_unit(91)
	sim.step([sim.issue("move", [91], 22)])
	check(worker.manual and worker.auto_mode == "" and not worker.has("ai_job"), "a new manual command cancels the construction assignment")
	var file = FileAccess.open("res://tests/development_wait_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failed": failures}, "\t")); file.close()
	print("DEVELOPMENT WAIT ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)
