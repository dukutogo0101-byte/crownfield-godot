extends SceneTree
const Core = preload("res://core/simulation.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var runs: Array = []
	for run_id in range(3):
		var sim = Core.new()
		sim.new_game()
		var peak_units: int = sim.state.units.size()
		var sampled: Array = []
		var start := Time.get_ticks_msec()
		for _tick in range(1200):
			sim.step([])
			peak_units = maxi(peak_units,sim.state.units.size())
			if sim.state.tick % 120 == 0:
				var populations: Array = []
				var funds: Array = []
				for faction in sim.state.factions:
					funds.append(faction.funds)
					var total: int = 0
					for base in sim.state.bases:
						if base.team == faction.id: total += base.pop
					for unit in sim.state.units:
						if unit.team == faction.id: total += unit.power
					populations.append(total)
				sampled.append({"tick":sim.state.tick,"units":sim.state.units.size(),"bases":sim.state.bases.size(),"population":populations,"funds":funds})
			if sim.state.result != "playing": break
		runs.append({"run":run_id,"ticks":sim.state.tick,"elapsed_ms":Time.get_ticks_msec()-start,"outcome":sim.state.result,"peak_units":peak_units,"final_hash":sim.state_hash(),"samples":sampled})
	var identical: bool = runs[0].final_hash == runs[1].final_hash and runs[1].final_hash == runs[2].final_hash
	var report := {"scope":"three repeat runs, one deterministic map; not statistical original AI fidelity","deterministic":identical,"runs":runs}
	var f := FileAccess.open("res://tests/simulation_stats.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	print("SIM STATS ", "PASS" if identical else "FAIL", ": 3 repeat runs; ticks=",runs[0].ticks," outcome=",runs[0].result," peak_units=",runs[0].peak_units)
	quit(0 if identical else 1)
