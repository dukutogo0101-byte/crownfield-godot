extends SceneTree
# Run the identical script against two source checkouts. Timings are CPU work
# in the native headless engine, not browser FPS or a phone performance claim.
const Core = preload("res://core/simulation.gd")
var output: Array = []
func stats(values: Array) -> Dictionary:
	var ordered: Array = values.duplicate(); ordered.sort()
	var total: int = 0
	for value in ordered: total += value
	return {"count": ordered.size(), "mean_ms": float(total) / maxi(1, ordered.size()) / 1000, "p95_ms": float(ordered[mini(ordered.size()-1, int(ordered.size()*0.95))]) / 1000, "max_ms": float(ordered[-1])/1000}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for label in ["fresh", "late"]:
		var ticks: Array = []; var ai_ticks: Array = []; var hashes: Array = []; var hash_times: Array = []
		for _repeat in range(3):
			var sim = Core.new()
			if label == "fresh": sim.new_game()
			else:
				var saved = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pre_ai_fix_stalemate.json"))
				assert(sim.restore(saved))
			for _tick in range(120):
				var began: int = Time.get_ticks_usec(); sim.step()
				var elapsed: int = Time.get_ticks_usec() - began
				ticks.append(elapsed)
				if sim.state.tick % sim.rules.ai_period == 0: ai_ticks.append(elapsed)
			var began: int = Time.get_ticks_usec(); hashes.append(sim.state_hash()); hash_times.append(Time.get_ticks_usec() - began)
		var result: Dictionary = {"case": label, "ticks": stats(ticks), "ai_ticks": stats(ai_ticks), "hashing": stats(hash_times), "hashes": hashes}
		output.append(result); print("BENCHMARK ", JSON.stringify(result))
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = arguments[0] if not arguments.is_empty() else "res://tests/performance_benchmark_results.json"
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify({"engine": Engine.get_version_info().string, "scope": "Native Godot headless CPU, three repetitions of each 120-tick case. Not real-device FPS.", "cases": output}, "\t"))
	quit()
