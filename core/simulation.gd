extends RefCounted
const Path = preload("res://core/pathfinder.gd")
const Combat = preload("res://core/combat_resolver.gd")
const ACTIONS := ["move", "wait", "auto", "defend", "reinforce", "destroy_base", "build_base", "destroy_village", "build_village", "build_fence", "build_bridge", "reclaim", "destroy_fence", "destroy_bridge", "seal_cave", "tax", "initial_order"]
var state: Dictionary = {}
var rules: Dictionary = {}
var command_log: Array = []
var issued_sequence: int = 0
var pending: Array = []
var replay_origin: Dictionary = {}

func new_game(map_path: String = "res://data/maps/four_rivers.json", rules_path: String = "res://data/rulesets/playable_experimental.json") -> bool:
	if not FileAccess.file_exists(map_path) or not FileAccess.file_exists(rules_path):return false
	var loaded_rules = JSON.parse_string(FileAccess.get_file_as_string(rules_path))
	var loaded_map = JSON.parse_string(FileAccess.get_file_as_string(map_path))
	if not loaded_rules is Dictionary or not loaded_map is Dictionary or not loaded_rules.get("playable",false):return false
	rules = _integers(loaded_rules)
	state = _integers(JSON.parse_string(FileAccess.get_file_as_string(map_path)))
	state.merge({"tick":0,"day":0,"limit_days":rules.get("limit_days",600),"result":"playing","winner":-1,"events":[],"losses":[0,0,0,0],"combat_losses":[0,0,0,0]})
	for king in state.leaders: king["alive"] = true
	command_log.clear(); pending.clear(); issued_sequence = 0
	replay_origin = snapshot(false)
	return true

func _integers(value):
	if value is float and value == floor(value): return int(value)
	if value is Array:
		var out: Array = []
		for v in value: out.append(_integers(v))
		return out
	if value is Dictionary:
		var out: Dictionary = {}
		for k in value: out[k] = _integers(value[k])
		return out
	return value

func _canonical(value) -> String:
	if value is Dictionary:
		var keys: Array = value.keys(); keys.sort()
		var parts: Array = []
		for key in keys: parts.append(JSON.stringify(str(key)) + ":" + _canonical(value[key]))
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var parts: Array = []
		for item in value: parts.append(_canonical(item))
		return "[" + ",".join(parts) + "]"
	return JSON.stringify(value)

func state_hash() -> String: return _canonical({"state":state,"rules":rules}).sha256_text()
func snapshot_hash(saved: Dictionary) -> String:
	var clean: Dictionary = saved.duplicate(true); clean.erase("checksum")
	return _canonical(clean).sha256_text()
func snapshot(include_origin: bool = true) -> Dictionary:
	var saved: Dictionary = {"schema":1,"state":state.duplicate(true),"rules":rules.duplicate(true),"issued_sequence":issued_sequence,"command_log":command_log.duplicate(true),"pending":pending.duplicate(true)}
	if include_origin and not replay_origin.is_empty(): saved["replay_origin"] = replay_origin.duplicate(true)
	saved["checksum"] = snapshot_hash(saved)
	return saved

