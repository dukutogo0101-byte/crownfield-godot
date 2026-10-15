extends SceneTree
# Structural checks for the three original-grammar maps.
# Some castle pairs are intentionally cut by unbridged water. CPU nations do not build bridges.
const Core = preload("res://core/simulation.gd")
const TICKS := 1200
var checks: int = 0
var failures: Array = []

const CASES := [
	{
		"id": "succession_isthmus",
		"linked": [[0, 1], [1, 2], [0, 2]],
		"sealed": [[0, 3], [1, 3], [2, 3]],
		"gates": [13 * 40 + 18, 13 * 40 + 19],
		"fords": [17 * 40 + 8],
	},
	{
		"id": "half_sea",
		"linked": [[0, 3], [1, 2]],
		"sealed": [[0, 1], [0, 2], [3, 1], [3, 2]],
		"gates": [],
		"fords": [6 * 40 + 17],
	},
	{
		"id": "spiral_channel",
		"linked": [],
		"sealed": [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]],
		"gates": [],
		"fords": [20 * 40 + 15, 14 * 40 + 30, 6 * 40 + 17],
	},
]

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var maps: Array = []
	for spec in CASES:
		maps.append(play(spec))
	var report := {
		"checks": checks,
		"passed": checks - failures.size(),
		"failed": failures,
		"engine": Engine.get_version_info().string,
		"ticks": TICKS,
		"scope": "Headless original-grammar maps. Not a copy of a Falcom stage, not a human 600-day play, not UI registration.",
		"maps": maps,
	}
	var file := FileAccess.open("res://tests/map_original_grammar_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("GRAMMAR ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)

func play(spec: Dictionary) -> Dictionary:
	var map_id: String = spec.id
	var sim = Core.new()
	check(sim.new_game("res://data/maps/%s.json" % map_id), map_id + " new_game")
	check(sim.restore(sim.snapshot()), map_id + " restore")
	var homes: Array = []
	for faction in sim.state.factions:
		homes.append(faction.home)
	for pair in spec.linked:
		check(not sim.path_to(homes[pair[0]], homes[pair[1]]).is_empty(), map_id + " link %d-%d" % [pair[0], pair[1]])
	for pair in spec.sealed:
		check(sim.path_to(homes[pair[0]], homes[pair[1]]).is_empty(), map_id + " sealed %d-%d" % [pair[0], pair[1]])
	for base in sim.state.bases:
		check(sim.can_tax(base), map_id + " tax " + str(base.id))
	for gate in spec.gates:
		var built: Dictionary = sim.state.cells[gate]
		check(built.terrain == 2 and built.bridge > 0 and built.bridge_built, map_id + " standing bridge " + str(gate))
	for ford in spec.fords:
		var water: Dictionary = sim.state.cells[ford]
		check(water.terrain == 2 and water.bridge == 0, map_id + " unbridged ford " + str(ford))
		var bank := false
		for side in sim.neighbors(ford):
			if sim._land(side):
				bank = true
		check(bank, map_id + " ford has a bank " + str(ford))
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
			print("GRAMMAR ", map_id, " ", JSON.stringify(samples[-1]))
	var end: Dictionary = sample(sim)
	if samples[-1].tick != end.tick:
		samples.append(end)
	for team in range(4):
		check(peak[team] > start[team], map_id + " team %d developed" % team)
	return {"id": map_id, "name": sim.state.name, "start_bases": start, "peak_bases": peak, "end": end, "samples": samples, "outcome": sim.state.result}

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
