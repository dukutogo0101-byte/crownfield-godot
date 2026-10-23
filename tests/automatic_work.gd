extends SceneTree
const Core = preload("res://core/simulation.gd")
var checks: int = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)
func fixture():
	var sim = Core.new()
	sim.new_game()
	sim.state.w = 9; sim.state.h = 9; sim.state.cells = []
	for _cell in 81: sim.state.cells.append({"terrain": 0, "owner": -1, "bridge": 0, "fence": 0, "bridge_built": false})
	sim.state.units = []; sim.state.bases = []; sim.state.next_id = 100
	for team in 4:
		var home: int = [0, 8, 72, 80][team]
		sim.state.factions[team].home = home; sim.state.factions[team].funds = 1000
		sim.state.leaders[team].pos = home; sim.state.leaders[team].target = home; sim.state.leaders[team].power = 100
		sim.state.bases.append({"id": 80 + team, "team": team, "pos": home, "pop": 32})
	sim.state.units.append({"id": 91, "team": 0, "pos": 20, "target": 20, "power": 800, "order": "wait", "auto_mode": "", "manual": true, "king": false})
	return sim
func bridge_fixture():
	var sim = fixture()
	for pos in [22, 31]: sim.state.cells[pos].terrain = 2
	return sim
func assign(sim, mode: String) -> Dictionary:
	var command: Dictionary = sim.issue(mode, [91])
	check(command.accepted and command.target == -1, "mode needs no clicked destination: " + mode)
	sim.step([command])
	return sim.get_unit(91)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for mode in Core.Automation.WORK_MODES:
		var sim = fixture()
		var u = assign(sim, mode)
		check(u.auto_mode == mode and not u.manual, "mode stays dedicated: " + mode)
		var restored = Core.new()
		check(restored.restore(sim.snapshot()) and restored.get_unit(91).auto_mode == mode, "save restores mode: " + mode)
		check(not sim.issue(mode, [sim.state.leaders[0].id]).accepted, "leader cannot use mode: " + mode)
		var initial: Dictionary = sim.issue("initial_order", [], -1, {"order": mode})
		sim.step([initial])
		check(sim.state.factions[0].initial_order == mode, "initial setting accepts mode: " + mode)
		sim._ai()
		check(u.auto_mode == mode and u.get("ai_job", "") == "work", "strategy cannot steal dedicated job: " + mode)
	# Build four durability, pay normal new/repair prices, then move on immediately.
	var sim = bridge_fixture()
	var u = assign(sim, "auto_build_bridge")
	check(u.order == "build_bridge" and u.target == 22, "bridge worker selects nearby useful crossing")
	u.pos = 21
	for _work in 4: sim._work()
	check(sim.state.cells[22].bridge == 4 and sim.state.factions[0].funds == 964, "bridge uses four actual work phases and normal 30+2+2+2 costs")
	check(u.order == "build_bridge" and u.target == 31 and u.pos == 21, "finished bridge immediately selects next crossing from land")
	sim.state.factions[0].funds = 0
	sim._movement()
	check(u.order == "wait" and u.pos == 21 and u.auto_mode == "auto_build_bridge", "unaffordable worker stops in place without attacking")
	sim.state.factions[0].funds = 100
	sim._ai()
	check(u.order == "build_bridge", "restored funds resume same job")
	var restored = Core.new()
	check(restored.restore(sim.snapshot()), "active bridge save restores")
	for _tick in 12: sim.step(); restored.step()
	check(sim.state_hash() == restored.state_hash(), "saved work continues deterministically")
	# Resource races between workers cannot spend money they do not have.
	sim = bridge_fixture(); u = assign(sim, "auto_build_bridge")
	var second: Dictionary = u.duplicate(true); second.id = 92; second.pos = 30; second.target = 31
	sim.state.units.append(second); sim.state.factions[0].funds = 30; u.pos = 21
	Core.Automation.plan(sim)
	check(u.target != second.target, "workers reserve distinct bridge sites")
	sim._work(); sim._movement()
	check(sim.state.factions[0].funds == 0 and sim.state.cells[22].bridge + sim.state.cells[31].bridge == 1, "shared money is charged once, never overdrafted")
	# Repeated clearing and sealing chain without waiting for the 24-tick AI cycle.
	for mode in ["auto_reclaim", "auto_seal_cave", "auto_destroy_fence"]:
		sim = fixture()
		for pos in [21, 22]:
			if mode == "auto_reclaim": sim.state.cells[pos].terrain = 1
			elif mode == "auto_seal_cave": sim.state.cells[pos].terrain = 3
			else: sim.state.cells[pos].fence = 4; sim.state.cells[pos].owner = 1
		u = assign(sim, mode)
		check(u.target == 21, "clearing selects nearest target: " + mode)
		if mode == "auto_reclaim": u.pos = 21
		sim._work()
		check(u.target == 22 and u.auto_mode == mode, "clearing immediately chains: " + mode)
		if mode == "auto_reclaim": u.pos = 22
		else: u.pos = 21
		sim._work()
		check(u.order == "wait" and u.target == u.pos and u.auto_mode == mode, "completed clearing waits with intent: " + mode)
	# Destruction never selects our villages or any home castle.
	sim = fixture()
	sim.state.bases.append({"id": 94, "team": 0, "pos": 21, "pop": 32})
	sim.state.bases.append({"id": 95, "team": 1, "pos": 22, "pop": 32})
	sim.state.bases.append({"id": 96, "team": 1, "pos": 40, "pop": 32})
	u = assign(sim, "auto_destroy_base"); u.pos = 21
	sim._work()
	check(not sim.get_base(21).is_empty() and sim.get_base(22).is_empty() and u.target == 40, "enemy demolition spares own village and chains to next enemy village")
	check(not Core.Automation.target_valid(sim, u, "destroy_base", 8), "home castles are excluded from demolition")
	u.pos = 39; sim._movement()
	check(sim.get_base(40).is_empty() and u.order == "wait", "village destroyed on arrival also immediately finishes the job")
	# Enemy bridges and border fences use the same adjacent-land work rules.
	sim = bridge_fixture(); sim.state.cells[22].bridge = 4; sim.state.cells[23].owner = 1
	u = assign(sim, "auto_destroy_bridge"); u.pos = 21; sim._work()
	check(sim.state.cells[22].bridge == 0 and u.order == "wait", "bridge demolition works from adjacent land then waits")
	sim = fixture(); sim.state.cells[21].owner = 0; sim.state.cells[22].owner = 1
	u = assign(sim, "auto_build_fence"); sim._work()
	check(sim.state.cells[21].fence == 4 and sim.state.factions[0].funds == 999 and u.order == "wait", "border fence charges normal price and does not build indefinitely")
	# New recruits inherit engineering and start planning immediately at birth.
	sim = bridge_fixture(); sim.state.units.clear()
	sim.state.factions[0].initial_order = "auto_build_bridge"
	sim.state.bases[0].pop = 1000
	for pos in sim.around(0): sim.state.cells[pos].owner = 0
	sim._population()
	check(sim.state.units.size() == 1 and sim.state.units[0].auto_mode == "auto_build_bridge" and sim.state.units[0].order == "build_bridge", "new recruit receives and plans the initial engineering command")
	# Manual cancellation clears the job, so a later AI update cannot revive it.
	sim = bridge_fixture(); u = assign(sim, "auto_build_bridge")
	sim.step([sim.issue("wait", [91])]); sim._ai()
	check(u.manual and u.auto_mode == "" and u.order == "wait", "manual single order cancels continuous work")
	# A construction job never destroys an unrelated enemy village to reach work.
	sim = bridge_fixture()
	for cell in sim.state.cells: cell.terrain = 3
	for pos in [20, 21, 23]: sim.state.cells[pos].terrain = 0
	sim.state.cells[22].terrain = 2
	sim.state.bases.append({"id": 94, "team": 1, "pos": 21, "pop": 1})
	u = assign(sim, "auto_build_bridge")
	check(u.order == "wait" and u.pos == 20, "blocked crossing makes builder wait instead of attacking the village")
	sim.state.bases.erase(sim.get_base(21)); sim._ai()
	check(u.order == "build_bridge" and u.target == 22, "same bridge job resumes when the route opens")
	# Enemy control around a crossing prevents a work-only unit approaching it.
	sim = bridge_fixture()
	sim.state.leaders[1].pos = 23; sim.state.leaders[1].power = 10000
	u = assign(sim, "auto_build_bridge")
	check(u.order == "wait" and u.pos == 20 and u.auto_mode == "auto_build_bridge", "dangerous work stays dedicated and waits")
	var report = {"checks": checks, "passed": checks - failures.size(), "failed": failures}
	var file = FileAccess.open("res://tests/automatic_work_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("AUTOMATIC WORK ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)
