extends RefCounted
## Plans orders only. Movement, combat, bank work, prices and population remain
## in the shared simulation. There is no resource grant or special movement.
const Path = preload("res://core/pathfinder.gd")
var sim
var actors: Array
var team: int
var threats: Dictionary
var sites: Dictionary
var units: Array
var used: Dictionary
var reservations: Array
var reachable_land: Dictionary
var engineer: Dictionary

func _init(simulation) -> void:
	sim = simulation

func think() -> void:
	actors = sim._actors()
	for faction in sim.state.factions:
		if faction.alive: _country(faction.id)

func _order(u: Dictionary, action: String, target: int, job: String) -> bool:
	if not sim.can_order(team, action, [u.id], target): return false
	u.order = action; u.target = u.pos if target < 0 else target
	u["ai_job"] = job
	u.manual = false
	return true

func _country(country: int) -> void:
	team = country; used = {}; reservations = []; engineer = {}
	threats = sim._threat_map(team)
	sites = sim._development_sites(team, threats)
	units = []
	for u in sim.state.units:
		if u.team == team and not u.manual and u.power > 0:
			if u.get("auto_mode", "") == "" and team > 0: u["auto_mode"] = "auto"
			if u.get("auto_mode", "") in ["auto", "develop"]: units.append(u)
		if u.order in ["build_base", "build_village"]: reservations.append({"id": u.id, "team": u.team, "pos": u.target})
	var count: int = 0
	for base in sim.state.bases:
		if base.team == team: count += 1
	_economic_policy(count)
	# Resume an engineering project before assigning ordinary economic roles.
	for u in units:
		if engineer.is_empty() and _resume_engineering(u): engineer = u; used[u.id] = true
	var builders: Dictionary = sim._builder_ids(team, threats, count)
	for u in units:
		if used.has(u.id): continue
		if int(threats.get(u.pos, 0)) > 0 and not sim._advantage(u.power, threats[u.pos]):
			_retreat(u); used[u.id] = true
			continue
		if u.get("auto_mode", "") == "develop" or builders.has(u.id):
			var distances: Dictionary = sim._reachable(u.pos, threats, 0, sim._builder_blockers(u))
			var continuing: bool = u.order in ["build_base", "build_village"] and sim._can_build(u.target, team) and sim.get_base(u.target).is_empty() and distances.has(u.target) and int(threats.get(u.target, 0)) == 0 and sim.state.factions[team].funds >= sim.rules.build_cost and u.power > sim.rules.build_population
			continuing = continuing or (u.order == "reclaim" and sim.state.cells[u.target].terrain == 1 and distances.has(u.target) and int(threats.get(u.target, 0)) == 0)
			if continuing or sim._assign_development(u, sites, distances, reservations): used[u.id] = true
			elif u.get("auto_mode", "") == "develop":
				sim._rally(u, sim._reachable(u.pos, threats, 0), threats); used[u.id] = true
	var soldiers: Array = []
	for u in units:
		if not used.has(u.id): soldiers.append(u)
	soldiers.sort_custom(func(a, b): return a.power > b.power if a.power != b.power else a.id < b.id)
	var invader: Dictionary = _invasion()
	var phase: String = "develop"
	if not soldiers.is_empty() and not invader.is_empty() and engineer.is_empty():
		reachable_land = sim._reachable(soldiers[0].pos)
		var defensive: Dictionary = _defensive_work(invader)
		if not defensive.is_empty(): _assign_engineer(soldiers, defensive, soldiers[0])
	if not invader.is_empty():
		phase = "defend"
		_defend(soldiers, invader)
	var available: Array = []
	for u in soldiers:
		if not used.has(u.id): available.append(u)
	if not available.is_empty():
		var primary: Dictionary = available[0]
		reachable_land = sim._reachable(primary.pos)
		var probe: Dictionary = primary.duplicate(true)
		sim._rally(probe, sim._reachable(primary.pos, threats, 0), threats)
		var rally: int = probe.target
		var task: Dictionary = _defensive_work(invader)
		if task.is_empty(): task = _supply_work(primary)
		if not task.is_empty() and engineer.is_empty(): _assign_engineer(available, task, primary)
		var objective: Dictionary = _objective(primary)
		if not objective.is_empty():
			var route: Array = Path.route(objective.tree, objective.pos)
			var barrier: Dictionary = _first_barrier(route, "attack")
			if not barrier.is_empty():
				if engineer.is_empty(): _assign_engineer(available, barrier, primary)
				if not engineer.is_empty() and not used.has(primary.id):
					var bank: int = _safe_bank(engineer, engineer.ai_task.target)
					if bank >= 0: _order(primary, "move", bank, "escort"); used[primary.id] = true
				phase = "engineer" if not engineer.is_empty() else "assemble"
			elif not used.has(primary.id):
				_order(primary, "destroy_base" if objective.kind == "village" else "move", objective.pos, "attack")
				used[primary.id] = true; phase = "attack"
			_write_plan(phase, objective.pos, objective.kind, rally)
		else:
			_write_plan(phase if phase == "defend" else "assemble", -1, "", rally)
		# Feed a common safe supply point. Small sorties do not chase a commander
		# into a hostile zone before they have physically merged.
		for u in available:
			if used.has(u.id): continue
			var goal: int = rally
			if not sim._reachable(u.pos, threats, 0).has(goal):
				sim._rally(u, sim._reachable(u.pos, threats, 0), threats)
			else: _order(u, "wait" if u.pos == goal else "reinforce", goal, "rally")
	else: _write_plan(phase, invader.get("pos", -1), "invasion" if not invader.is_empty() else "", -1)
	_king_policy(invader)

