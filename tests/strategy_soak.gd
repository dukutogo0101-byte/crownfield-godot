extends SceneTree
const Core = preload("res://core/simulation.gd")
var failures: Array = []
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cases: Array = []
	for map_id in ["four_rivers", "open_plains", "twin_crossings", "borderlands"]:
		var sim = Core.new(); check(sim.new_game("res://data/maps/" + map_id + ".json"), map_id + " loads")
		var ticks: int = 3600 if map_id == "four_rivers" else 1200
		var peaks: Array = [2, 2, 2, 2]
		var jobs: Dictionary = {}; var phases: Dictionary = {}; var samples: Array = []
		var began: int = Time.get_ticks_msec()
		for _tick in range(ticks):
			sim.step()
			if sim.state.tick % 24 == 0:
				var counts: Array = [0, 0, 0, 0]
				for b in sim.state.bases: counts[b.team] += 1
				for team in range(4): peaks[team] = maxi(peaks[team], counts[team])
				for u in sim.state.units:
					if u.team > 0:
						var job: String = u.get("ai_job", "none"); jobs[job] = int(jobs.get(job, 0)) + 1
				for team in range(1, 4):
					var phase: String = sim.state.factions[team].get("ai_plan", {}).get("phase", "none")
					phases[phase] = int(phases.get(phase, 0)) + 1
				if sim.state.tick % 240 == 0:
					var row: Dictionary = {"tick": sim.state.tick, "bases": counts, "funds": [], "population": [], "combat_losses": sim.state.combat_losses.duplicate(), "alive": []}
					for team in range(4):
						row.funds.append(sim.state.factions[team].funds); row.population.append(sim.population(team)); row.alive.append(sim.state.factions[team].alive)
					samples.append(row); print("STRATEGY SOAK ", map_id, " ", JSON.stringify(row))
			if sim.state.result != "playing": break
		check(jobs.get("attack", 0) > 0, map_id + " enemies actually launch attacks")
		check(sim.state.combat_losses[1] + sim.state.combat_losses[2] + sim.state.combat_losses[3] > 0, map_id + " attacks produce real combat, not orders alone")
		var developed: int = 0
		for team in range(1, 4):
			if peaks[team] > 7: developed += 1
			check(sim.state.factions[team].funds >= 0, map_id + " country has no negative funds " + str(team))
		check(developed >= 2, map_id + " at least two enemies develop beyond seven villages")
		var resumed = Core.new(); check(resumed.restore(sim.snapshot()), map_id + " late-game save is valid")
		for _tick in range(24): sim.step(); resumed.step()
		check(sim.state_hash() == resumed.state_hash(), map_id + " late-game save continues identically")
		cases.append({"map": map_id, "tick": sim.state.tick, "result": sim.state.result, "peak_bases": peaks, "job_observations": jobs, "phase_observations": phases, "samples": samples, "hash": sim.state_hash(), "elapsed_ms": Time.get_ticks_msec() - began})
	FileAccess.open("res://tests/strategy_soak_results.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "passed": checks - failures.size(), "failed": failures, "cases": cases, "scope": "AI-only Godot headless games, up to 3600 ticks on default map and 1200 on each additional map; not human difficulty or real-device performance"}, "\t"))
	print("STRATEGY SOAK RESULT ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)