func _valid(saved: Dictionary) -> bool:
	if saved.get("schema") != 1 or not saved.get("state") is Dictionary or not saved.get("rules") is Dictionary: return false
	if not saved.get("issued_sequence") is int or not saved.get("command_log") is Array or not saved.get("pending") is Array: return false
	var s: Dictionary = saved.state
	for k in ["w","h","tick","day","next_id","limit_days","winner"]:
		if not s.get(k) is int: return false
	if s.w <= 0 or s.h <= 0 or s.w > 256 or s.h > 256: return false
	if s.get("result") not in ["playing","victory","defeat"] or not s.get("result") is String or s.tick<0 or s.day<0 or s.limit_days<1: return false
	if not s.get("cells") is Array or s.cells.size() != s.w*s.h: return false
	for k in ["factions","units","bases","leaders","events","losses","combat_losses"]:
		if not s.get(k) is Array: return false
	if s.factions.size()!=4 or s.leaders.size()!=4 or s.losses.size()!=4 or s.combat_losses.size()!=4: return false
	var ids: Dictionary = {}
	var faction_ids: Dictionary = {}
	for cell in s.cells:
		if not cell is Dictionary: return false
		for k in ["terrain","owner","bridge","fence"]:
			if not cell.get(k) is int: return false
		if not cell.get("bridge_built") is bool or cell.terrain<0 or cell.terrain>3 or cell.owner< -1 or cell.owner>3 or cell.bridge<0 or cell.fence<0: return false
	for f in s.factions:
		if not f is Dictionary: return false
		for k in ["id","funds","tax","home"]:
			if not f.get(k) is int: return false
		if faction_ids.has(f.id): return false
		faction_ids[f.id]=true
		if f.id<0 or f.id>3 or f.funds<0 or f.tax<0 or f.tax>saved.rules.get("tax_max",30) or f.home<0 or f.home>=s.cells.size() or not f.get("alive") is bool: return false
	for group in [s.units,s.bases,s.leaders]:
		for e in group:
			if not e is Dictionary: return false
			for k in ["id","team","pos"]:
				if not e.get(k) is int: return false
			if ids.has(e.id) or e.id<1 or e.team<0 or e.team>3 or e.pos<0 or e.pos>=s.cells.size(): return false
			ids[e.id]=true
			if e.id>=s.next_id: return false
			if e.has("pop"):
				if not e.pop is int or e.pop<1: return false
			else:
				if not e.get("power") is int or e.power<0 or not e.get("order") is String or not e.get("target") is int or e.target<0 or e.target>=s.cells.size() or not e.get("manual") is bool or e.order not in ACTIONS: return false
	for key in ["day_ticks","move_period","base_period","tax_period","decay_period","combat_period","work_period","ai_period","combat_divisor","decay_divisor","growth_tax_divisor"]:
		if not saved.rules.get(key) is int or saved.rules[key]<1: return false
	if saved.rules.get("id") != "PLAYABLE_EXPERIMENTAL_V1" or saved.rules.get("playable") != true or saved.rules.get("version") != 1: return false
	if not saved.rules.get("phase_order") is Array or saved.rules.phase_order.size()!=9: return false
	var phases: Dictionary={}
	for phase in saved.rules.phase_order:
		if phase not in ["commands","movement","contacts","work","population","economy","ai","leaders","outcome"] or phases.has(phase): return false
		phases[phase]=true
	if not saved.rules.get("path_neighbor_order") is Array or saved.rules.path_neighbor_order.size()!=4: return false
	var directions: Dictionary={}
	for direction in saved.rules.path_neighbor_order:
		if direction not in ["up","left","right","down"] or directions.has(direction):return false
		directions[direction]=true
	for key in ["tax_max","growth_base","upkeep_threshold","upkeep_divisor","build_cost","build_population","base_initial_population","bridge_new_cost","bridge_repair_cost","fence_cost","fence_durability","castle_king_factor","castle_unit_factor","max_units","ai_development_bases","king_recovery"]:
		if not saved.rules.get(key) is int or saved.rules[key]<1:return false
	for list in [saved.pending,saved.command_log]:
		for cmd in list:
			if not cmd is Dictionary or not cmd.get("tick") is int or not cmd.get("sequence") is int or cmd.tick<1 or cmd.sequence<1 or not cmd.get("action") is String or cmd.action not in ACTIONS or not cmd.get("actors") is Array or not cmd.get("target") is int or cmd.target< -1 or cmd.target>=s.cells.size() or not cmd.get("extra") is Dictionary:return false
			for actor in cmd.actors:
				if not actor is int or actor<1:return false
	for loss in s.losses+s.combat_losses:
		if not loss is int or loss<0:return false
	for king in s.leaders:
		if not king.get("alive") is bool or king.get("king") != true:return false
	return saved.get("checksum", "") == snapshot_hash(saved)

func restore(raw: Dictionary) -> bool:
	var saved: Dictionary = _integers(raw)
	if not _valid(saved): return false
	state = saved.state.duplicate(true); rules = saved.rules.duplicate(true)
	issued_sequence = saved.issued_sequence; command_log = saved.command_log.duplicate(true); pending = saved.pending.duplicate(true)
	replay_origin = saved.get("replay_origin",saved).duplicate(true)
	return true