func _economic_policy(base_count: int) -> void:
	if team == 0: return
	var faction: Dictionary = sim.state.factions[team]
	if sim.state.tick - int(faction.get("ai_tax_tick", -100000)) < int(sim.rules.get("ai_tax_cooldown", 120)): return
	var reserve: int = maxi(sim.rules.build_cost * 3, base_count * 12)
	var target: int = 10
	if faction.funds < sim.rules.build_cost: target = 25
	elif faction.funds < reserve: target = 20
	elif faction.funds > reserve * 2: target = 5
	faction.tax = clampi(target, 0, sim.rules.tax_max)
	faction["ai_tax_tick"] = sim.state.tick
	faction.initial_order = "auto"

func _write_plan(phase: String, target: int, kind: String, rally: int) -> void:
	var faction: Dictionary = sim.state.factions[team]
	var old = faction.get("ai_plan", {})
	var since: int = sim.state.tick
	if old is Dictionary and old.get("phase") == phase and old.get("target") == target: since = int(old.get("since", since))
	faction["ai_plan"] = {"phase": phase, "target": target, "kind": kind, "rally": rally, "since": since}

func _invasion() -> Dictionary:
	var best: Dictionary = {}
	var score: int = -1
	for enemy in actors:
		if enemy.team == team or enemy.power <= 0: continue
		if enemy.get("king", false) and enemy.pos == sim.state.factions[enemy.team].home: continue
		var distance: int = sim._distance(enemy.pos, sim.state.factions[team].home)
		var value: int = 100 - distance * 8 if distance <= 8 else -1000
		for base in sim.state.bases:
			if base.team == team and sim._distance(enemy.pos, base.pos) <= 4: value = maxi(value, 40 + mini(base.pop, 144) / 8 - sim._distance(enemy.pos, base.pos) * 4)
		if value > score: score = value; best = enemy
	return best

func _defend(soldiers: Array, invader: Dictionary) -> void:
	var candidates: Array = soldiers.duplicate()
	candidates.sort_custom(func(a, b): return sim._distance(a.pos, invader.pos) < sim._distance(b.pos, invader.pos) if sim._distance(a.pos, invader.pos) != sim._distance(b.pos, invader.pos) else a.id < b.id)
	for u in candidates:
		if used.has(u.id): continue
		if sim._advantage(u.power, int(threats.get(invader.pos, invader.power))) and sim._reachable(u.pos, threats, u.power).has(invader.pos):
			_order(u, "move", invader.pos, "defend"); used[u.id] = true
			return
	# A weak field army combines with the castle garrison when the king is at risk.
	var home: int = sim.state.factions[team].home
	if sim._distance(home, invader.pos) <= 6:
		for u in candidates:
			if used.has(u.id): continue
			if sim._reachable(u.pos, threats, 0).has(home): _order(u, "defend", home, "defend"); used[u.id] = true

