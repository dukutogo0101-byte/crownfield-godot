extends SceneTree
# Structural checks for the three original-grammar maps.
# Initial connectivity is intentionally restricted; the current strategic AI can build bridges.
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
		"scope": "Godot headless map structure, paid land-bank construction, all-country connectivity after bridging, and 1200 ticks with current strategic AI; phone and human difficulty not tested.",
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
	verify_openable(spec)
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
	var bridges: int = 0
	for cell in sim.state.cells:
		if cell.bridge > 0: bridges += 1
	return {"bridge_cells": bridges, "tick": sim.state.tick, "day": sim.state.day, "bases": bases, "population": population, "funds": funds, "alive": alive, "result": sim.state.result}


func verify_openable(spec: Dictionary) -> void:
	var sim = Core.new()
	sim.new_game("res://data/maps/" + spec.id + ".json")
	var worker: Dictionary = sim.get_unit(4)
	# Remove opposition only in this construction fixture. Real AI wars are
	# exercised separately above. Do not change terrain or give free bridges.
	sim.state.units = [worker]
	for leader in sim.state.leaders: leader.alive = false
	worker.manual = true
	var funds: int = sim.state.factions[0].funds
	for ford in spec.fords:
		check(sim.can_order(0, "build_bridge", [worker.id], ford), spec.id + " player can reach bank for " + str(ford))
		worker.order = "build_bridge"; worker.target = ford
		for _move in range(160):
			sim._movement(); sim._work()
			if sim.state.cells[ford].bridge > 0: break
		check(sim.state.cells[ford].bridge == 1, spec.id + " bridge completed with normal work " + str(ford))
		check(sim._land(worker.pos) and worker.pos in sim.neighbors(ford), spec.id + " bridge built from adjacent land " + str(ford))
	check(sim.state.factions[0].funds == funds - spec.fords.size() * sim.rules.bridge_new_cost, spec.id + " player pays normal crossing costs")
	for a in range(4):
		for b in range(a + 1, 4):
			check(not sim.path_to(sim.state.factions[a].home, sim.state.factions[b].home).is_empty(), spec.id + " all castles reachable after legal bridges %d-%d" % [a,b])
