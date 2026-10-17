extends SceneTree
# Room trace of the Foods Panic opening stage. Not a Falcom cell dump.
const Core = preload("res://core/simulation.gd")
const TICKS := 1200
const W := 48
var checks: int = 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	verify_crossing()
	var report_map: Dictionary = play()
	var report := {
		"checks": checks,
		"passed": checks - failures.size(),
		"failed": failures,
		"engine": Engine.get_version_info().string,
		"ticks": TICKS,
		"scope": "Headless shop-crossing trace. Not a Falcom stage file, not a human 600-day play, UI registration is covered separately by map_selection_ui.gd.",
		"map": report_map,
	}
	var file := FileAccess.open("res://tests/map_shop_crossing_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("SHOP ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)

func play() -> Dictionary:
	var sim = Core.new()
	check(sim.new_game("res://data/maps/shop_crossing.json"), "new_game")
	check(sim.restore(sim.snapshot()), "restore")
	check(sim.state.w == W and sim.state.h == W, "48x48")
	var homes: Array = []
	for faction in sim.state.factions:
		homes.append(faction.home)
	for a in range(4):
		for b in range(a + 1, 4):
			check(not sim.path_to(homes[a], homes[b]).is_empty(), "kings linked %d-%d" % [a, b])
	for base in sim.state.bases:
		var taxed: bool = sim.can_tax(base)
		if base.team == 1:
			check(not taxed, "sealed shop has no tax " + str(base.id))
			check(sim.path_to(homes[0], base.pos).is_empty(), "sealed village " + str(base.id))
		else:
			check(taxed, "tax " + str(base.id))
	var standing: int = 45 * W + 12
	var ford: int = 20 * W + 41
	var built: Dictionary = sim.state.cells[standing]
	check(built.terrain == 2 and built.bridge > 0 and built.bridge_built, "standing crossing")
	var water: Dictionary = sim.state.cells[ford]
	check(water.terrain == 2 and water.bridge == 0, "unbridged crossing")
	var bank := false
	for side in sim.neighbors(ford):
		if sim._land(side):
			bank = true
	check(bank, "ford has a bank")
	var start := [0, 0, 0, 0]
	for base in sim.state.bases:
		start[base.team] += 1
	var peak := start.duplicate()
	var samples: Array = [sample(sim)]
	for _tick in range(TICKS):
		if sim.state.result != "playing":
			break
		sim.step([])
		var counts := [0, 0, 0, 0]
		for base in sim.state.bases:
			counts[base.team] += 1
		for team in range(4):
			peak[team] = maxi(peak[team], counts[team])
		if sim.state.tick % 240 == 0:
			samples.append(sample(sim))
			print("SHOP ", JSON.stringify(samples[-1]))
	var end: Dictionary = sample(sim)
	if samples[-1].tick != end.tick:
		samples.append(end)
	for team in range(4):
		check(peak[team] > start[team], "team %d developed" % team)
	return {"id": "shop_crossing", "name": sim.state.name, "start_bases": start, "peak_bases": peak, "end": end, "samples": samples, "outcome": sim.state.result}

func sample(sim) -> Dictionary:
	var bases := [0, 0, 0, 0]
	var population := [0, 0, 0, 0]
	var funds := [0, 0, 0, 0]
	var alive := [false, false, false, false]
	for base in sim.state.bases:
		bases[base.team] += 1
	for team in range(4):
		population[team] = sim.population(team)
		funds[team] = sim.state.factions[team].funds
		alive[team] = sim.state.factions[team].alive
	return {"tick": sim.state.tick, "day": sim.state.day, "bases": bases, "population": population, "funds": funds, "alive": alive, "result": sim.state.result}

func verify_crossing() -> void:
	var sim = Core.new()
	sim.new_game("res://data/maps/shop_crossing.json")
	var worker: Dictionary = sim.get_unit(4)
	sim.state.units = [worker]
	for leader in sim.state.leaders: leader.alive = false
	worker.manual = true
	var ford: int = 20 * W + 41
	var funds: int = sim.state.factions[0].funds
	check(sim.can_order(0, "build_bridge", [worker.id], ford), "player can order bridge on the sealed shop crossing")
	worker.order = "build_bridge"; worker.target = ford
	for _move in range(240):
		sim._movement(); sim._work()
		if sim.state.cells[ford].bridge > 0: break
	check(sim.state.cells[ford].bridge == 1, "sealed crossing opens through normal work")
	check(sim._land(worker.pos) and worker.pos in sim.neighbors(ford), "construction uses the adjacent land bank")
	check(sim.state.factions[0].funds == funds - sim.rules.bridge_new_cost, "crossing uses the normal construction price")
	for base in sim.state.bases:
		if base.team == 1:
			check(not sim.path_to(sim.state.factions[0].home, base.pos).is_empty(), "red shop village reachable after paid bridge " + str(base.id))