static func retreat_tree(simulation, u: Dictionary, danger: Dictionary) -> Dictionary:
	var blocked: Dictionary = {}
	var contact: Dictionary = {}
	for enemy in simulation._actors():
		if enemy.team == u.team or enemy.power <= 0: continue
		blocked[enemy.pos] = true
		for pos in simulation.neighbors(enemy.pos): contact[pos] = int(contact.get(pos, 0)) + enemy.power * simulation._castle_factor(enemy)
	var initial: int = int(contact.get(u.pos, 0))
	return Path.cost_tree(u.pos, simulation.state.w, simulation.state.h, func(p):
		if not simulation._passable(p) or blocked.has(p) or int(contact.get(p, 0)) > initial: return -1
		return 10 + int(danger.get(p, 0)) * 12 / maxi(1, u.power) + int(contact.get(p, 0)) * 40 / maxi(1, u.power), simulation.rules.path_neighbor_order)

func _retreat(u: Dictionary) -> void:
	var tree: Dictionary = retreat_tree(sim, u, threats)
	var goal: int = -1
	var score: int = 2147483647
	for base in sim.state.bases:
		if base.team != team or not tree.distance.has(base.pos) or int(threats.get(base.pos, 0)) > 0: continue
		if int(tree.distance[base.pos]) < score: score = tree.distance[base.pos]; goal = base.pos
	if goal < 0:
		for pos in tree.distance:
			var value: int = int(threats.get(pos, 0)) * 100 + int(tree.distance[pos]) + sim._distance(pos, sim.state.factions[team].home)
			if value < score: score = value; goal = pos
	if goal < 0: goal = u.pos
	_order(u, "wait" if goal == u.pos else "move", goal, "retreat")

func _engineering_action(pos: int) -> String:
	var cell: Dictionary = sim.state.cells[pos]
	if cell.fence > 0: return "destroy_fence"
	if cell.terrain == 3: return "seal_cave"
	if cell.terrain == 2 and cell.bridge == 0: return "build_bridge"
	return ""

func _work_price(action: String, pos: int) -> int:
	var cell: Dictionary = sim.state.cells[pos]
	if action == "build_bridge":
		var goal: int = int(sim.rules.get("ai_bridge_durability", 4))
		if cell.bridge > 0: return maxi(0, goal - cell.bridge) * sim.rules.bridge_repair_cost
		return (sim.rules.bridge_repair_cost if cell.bridge_built else sim.rules.bridge_new_cost) + maxi(0, goal - 1) * sim.rules.bridge_repair_cost
	if action == "build_fence": return sim.rules.fence_cost
	return 0

func _travel_cost(pos: int, power: int, engineering: bool, supply: bool = false) -> int:
	if supply and sim.state.cells[pos].owner not in [-1, team]: return -1
	if not sim._safe_step(pos, threats, power): return -1
	if sim._passable(pos): return 10
	if not engineering: return -1
	var action: String = _engineering_action(pos)
	if action == "": return -1
	var cut = sim.state.factions[team].get("ai_cut", {})
	if cut is Dictionary and cut.get("pos", -1) == pos and int(cut.get("until", 0)) > sim.state.tick: return -1
	var bank: bool = false
	for adjacent in sim.neighbors(pos):
		if sim._land(adjacent) and reachable_land.has(adjacent): bank = true; break
	if not bank: return -1
	var price: int = _work_price(action, pos)
	var reserve: int = 0 if supply or price == 0 else sim.rules.build_cost
	if price + reserve > sim.state.factions[team].funds: return -1
	var labor: int = 1
	if action == "destroy_fence": labor = ceili(sim.state.cells[pos].fence / 4.0)
	elif action == "build_bridge": labor = int(sim.rules.get("ai_bridge_durability", 4))
	return 10 + labor * sim.rules.work_period * 10 / sim.rules.move_period + price