func export_replay() -> Dictionary:
	return {"format":1,"ruleset_id":rules.id,"rng_state":"unused","initial_state":replay_origin.duplicate(true),"initial_state_hash":_canonical({"state":replay_origin.state,"rules":replay_origin.rules}).sha256_text(),"commands":command_log.duplicate(true),"final_tick":state.tick,"final_hash":state_hash(),"checkpoints":[{"tick":state.tick,"hash":state_hash()}]}
func replay() -> Dictionary: return export_replay()
func load_replay(record: Dictionary) -> bool:
	if record.get("format") != 1 or record.get("rng_state") != "unused" or not record.get("initial_state") is Dictionary or not record.get("commands") is Array: return false
	var temp = get_script().new()
	if not temp.restore(record.initial_state): return false
	if temp.state_hash()!=record.get("initial_state_hash") or temp.rules.id!=record.get("ruleset_id"): return false
	var final_tick = record.get("final_tick")
	if not (final_tick is int or final_tick is float) or float(final_tick)!=floor(float(final_tick)) or final_tick<temp.state.tick or final_tick>100000: return false
	temp.pending = _integers(record.commands); temp.command_log = _integers(record.commands)
	for command in temp.command_log:
		if not command is Dictionary:return false
		temp.issued_sequence=maxi(temp.issued_sequence,int(command.get("sequence",0)))
	if not temp._valid(temp.snapshot()):return false
	while temp.state.tick < int(final_tick) and temp.state.result=="playing": temp.step()
	if temp.state_hash()!=record.get("final_hash"): return false
	return restore(temp.snapshot())

func get_unit(id: int) -> Dictionary:
	for group in [state.units,state.leaders]:
		for e in group:
			if e.id==id: return e
	return {}
func get_base(pos: int) -> Dictionary:
	for b in state.bases:
		if b.pos==pos:return b
	return {}
func neighbors(pos: int) -> Array: return Path.neighbors(pos,state.w,state.h,rules.path_neighbor_order)
func around(pos: int) -> Array:
	var out: Array=[]
	var x: int=pos%state.w; var y: int=pos/state.w
	for dy in [-1,0,1]:
		for dx in [-1,0,1]:
			if (dx!=0 or dy!=0) and x+dx>=0 and x+dx<state.w and y+dy>=0 and y+dy<state.h:out.append((y+dy)*state.w+x+dx)
	return out
func _passable(pos: int) -> bool:
	var c: Dictionary=state.cells[pos]
	return c.fence==0 and (c.terrain!=2 or c.bridge>0) and c.terrain!=3
func path_to(start: int,target: int) -> Array: return Path.path(start,target,state.w,state.h,_passable,rules.path_neighbor_order)
func path_preview(id: int,target: int) -> Array:
	var u: Dictionary=get_unit(id)
	return [] if u.is_empty() or target<0 or target>=state.cells.size() else path_to(u.pos,target)
func population(team: int) -> int:
	var pop := 0
	for b in state.bases:
		if b.team==team:pop+=b.pop
	for u in state.units:
		if u.team==team:pop+=u.power
	return pop
func territory_count(base: Dictionary) -> int:
	var count:=0
	for pos in around(base.pos):
		if state.cells[pos].owner==base.team:count+=1
	return count
func population_limit(base: Dictionary) -> int: return (territory_count(base)+1)*16
func _tax_passable(pos: int, team: int) -> bool:
	var c: Dictionary=state.cells[pos]
	var b: Dictionary=get_base(pos)
	return _passable(pos) and (c.owner==-1 or c.owner==team) and (b.is_empty() or b.team==team)
func can_tax(base: Dictionary) -> bool:
	var f: Dictionary=state.factions[base.team];var king: Dictionary=state.leaders[base.team]
	if not f.alive or not king.alive or king.pos!=f.home or f.tax<1:return false
	return base.pos==f.home or not Path.path(f.home,base.pos,state.w,state.h,func(p):return _tax_passable(p,base.team),rules.path_neighbor_order).is_empty()
