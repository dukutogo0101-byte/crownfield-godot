extends RefCounted
## Dedicated repeat orders. Uses shared movement, bank work and actual prices.
const WORK = {
	"auto_build_bridge": "build_bridge", "auto_destroy_base": "destroy_base",
	"auto_destroy_bridge": "destroy_bridge", "auto_build_fence": "build_fence",
	"auto_destroy_fence": "destroy_fence", "auto_reclaim": "reclaim", "auto_seal_cave": "seal_cave"
}
const WORK_MODES = [ "auto_build_bridge", "auto_destroy_base", "auto_destroy_bridge", "auto_build_fence", "auto_destroy_fence", "auto_reclaim", "auto_seal_cave"]
const MODES = ["auto", "develop", "auto_build_bridge", "auto_destroy_base", "auto_destroy_bridge", "auto_build_fence", "auto_destroy_fence", "auto_reclaim", "auto_seal_cave"]
const INITIAL = ["auto", "develop", "wait", "auto_build_bridge", "auto_destroy_base", "auto_destroy_bridge", "auto_build_fence", "auto_destroy_fence", "auto_reclaim", "auto_seal_cave"]

static func affordable(sim, u: Dictionary, action: String, target: int) -> bool:
	var cost: int = 0
	if action == "build_bridge": cost = sim.rules.bridge_repair_cost if sim.state.cells[target].bridge_built else sim.rules.bridge_new_cost
	elif action == "build_fence": cost = sim.rules.fence_cost
	return sim.state.factions[u.team].funds >= cost

static func useful_bridge(sim, pos: int) -> bool:
	if sim.state.cells[pos].bridge_built: return true
	var banks: Array = sim.neighbors(pos)
	for a in banks:
		if not sim._land(a): continue
		for b in banks:
			if a != b and sim._land(b) and ((a % sim.state.w == b % sim.state.w and absi(a - b) == 2 * sim.state.w) or (a / sim.state.w == b / sim.state.w and absi(a - b) == 2)): return true
	return false

static func target_valid(sim, u: Dictionary, action: String, pos: int, bases: Dictionary = {}) -> bool:
	if pos < 0 or pos >= sim.state.cells.size(): return false
	var cell: Dictionary = sim.state.cells[pos]
	match action:
		"build_bridge": return cell.terrain == 2 and cell.bridge < int(sim.rules.get("ai_bridge_durability", 4)) and useful_bridge(sim, pos)
		"destroy_base":
			var base: Dictionary = bases.get(pos, {}) if not bases.is_empty() else sim.get_base(pos)
			if base.is_empty() or base.team == u.team: return false
			for nation in sim.state.factions:
				if nation.home == pos: return false
			return true
		"destroy_bridge":
			if cell.bridge <= 0: return false
			for bank in sim.neighbors(pos):
				if sim.state.cells[bank].owner >= 0 and sim.state.cells[bank].owner != u.team: return true
		"build_fence":
			if cell.terrain != 0 or cell.owner != u.team or cell.fence > 0: return false
			if bases.has(pos) if not bases.is_empty() else not sim.get_base(pos).is_empty(): return false
			for nation in sim.state.factions:
				if nation.home == pos: return false
			for neighbor in sim.neighbors(pos):
				if sim.state.cells[neighbor].owner >= 0 and sim.state.cells[neighbor].owner != u.team: return true
		"destroy_fence": return cell.fence > 0 and cell.owner != u.team
		"reclaim": return cell.terrain == 1 and cell.fence == 0 and cell.owner in [-1, u.team]
		"seal_cave": return cell.terrain == 3
	return false

static func wait_here(u: Dictionary) -> void:
	u.order = "wait"; u.target = u.pos; u["ai_job"] = "work"

static func blockers(sim, u: Dictionary) -> Dictionary:
	var blocked: Dictionary = sim._builder_blockers(u)
	for base in sim.state.bases:
		if base.team != u.team and u.auto_mode != "auto_destroy_base": blocked[base.pos] = true
	for nation in sim.state.factions:
		if nation.id != u.team: blocked[nation.home] = true
	return blocked

static func plan(sim, only: Array = []) -> void:
	var workers: Array = []
	var reserved: Dictionary = {}
	for u in sim.state.units:
		if u.manual or not WORK.has(u.get("auto_mode", "")) or u.power <= 0: continue
		if only.is_empty() or only.has(u): workers.append(u)
		elif u.order != "wait": reserved[str(u.team) + ":" + u.order + ":" + str(u.target)] = u.id
	if workers.is_empty(): return
	workers.sort_custom(func(a, b): return a.id < b.id)
	var threats_by_team: Dictionary = {}
	var targets_by_job: Dictionary = {}
	var bases: Dictionary = {}
	for base in sim.state.bases: bases[base.pos] = base
	for u in workers:
		if not sim.state.factions[u.team].alive: continue
		var action: String = WORK[u.auto_mode]
		if not threats_by_team.has(u.team): threats_by_team[u.team] = sim._threat_map(u.team)
		var threats: Dictionary = threats_by_team[u.team]
		var power: int = u.power if action == "destroy_base" else 0
		var distances: Dictionary = sim._reachable(u.pos, threats, power, blockers(sim, u))
		var job: String = str(u.team) + ":" + action
		if not targets_by_job.has(job):
			var targets: Array = []
			var positions: Array = []
			if action == "destroy_base":
				for base in sim.state.bases: positions.append(base.pos)
			else: positions.assign(range(sim.state.cells.size()))
			for pos in positions:
				if target_valid(sim, u, action, pos, bases): targets.append(pos)
			targets_by_job[job] = targets
		var candidates: Array = targets_by_job[job].duplicate()
		if u.order == action and candidates.has(u.target):
			candidates.erase(u.target); candidates.push_front(u.target)
		var target: int = -1; var best: int = 2147483647
		for pos in candidates:
			var key: String = str(u.team) + ":" + action + ":" + str(pos)
			if reserved.has(key) or not affordable(sim, u, action, pos) or not sim._safe_step(pos, threats, power): continue
			var distance: int = int(distances.get(pos, 2147483647))
			if action in sim.BANK_WORK:
				distance = 2147483647
				for bank in sim.neighbors(pos):
					if sim._land(bank): distance = mini(distance, int(distances.get(bank, 2147483647)))
			if distance == 2147483647: continue
			if u.order == action and u.target == pos: target = pos; break
			if distance < best: best = distance; target = pos
		if target < 0: wait_here(u); continue
		u.order = action; u.target = target; u["ai_job"] = "work"
		reserved[str(u.team) + ":" + action + ":" + str(target)] = u.id