func _objective(primary: Dictionary) -> Dictionary:
	var tree: Dictionary = Path.cost_tree(primary.pos, sim.state.w, sim.state.h, func(p): return _travel_cost(p, primary.power, true), sim.rules.path_neighbor_order)
	var choices: Array = []
	for base in sim.state.bases:
		if base.team != team: choices.append({"pos": base.pos, "value": 240 + base.pop / 2, "kind": "village"})
	for enemy in actors:
		if enemy.team == team: continue
		choices.append({"pos": enemy.pos, "value": 1200 if enemy.get("king", false) else 120 + mini(enemy.power, 2000) / 16, "kind": "king" if enemy.get("king", false) else "army"})
	var best: Dictionary = {}
	var best_score: int = -2147483647
	var old = sim.state.factions[team].get("ai_plan", {})
	for choice in choices:
		if not tree.distance.has(choice.pos) or not sim._advantage(primary.power, int(threats.get(choice.pos, 0))): continue
		var score: int = choice.value * 10 - int(tree.distance[choice.pos]) * 3
		if old is Dictionary and old.get("target", -1) == choice.pos: score += 200
		if score > best_score: best = choice; best_score = score
	if not best.is_empty(): best["tree"] = tree
	return best

func _first_barrier(route: Array, purpose: String) -> Dictionary:
	for pos in route:
		var action: String = _engineering_action(pos)
		if action != "": return {"action": action, "target": pos, "durability": int(sim.rules.get("ai_bridge_durability", 4)), "purpose": purpose}
	return {}

func _supply_work(primary: Dictionary) -> Dictionary:
	if sim.state.factions[team].tax == 0: return {}
	var network: Dictionary = sim.tax_network(team)
	if network.is_empty(): return {}
	var disconnected: Array = []
	for base in sim.state.bases:
		if base.team == team and not network.has(base.pos): disconnected.append(base.pos)
	if disconnected.is_empty():
		# Maintain an existing crossing that is already carrying troops or taxes.
		for pos in network:
			var cell: Dictionary = sim.state.cells[pos]
			if cell.terrain == 2 and cell.bridge > 0 and cell.bridge < int(sim.rules.get("ai_bridge_durability", 4)):
				return {"action": "build_bridge", "target": pos, "durability": int(sim.rules.get("ai_bridge_durability", 4)), "purpose": "supply"}
		return {}
	var home: int = sim.state.factions[team].home
	var tree: Dictionary = Path.cost_tree(home, sim.state.w, sim.state.h, func(p): return _travel_cost(p, primary.power, true, true), sim.rules.path_neighbor_order)
	var target: int = -1; var distance: int = 2147483647
	for pos in disconnected:
		if tree.distance.has(pos) and int(tree.distance[pos]) < distance: target = pos; distance = tree.distance[pos]
	return _first_barrier(Path.route(tree, target), "supply") if target >= 0 else {}

func _defensive_work(invader: Dictionary) -> Dictionary:
	if invader.is_empty() or invader.power <= 0: return {}
	var friendly: int = sim.state.leaders[team].power * sim._castle_factor(sim.state.leaders[team])
	for u in units:
		if sim._distance(u.pos, invader.pos) <= 5: friendly += u.power
	if friendly >= invader.power or sim._distance(invader.pos, sim.state.factions[team].home) > 10: return {}
	var home: int = sim.state.factions[team].home
	for pos in range(sim.state.cells.size()):
		if sim._distance(pos, invader.pos) > 4: continue
		var cell: Dictionary = sim.state.cells[pos]
		var action: String = ""
		if cell.terrain == 2 and cell.bridge > 0: action = "destroy_bridge"
		elif cell.terrain == 0 and cell.fence == 0 and sim.get_base(pos).is_empty() and pos != home:
			var exits: int = 0
			for adjacent in sim.neighbors(pos):
				if sim._passable(adjacent): exits += 1
			if exits <= 2: action = "build_fence"
		if action == "": continue
		var blocked: Dictionary = {pos: true}
		var safe: Dictionary = _component(home, blocked)
		if safe.has(invader.pos): continue
		var stranded: bool = false
		for base in sim.state.bases:
			if base.team == team and not safe.has(base.pos): stranded = true
		for ally in actors:
			if ally.team == team and not safe.has(ally.pos): stranded = true
		if not stranded: return {"action": action, "target": pos, "durability": 0, "purpose": "defend"}
	return {}