func issue(action: String, actor_ids: Array, target: int = -1, extra: Dictionary = {}) -> Dictionary:
	if action=="build_village":action="build_base"
	if action=="destroy_village":action="destroy_base"
	if state.result!="playing":return {"accepted":false,"reason":"Game finished"}
	if action not in ACTIONS:return {"accepted":false,"reason":"Unknown order"}
	if target < -1 or target>=state.cells.size():return {"accepted":false,"reason":"Outside map"}
	if action not in ["tax","initial_order"]:
		if actor_ids.is_empty():return {"accepted":false,"reason":"Select troops"}
		for id in actor_ids:
			var u: Dictionary=get_unit(int(id))
			if u.is_empty() or u.team!=0 or (u.get("king",false) and action not in ["move","wait"]):return {"accepted":false,"reason":"Invalid actor / leader may only move"}
		if action not in ["wait","auto"] and target<0:return {"accepted":false,"reason":"Choose destination"}
	issued_sequence+=1
	var cmd: Dictionary={"tick":state.tick+1,"sequence":issued_sequence,"action":action,"actors":actor_ids.duplicate(),"actor_ids":actor_ids.duplicate(),"target":target,"extra":extra.duplicate(true),"accepted":true,"reason":"Order ready"}
	return cmd
func step(commands: Array = []) -> void:
	if state.result!="playing":return
	for raw in commands:
		if not raw is Dictionary or not raw.get("accepted",true):continue
		var c: Dictionary=_integers(raw)
		if not c.has("actors") and c.has("actor_ids"):c["actors"]=c.actor_ids
		if not c.get("actors") is Array or not c.get("action") is String or c.action not in ACTIONS or not c.get("tick") is int or not c.get("sequence") is int or not c.get("target") is int or not c.get("extra") is Dictionary:continue
		if c.target< -1 or c.target>=state.cells.size() or c.tick<=state.tick:continue
		var duplicate:=false
		for prior in command_log:
			if prior.sequence==c.sequence:duplicate=true;break
		if duplicate:continue
		pending.append(c.duplicate(true));command_log.append(c.duplicate(true));issued_sequence=maxi(issued_sequence,c.sequence)
	state.tick+=1;state.day=state.tick/rules.day_ticks
	for phase in rules.phase_order:
		match phase:
			"commands":_commands()
			"movement":
				if state.tick%rules.move_period==0:_movement()
			"contacts":
				if state.tick%rules.combat_period==0:_contacts()
			"work":
				if state.tick%rules.work_period==0:_work()
			"population":
				if state.tick%rules.base_period==0:_population()
			"economy":_economy()
			"ai":
				if state.tick%rules.ai_period==0:_ai()
			"leaders":_leaders()
			"outcome":_outcome()
func _commands() -> void:
	pending.sort_custom(func(a,b):return a.sequence<b.sequence)
	var keep: Array=[]
	for c in pending:
		if c.tick>state.tick:keep.append(c);continue
		if c.action=="tax":state.factions[0].tax=clampi(int(c.extra.get("value",c.target)),0,rules.tax_max);continue
		if c.action=="initial_order":
			var order: String=c.extra.get("order","auto")
			if order in ["auto","wait","defend"]:state.factions[0].initial_order=order
			continue
		for id in c.actors:
			var u: Dictionary=get_unit(int(id))
			if not u.is_empty() and u.team==0:
				u.order=c.action;u.target=u.pos if c.target<0 else c.target;u.manual=c.action!="auto"
	pending=keep
func _movement() -> void:
	for group in [state.units,state.leaders]:
		for u in group.duplicate():
			if u.power<=0 or u.order in ["wait","auto"]:continue
			if u.pos==u.target:continue
			var goal: int=u.target
			if not _passable(goal):
				var candidates: Array=neighbors(goal);var best: Array=[]
				for p in candidates:
					if not _passable(p):continue
					var path: Array=path_to(u.pos,p)
					if u.pos==p:best=[];goal=p;break
					if not path.is_empty() and (best.is_empty() or path.size()<best.size()):best=path;goal=p
			var route: Array=path_to(u.pos,goal)
			if route.is_empty():continue
			var next: int=route[0];var occupied:=false
			for enemy in _actors():
				if enemy.team!=u.team and enemy.pos==next and enemy.power>0:occupied=true;break
			if not occupied:
				u.pos=next
				var b: Dictionary=get_base(next)
				if not b.is_empty() and b.team!=u.team:
					state.bases.erase(b);_event("Enemy village destroyed")
				if state.cells[next].terrain==0:state.cells[next].owner=u.team
