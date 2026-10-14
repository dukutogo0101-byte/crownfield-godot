extends SceneTree
# Explicit maintainer operation. Normal tests only read frozen golden.
const Core = preload("res://core/simulation.gd")
func _initialize() -> void:
	var sim = Core.new()
	sim.new_game()
	var points: Array = [{"tick":0,"hash":sim.state_hash()}]
	for tick in range(320):
		var due: Array = []
		if tick == 8: due.append(sim.issue("wait",[4]))
		if tick == 30: due.append(sim.issue("auto",[4]))
		if tick == 80: due.append(sim.issue("move",[1],164))
		sim.step(due)
		if sim.state.tick % 32 == 0: points.append({"tick":sim.state.tick,"hash":sim.state_hash()})
	var record := {"format":1,"classification":"C","description":"Frozen regression of this experimental kernel. Not measured original Windows behavior.","replay":sim.export_replay(),"checkpoints":points}
	var f := FileAccess.open("res://tests/golden/regression.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(record,"\t"))
	print("Recorded experimental golden: ",points.size()," checkpoints; run tests separately")
	quit()