func _component(start: int, blocked: Dictionary) -> Dictionary:
	return sim._reachable(start, {}, -1, blocked)

func _safe_bank(u: Dictionary, target: int) -> int:
	var distances: Dictionary = sim._reachable(u.pos, threats, u.power)
	var goal: int = -1; var length: int = 2147483647
	for bank in sim.neighbors(target):
		if not sim._land(bank) or not distances.has(bank): continue
		if int(distances[bank]) < length: goal = bank; length = distances[bank]
	return goal

func _resume_engineering(u: Dictionary) -> bool:
	var task = u.get("ai_task", {})
	if not task is Dictionary or task.get("action", "") not in sim.BANK_WORK: u.erase("ai_task"); return false
	var target = task.get("target", -1)
	if not target is int or target < 0 or target >= sim.state.cells.size(): u.erase("ai_task"); return false
	if task_done(sim, task): u.erase("ai_task"); return false
	if int(threats.get(u.pos, 0)) > 0 and not sim._advantage(u.power, threats[u.pos]): u.erase("ai_task"); return false
	if _safe_bank(u, target) < 0 or _work_price(task.action, target) > sim.state.factions[team].funds: u.erase("ai_task"); return false
	return _order(u, task.action, target, "engineer")

func _assign_engineer(candidates: Array, task: Dictionary, primary: Dictionary) -> void:
	if not engineer.is_empty(): return
	var ranked: Array = candidates.duplicate()
	ranked.sort_custom(func(a, b):
		if (a.id == primary.id) != (b.id == primary.id): return a.id != primary.id
		return a.power < b.power if a.power != b.power else a.id < b.id)
	var price: int = _work_price(task.action, task.target)
	var reserve: int = sim.rules.build_cost if task.purpose == "attack" and price > 0 else 0
	if sim.state.factions[team].funds < price + reserve: return
	for u in ranked:
		if used.has(u.id) or _safe_bank(u, task.target) < 0: continue
		if not _order(u, task.action, task.target, "engineer"): continue
		u["ai_task"] = task.duplicate(true)
		engineer = u; used[u.id] = true
		sim._event(str(sim.state.factions[team].name) + ": " + {"build_bridge": "架橋・橋修理", "destroy_bridge": "橋を遮断", "build_fence": "防柵を建設", "destroy_fence": "柵を突破", "seal_cave": "洞窟を封鎖"}.get(task.action, task.action))
		return

static func task_done(simulation, task: Dictionary) -> bool:
	var cell: Dictionary = simulation.state.cells[task.target]
	match task.action:
		"build_bridge": return cell.terrain != 2 or cell.bridge >= int(task.get("durability", 4))
		"destroy_bridge": return cell.bridge == 0
		"build_fence": return cell.fence > 0 or cell.terrain != 0
		"destroy_fence": return cell.fence == 0
		"seal_cave": return cell.terrain != 3
	return true

static func work_completed(simulation, u: Dictionary, action: String) -> void:
	var task = u.get("ai_task", {})
	if u.get("ai_job", "") != "engineer" or not task is Dictionary or task.get("action", "") != action: return
	if task_done(simulation, task):
		if action in ["destroy_bridge", "build_fence"]: simulation.state.factions[u.team]["ai_cut"] = {"pos": task.target, "until": simulation.state.tick + 240}
		u.erase("ai_task"); u["ai_job"] = "rally"
	elif simulation.can_order(u.team, action, [u.id], task.target):
		u.order = action; u.target = task.target

func _king_policy(invader: Dictionary) -> void:
	if team == 0: return
	var king: Dictionary = sim.state.leaders[team]
	if not king.alive or king.manual: return
	var home: int = sim.state.factions[team].home
	if king.pos != home: _order(king, "move", home, "retreat"); return
	_order(king, "wait", home, "rally")
	if not invader.is_empty(): return
	for enemy in actors:
		if not enemy.get("king", false) or enemy.team == team or sim._distance(king.pos, enemy.pos) > 6: continue
		if sim._advantage(king.power, sim._enemy_strength(enemy.pos, team)) and sim._reachable(king.pos, threats, king.power).has(enemy.pos):
			_order(king, "move", enemy.pos, "attack"); return