func _actors() -> Array:
	var out: Array=state.units.duplicate()
	for k in state.leaders:
		if k.alive:out.append(k)
	out.sort_custom(func(a,b):return a.id<b.id)
	return out
func _merge_priority(u: Dictionary) -> Array:
	var reinforcement:=0
	for other in state.units:
		if other.team==u.team and other.order=="reinforce" and other.target==u.pos:reinforcement=1;break
	return [1 if u.get("king",false) else 0,1 if u.manual else 0,reinforcement,u.power,-u.id]
func _absorber(a: Dictionary,b: Dictionary) -> Dictionary:
	# Explicit reinforcement recipient retains its order, except a king always absorbs.
	if a.get("king",false):return a
	if b.get("king",false):return b
	if a.order=="reinforce" and a.target==b.pos:return b
	if b.order=="reinforce" and b.target==a.pos:return a
	var pa: Array=_merge_priority(a);var pb: Array=_merge_priority(b)
	for i in range(pa.size()):
		if pa[i]>pb[i]:return a
		if pa[i]<pb[i]:return b
	return a
func _contacts() -> void:
	var actors: Array=_actors()
	for i in range(actors.size()):
		var a: Dictionary=actors[i]
		if a.power<=0:continue
		for j in range(i+1,actors.size()):
			var b: Dictionary=actors[j]
			if b.power<=0:continue
			if a.team==b.team:
				if a.pos==b.pos:
					var winner: Dictionary=_absorber(a,b);var donor: Dictionary=b if winner.id==a.id else a
					winner.power+=donor.power;donor.power=0
				continue
			if a.pos!=b.pos and b.pos not in neighbors(a.pos):continue
			var fa: int=_castle_factor(a);var fb: int=_castle_factor(b)
			var loss: Array=Combat.resolve(a.power,b.power,fa,fb,rules.combat_divisor)
			a.power-=loss[0];b.power-=loss[1]
			state.losses[a.team]+=loss[0];state.losses[b.team]+=loss[1]
			state.combat_losses[a.team]+=loss[0];state.combat_losses[b.team]+=loss[1]
			if a.get("king",false) and a.power<=0:_eliminate(a.team,b.team if b.get("king",false) and b.power>0 else -1)
			if b.get("king",false) and b.power<=0:_eliminate(b.team,a.team if a.get("king",false) and a.power>0 else -1)
	_cleanup()
func _castle_factor(u: Dictionary) -> int:
	return (rules.castle_king_factor if u.get("king",false) else rules.castle_unit_factor) if u.pos==state.factions[u.team].home else 1
func _cleanup() -> void:
	for u in state.units.duplicate():
		if u.power<=0:state.units.erase(u)
func _event(message: String) -> void:
	state.events.append({"tick":state.tick,"message":message})
	if state.events.size()>30:state.events.pop_front()
func _can_build(pos: int,team: int) -> bool:
	if pos<0 or pos>=state.cells.size() or state.cells[pos].terrain!=0 or state.cells[pos].fence>0:return false
	for f in state.factions:
		if f.home==pos:return false
	for p in around(pos):
		var b: Dictionary=get_base(p)
		if not b.is_empty() and b.team==team:return false
	var existing: Dictionary=get_base(pos)
	return existing.is_empty() or existing.team!=team
