extends SceneTree
const Core = preload("res://core/simulation.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var sim = Core.new()
	sim.new_game()
	var points: Array=[{"tick":0,"hash":sim.state_hash()}]
	var start:=Time.get_ticks_msec()
	for _t in range(3600):
		var due: Array=[]
		if sim.state.tick >= 240 and sim.state.tick % 24 == 0:
			var king: Dictionary=sim.state.leaders[0]
			var troop_ids: Array=[]
			for u in sim.state.units:
				if u.team==0:troop_ids.append(u.id)
			if not troop_ids.is_empty():due.append(sim.issue("reinforce",troop_ids,king.pos))
			var target: int=-1
			var weakest: int=2147483647
			for enemy in sim.state.leaders:
				if enemy.team==0 or not enemy.alive:continue
				if king.power > enemy.power * sim._castle_factor(enemy) * 5 / 4 and enemy.power<weakest and not sim.path_to(king.pos,enemy.pos).is_empty():
					weakest=enemy.power;target=enemy.pos
			if target>=0:due.append(sim.issue("move",[king.id],target))
			elif king.pos!=sim.state.factions[0].home and king.order=="wait":due.append(sim.issue("move",[king.id],sim.state.factions[0].home))
		sim.step(due)
		points.append({"tick":sim.state.tick,"hash":sim.state_hash()})
		if sim.state.result!="playing":break
	var replay: Dictionary=sim.export_replay()
	var verify = Core.new()
	verify.new_game()
	var complete: bool=verify.load_replay(JSON.parse_string(JSON.stringify(replay)))
	var replay_exact: bool=complete and verify.state_hash()==sim.state_hash()
	var checkpoint_sim=Core.new()
	checkpoint_sim.new_game()
	var checkpoint_exact: bool=checkpoint_sim.restore(JSON.parse_string(JSON.stringify(replay.initial_state)))
	var log: Array=checkpoint_sim._integers(JSON.parse_string(JSON.stringify(replay.commands)))
	for checkpoint in points:
		while checkpoint_sim.state.tick<int(checkpoint.tick):
			var due: Array=[]
			for command in log:
				if command.tick==checkpoint_sim.state.tick+1:due.append(command)
			checkpoint_sim.step(due)
		if checkpoint_sim.state_hash()!=checkpoint.hash:checkpoint_exact=false;break
	var record: Dictionary={"format":1,"classification":"C","description":"Default Four Rivers; only ordinary player commands, no state cheats. Experimental rules, not original measured fidelity.","result":sim.state.result,"tick":sim.state.tick,"commands_count":replay.commands.size(),"replay_verified":replay_exact,"all_checkpoints_verified":checkpoint_exact,"elapsed_ms":Time.get_ticks_msec()-start,"replay":replay,"checkpoints":points}
	var f:=FileAccess.open("res://tests/golden/winning_playthrough.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(record,"\t"))
	print("PLAYTHROUGH ",sim.state.result," tick=",sim.state.tick," commands=",replay.commands.size()," exact_replay=",replay_exact," all_checkpoints=",checkpoint_exact)
	quit(0 if sim.state.result=="victory" and replay_exact and checkpoint_exact else 1)
