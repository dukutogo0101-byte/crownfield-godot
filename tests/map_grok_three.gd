extends SceneTree
# New-map contract checks for the three Grok maps. Does not load golden
# fixtures and does not touch four_rivers. Selection UI is out of scope.
const Core = preload("res://core/simulation.gd")
const MAPS := ["open_plains", "twin_crossings", "borderlands"]
const TICKS := 1200
var checks: int = 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL ", label)

func around(sim, pos: int) -> Array:
	return sim.around(pos)

func run() -> void:
	var maps: Array = []
	for map_id in MAPS:
		maps.append(play(map_id))
	var report := {
		"checks": checks,
		"passed": checks - failures.size(),
		"failed": failures,
		"engine": Engine.get_version_info().string,
		"ticks": TICKS,
		"scope": "Headless new-map load, tax roads, castle reachability and 1200-tick development. Not selection UI, web export, or a human playtest.",
		"maps": maps,
	}
	var file := FileAccess.open("res://tests/map_grok_three_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MAP GROK ", checks - failures.size(), "/", checks, " failed=", failures.size())
	quit(0 if failures.is_empty() else 1)

func play(map_id: String) -> Dictionary:
	var path := "res://data/maps/%s.json" % map_id
	var sim = Core.new()
	check(sim.new_game(path), map_id + " new_game")
	check(sim.restore(sim.snapshot()), map_id + " snapshot restore")
	check(sim.state.w == 40 and sim.state.h == 26, map_id + " size 40x26")
	check(sim.state.factions.size() == 4 and sim.state.leaders.size() == 4, map_id + " four nations")
	var homes: Array = []
	for faction in sim.state.factions:
		homes.append(faction.home)
		var king = sim.state.leaders[faction.id]
		check(king.pos == faction.home and king.king == true, map_id + " king home " + str(faction.id))
	for i in range(4):
		for j in range(i + 1, 4):
			check(not sim.path_to(homes[i], homes[j]).is_empty(), map_id + " castles reachable %d-%d" % [i, j])
	var seen_ids := {}
	var seen_pos := {}
	for base in sim.state.bases:
		check(sim.can_tax(base), map_id + " initial tax " + str(base.id))
		check(not seen_ids.has(base.id) and not seen_pos.has(base.pos), map_id + " unique base " + str(base.id))
		seen_ids[base.id] = true
		seen_pos[base.pos] = true
		for other in sim.state.bases:
			if other.id != base.id and other.team == base.team:
				check(other.pos not in around(sim, base.pos), map_id + " village spacing %d/%d" % [base.id, other.id])
	for unit in sim.state.units:
		check(not seen_ids.has(unit.id) and not seen_pos.has(unit.pos), map_id + " unique unit " + str(unit.id))
		seen_ids[unit.id] = true
		seen_pos[unit.pos] = true
		check(sim._passable(unit.pos), map_id + " unit passable " + str(unit.id))
	var start_bases := [0, 0, 0, 0]
	for base in sim.state.bases:
		start_bases[base.team] += 1
	var peak_bases := start_bases.duplicate()
	var samples: Array = [sample(sim)]
	var stuck: Dictionary = {}
	var began := Time.get_ticks_msec()
	for _tick in range(TICKS):
		if sim.state.result != "playing":
			break
		sim.step([])
		var counts := [0, 0, 0, 0]
		for base in sim.state.bases:
			counts[base.team] += 1
		for team in range(4):
			peak_bases[team] = maxi(peak_bases[team], counts[team])
		if sim.state.tick % 120 == 0:
			samples.append(sample(sim))
			note_stuck(sim, stuck)
			print("MAP ", map_id, " ", JSON.stringify(samples[-1]))
	var end: Dictionary = sample(sim)
	if samples.is_empty() or samples[-1].tick != end.tick:
		samples.append(end)
	for team in range(4):
		var faction = sim.state.factions[team]
		var grew: bool = peak_bases[team] > start_bases[team]
		if faction.alive and not grew:
			failures.append(map_id + " living team %d never founded a village" % team)
			checks += 1
		else:
			checks += 1
	var stalled: Array = []
	for unit_id in stuck:
		var info: Dictionary = stuck[unit_id]
		if int(info.still) >= 4:
			stalled.append({"id": unit_id, "team": info.team, "pos": info.pos, "order": info.order, "samples": info.still})
	return {
		"id": map_id,
		"name": sim.state.name if sim.state.has("name") else map_id,
		"start_bases": start_bases,
		"peak_bases": peak_bases,
		"end": end,
		"samples": samples,
		"stalled_units": stalled,
		"outcome": sim.state.result,
		"winner": sim.state.winner,
		"elapsed_ms": Time.get_ticks_msec() - began,
		"final_hash": sim.state_hash(),
	}

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
	return {
		"tick": sim.state.tick,
		"day": sim.state.day,
		"bases": bases,
		"population": population,
		"funds": funds,
		"alive": alive,
		"result": sim.state.result,
	}

func note_stuck(sim, stuck: Dictionary) -> void:
	for unit in sim.state.units:
		if unit.order not in ["move", "build_base", "build_village", "reclaim"]:
			stuck.erase(unit.id)
			continue
		if not stuck.has(unit.id) or stuck[unit.id].pos != unit.pos or stuck[unit.id].order != unit.order:
			stuck[unit.id] = {"team": unit.team, "pos": unit.pos, "order": unit.order, "still": 1}
		else:
			stuck[unit.id].still = int(stuck[unit.id].still) + 1

func _initialize() -> void:
	call_deferred("run")