func _work() -> void:
	for u in state.units.duplicate():
		var pos: int=u.target
		if pos<0 or pos>=state.cells.size():continue
		if u.pos!=pos and u.pos not in neighbors(pos):continue
		var c: Dictionary=state.cells[pos];var f: Dictionary=state.factions[u.team];var done:=false
		match u.order:
			"build_base","build_village":
				if u.pos==pos and _can_build(pos,u.team) and f.funds>=rules.build_cost and u.power>rules.build_population:
					var old: Dictionary=get_base(pos)
					if not old.is_empty():state.bases.erase(old)
					f.funds-=rules.build_cost;u.power-=rules.build_population
					state.bases.append({"id":state.next_id,"team":u.team,"pos":pos,"pop":rules.base_initial_population});state.next_id+=1
					c.owner=u.team
					for p in around(pos):
						if state.cells[p].terrain==0 and state.cells[p].fence==0:state.cells[p].owner=u.team
					done=true;_event("Village founded")
			"build_bridge":
				if c.terrain==2:
					var cost: int=rules.bridge_repair_cost if c.bridge_built else rules.bridge_new_cost
					if f.funds>=cost:f.funds-=cost;c.bridge+=1;c.bridge_built=true;done=true
			"build_fence":
				if c.terrain==0 and get_base(pos).is_empty() and f.funds>=rules.fence_cost:
					var home:=false
					for nation in state.factions:
						if nation.home==pos:home=true
					if not home:f.funds-=rules.fence_cost;c.fence+=rules.fence_durability;done=true
			"destroy_bridge":
				if c.bridge>0:c.bridge=maxi(0,c.bridge-4);done=c.bridge==0
			"destroy_fence":
				if c.fence>0:c.fence=maxi(0,c.fence-4);done=c.fence==0
			"reclaim":
				if c.terrain==1:c.terrain=0;c.owner=u.team;done=true
			"seal_cave":
				if c.terrain==3:c.terrain=0;c.owner=u.team;done=true
			"destroy_base","destroy_village":
				var b: Dictionary=get_base(pos)
				if not b.is_empty():state.bases.erase(b);done=true
			"reinforce","move":done=u.pos==pos
		if done:u.order="wait" if u.manual else "auto"
func _population() -> void:
	for b in state.bases.duplicate():
		var cap: int=population_limit(b)
		if b.pop<=cap:
			b.pop+=maxi(1,(rules.growth_base+territory_count(b))*(rules.growth_tax_divisor-state.factions[b.team].tax)/rules.growth_tax_divisor)
		else:
			var expansion: int=-1
			for p in around(b.pos):
				if state.cells[p].terrain==0 and state.cells[p].owner==-1 and state.cells[p].fence==0:expansion=p;break
			if expansion>=0:state.cells[expansion].owner=b.team
			elif state.units.size()<rules.max_units:
				state.units.append({"id":state.next_id,"team":b.team,"pos":b.pos,"power":b.pop-1,"order":state.factions[b.team].initial_order,"target":b.pos,"manual":false,"king":false});state.next_id+=1;b.pop=1
func _economy() -> void:
	if state.tick%rules.tax_period==0:
		for b in state.bases:
			if can_tax(b):state.factions[b.team].funds+=maxi(1,b.pop*state.factions[b.team].tax/100)
	if state.tick%rules.decay_period!=0:return
	for u in state.units:
		var b: Dictionary=get_base(u.pos);var on_base: bool=not b.is_empty() and b.team==u.team
		var decay:=0
		if not on_base:decay=maxi(1,u.power/rules.decay_divisor)
		elif u.power>=rules.upkeep_threshold:
			var cost: int=u.power/rules.upkeep_divisor
			if state.factions[u.team].funds>=cost:state.factions[u.team].funds-=cost
			else:decay=maxi(1,u.power/rules.decay_divisor)
		u.power-=decay;state.losses[u.team]+=decay
	_cleanup()
func _nearest(start: int, positions: Array) -> int:
	var target: int=-1;var best:=2147483647
	for p in positions:
		var d: int=absi(start%state.w-int(p)%state.w)+absi(start/state.w-int(p)/state.w)
		if d<best:best=d;target=int(p)
	return target
func _ai() -> void:
	for u in state.units:
		if u.manual or u.order not in ["auto","wait"] or (u.order=="wait" and u.team==0):continue
		var rough: Array=[];var builds: Array=[];var enemies: Array=[];var own_count:=0
		for b in state.bases:
			if b.team==u.team:own_count+=1
		for p in range(state.cells.size()):
			var c: Dictionary=state.cells[p]
			if c.terrain==1 and (c.owner==u.team or c.owner==-1):rough.append(p)
			if own_count<rules.ai_development_bases and c.owner==u.team and _can_build(p,u.team):builds.append(p)
		for king in state.leaders:
			if king.team!=u.team and king.alive:enemies.append(king.pos)
		var target: int=_nearest(u.pos,rough)
		if target>=0 and not path_to(u.pos,target).is_empty():u.target=target;u.order="reclaim";continue
		target=_nearest(u.pos,builds)
		if target>=0 and state.factions[u.team].funds>=rules.build_cost and u.power>rules.build_population:u.target=target;u.order="build_base";continue
		# C strategic rally: CPU countries periodically feed troops to their leader.
		# Original king absorption is A; choosing this strategy is explicitly C.
		if u.team>0 and u.id%3==0 and state.leaders[u.team].alive:
			u.target=state.leaders[u.team].pos;u.order="reinforce";continue
		# Troops rally at the nearest enemy. Stronger neighboring enemies are avoided.
		target=_nearest(u.pos,enemies)
		var threat: Dictionary={}
		for enemy in _actors():
			if enemy.team!=u.team and enemy.pos in neighbors(u.pos) and enemy.power*_castle_factor(enemy)>u.power*2:threat=enemy;break
		if not threat.is_empty():
			u.target=state.factions[u.team].home;u.order="move"
		elif target>=0:u.target=target;u.order="move"
	for king in state.leaders:
		if king.team==0 or not king.alive:continue
		var targets: Array=[]
		for enemy in state.leaders:
			if enemy.team!=king.team and enemy.alive and king.power>enemy.power*_castle_factor(enemy)*5/4:targets.append(enemy.pos)
		var goal: int=_nearest(king.pos,targets)
		king.target=state.factions[king.team].home if goal<0 else goal
		king.order="wait" if king.pos==king.target else "move"
func _leaders() -> void:
	for king in state.leaders:
		if not king.alive:continue
		var pop: int=population(king.team)
		if pop<=0:_eliminate(king.team,-1);continue
		if king.pos==state.factions[king.team].home and king.power<pop:king.power=mini(pop,king.power+rules.king_recovery)
		# A documents splitting one quarter; exact trigger/comparison is unmeasured C.
		if king.pos==state.factions[king.team].home and king.power>pop*rules.get("king_split_ratio",2) and state.units.size()<rules.max_units:
			var split: int=king.power/4
			if split>0:
				king.power-=split
				state.units.append({"id":state.next_id,"team":king.team,"pos":neighbors(king.pos)[0],"power":split,"order":"auto","target":neighbors(king.pos)[0],"manual":false,"king":false})
				state.next_id+=1
func _eliminate(team: int,captor: int) -> void:
	if not state.factions[team].alive:return
	state.factions[team].alive=false;state.leaders[team].alive=false;state.leaders[team].power=0
	if captor>=0:
		state.factions[captor].funds+=state.factions[team].funds
		for b in state.bases:
			if b.team==team:b.team=captor
		for u in state.units:
			if u.team==team:u.team=captor;u.order="wait";u.target=u.pos;u.manual=false
		for c in state.cells:
			if c.owner==team:c.owner=captor
	else:
		for b in state.bases.duplicate():
			if b.team==team:state.bases.erase(b)
		for u in state.units.duplicate():
			if u.team==team:state.units.erase(u)
		for c in state.cells:
			if c.owner==team:c.owner=-1
	state.factions[team].funds=0;_event("Nation defeated")
func _outcome() -> void:
	var alive: Array=[]
	for f in state.factions:
		if f.alive:alive.append(f.id)
	if not state.factions[0].alive:state.result="defeat";state.winner=alive[0] if alive.size()==1 else -1
	elif alive.size()==1:state.result="victory";state.winner=0
	elif state.day>=state.limit_days:state.result="defeat";state.winner=-1
func score(team: int=0) -> Dictionary:
	var total:=0;var area:=0;var enemy_loss:=0
	for c in state.cells:
		if c.terrain in [0,1]:
			total+=1
			if c.owner==team:area+=1
	for i in range(4):
		if i!=team:enemy_loss+=state.combat_losses[i]
	var occupation: int=area*100/maxi(1,total)
	var efficiency: int=enemy_loss*100/maxi(1,state.losses[team])
	var remaining: int=maxi(0,state.limit_days-state.day)
	var penalty: int=remaining*(total-area)/maxi(1,total)
	var bonus: int=mini(500,maxi(0,efficiency-100)) if remaining>0 else 0
	return {"occupation":occupation,"own_loss":state.losses[team],"enemy_loss":enemy_loss,"efficiency":efficiency,"remaining":remaining,"penalty":penalty,"bonus":bonus,"carry":remaining+bonus-penalty,"rounding":"C floor; zero-loss denominator=1 unmeasured"}
