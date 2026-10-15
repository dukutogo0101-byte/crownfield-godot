extends SceneTree

const Core = preload("res://core/simulation.gd")
const Paths = preload("res://core/pathfinder.gd")
const Combat = preload("res://core/combat_resolver.gd")
var checks: int = 0
var failures: Array = []

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL ", label)

func equal(a: Variant, b: Variant, label: String) -> void:
	expect(a == b, label + " expected=" + str(b) + " got=" + str(a))

func fresh():
	var sim = Core.new()
	sim.new_game()
	return sim

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_path()
	test_combat()
	test_determinism()
	test_save()
	test_rules()
	test_commands()
	test_population()
	test_construction()
	test_tax_and_decay()
	test_merging()
	test_leaders_and_result()
	test_external_phase_order()
	test_development_ai()
	test_ai_stalemate()
	test_attack_judgment()
	test_bank_work()
	test_golden()
	print("TEST RESULT ", checks - failures.size(), "/", checks, " passed; ", failures.size(), " failed")
	var report := {"checks": checks, "passed": checks - failures.size(), "failed": failures, "engine": Engine.get_version_info().string, "scope": "Godot headless integer kernel; not original differential or Android device tests"}
	var f := FileAccess.open("res://tests/test_results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	quit(1 if not failures.is_empty() else 0)

func test_path() -> void:
	equal(Paths.neighbors(0, 3, 3), [1,3], "corner cardinal neighbors")
	equal(Paths.neighbors(4, 3, 3), [1,3,5,7], "explicit cardinal tie order")
	equal(Paths.neighbors(4, 3, 3, ["down","right","left","up"]), [7,5,3,1], "external neighbor order")
	equal(Paths.path(4, 4, 3, 3, func(_p): return true), [], "already at destination")
	equal(Paths.path(0, 8, 3, 3, func(_p): return true), [1,2,5,8], "deterministic equal-distance path")
	equal(Paths.path(0, 8, 3, 3, func(_p): return true, ["down","right","left","up"]), [3,6,7,8], "neighbor order changes only chosen route")
	equal(Paths.path(0, 8, 3, 3, func(p): return p not in [1,3]), [], "disconnected target")
	equal(Paths.path(0, 2, 3, 3, func(p): return p != 1), [3,4,5,2], "obstacle detour")

func test_combat() -> void:
	equal(Combat.resolve(80, 80, 1, 1, 8), [10,10], "C simultaneous attrition")
	equal(Combat.resolve(80, 80, 4, 1, 8), [2,40], "C castle multiplier")
	equal(Combat.resolve(1, 999, 1, 1, 8), [1,1], "C losses capped to available population")
	var a := Combat.resolve(80,160,1,1,8)
	var b := Combat.resolve(160,80,1,1,8)
	equal(a, [b[1],b[0]], "C resolver symmetric outside castle")

func test_determinism() -> void:
	var a = fresh()
	var b = fresh()
	equal(a.state_hash(), b.state_hash(), "same initial state hash")
	var commands: Array = []
	for tick in range(320):
		commands.clear()
		if tick == 8: commands.append(a.issue("wait", [4]))
		if tick == 30: commands.append(a.issue("auto", [4]))
		if tick == 80: commands.append(a.issue("move", [1], 164))
		a.step(commands)
		b.step(commands)
		if tick % 32 == 31: equal(a.state_hash(), b.state_hash(), "deterministic checkpoint " + str(tick+1))
	var parsed = JSON.parse_string(JSON.stringify(a.snapshot()))
	var c = fresh()
	expect(c.restore(parsed), "JSON snapshot roundtrip restore")
	equal(c.state_hash(), a.state_hash(), "JSON integer normalization produces identical hash")
	for _tick in range(20):
		a.step([])
		c.step([])
	equal(c.state_hash(), a.state_hash(), "save resume future state identical")
	var replay = a.export_replay()
	var d = fresh()
	expect(d.load_replay(replay), "replay origin accepted")
	equal(d.state_hash(), a.state_hash(), "exported command replay exact final hash")

func test_save() -> void:
	var sim = fresh()
	var original: String = sim.state_hash()
	var snap: Dictionary = sim.snapshot()
	var corrupt := snap.duplicate(true)
	corrupt.state.factions[0].funds += 1
	expect(not sim.restore(corrupt), "modified snapshot checksum rejected")
	equal(sim.state_hash(), original, "corrupt restore atomic")
	corrupt = snap.duplicate(true)
	corrupt.state.erase("units")
	expect(not sim.restore(corrupt), "missing field rejected")
	equal(sim.state_hash(), original, "missing field restore atomic")
	corrupt = snap.duplicate(true)
	corrupt.rules.id = "UNKNOWN_RULES"
	expect(not sim.restore(corrupt), "foreign rules rejected")
	equal(sim.state_hash(), original, "foreign rules restore atomic")
	corrupt = snap.duplicate(true)
	corrupt.state.units[0].erase("power")
	corrupt.checksum = sim.snapshot_hash(corrupt)
	expect(not sim.restore(corrupt), "valid checksum does not bypass missing entity power")
	equal(sim.state_hash(), original, "invalid entity restore atomic")
	corrupt = snap.duplicate(true)
	corrupt.state.factions[0].funds = 1.5
	corrupt.checksum = sim.snapshot_hash(corrupt)
	expect(not sim.restore(corrupt), "fractional money rejected by integer state validation")
	equal(sim.state_hash(), original, "fractional restore atomic")
	corrupt = snap.duplicate(true)
	corrupt.state.factions[1].id = 0
	corrupt.checksum = sim.snapshot_hash(corrupt)
	expect(not sim.restore(corrupt), "duplicate faction identities rejected")
	equal(sim.state_hash(), original, "duplicate faction restore atomic")
	expect(sim.restore(snap), "valid snapshot accepted")
	equal(sim.state_hash(), original, "valid restore identical")

func test_rules() -> void:
	var sim = fresh()
	equal(sim.rules.build_cost, 100, "A village cost")
	equal(sim.rules.bridge_new_cost, 30, "A new bridge point cost")
	equal(sim.rules.bridge_repair_cost, 2, "A bridge repair point cost")
	equal(sim.rules.fence_durability, 4, "A fence durability per G")
	equal(sim.rules.upkeep_threshold, 2048, "A upkeep threshold")
	equal(sim.rules.rng, "unused", "no rule RNG")
	equal(sim.rules.classification, "C", "playable numerical profile explicitly C")
	equal(sim.state.factions.size(), 4, "four starting factions")
	equal(sim.state.leaders.size(), 4, "four starting leaders")
	equal(sim.state.w * sim.state.h, sim.state.cells.size(), "external map dimensions")

func test_commands() -> void:
	var sim = fresh()
	var command: Dictionary = sim.issue("auto", [1])
	expect(not command.accepted, "A leader cannot auto")
	command = sim.issue("build_village", [1], 165)
	expect(not command.accepted, "A leader cannot build")
	command = sim.issue("move", [1], 164)
	expect(command.accepted, "A leader can move")
	var second: Dictionary = sim.issue("wait", [4])
	expect(second.accepted, "unit wait accepted")
	expect(second.sequence > command.sequence, "stable increasing input sequence")
	equal(second.tick, sim.state.tick+1, "command queued at next logical tick")
	command = sim.issue("move", [99999], 165)
	expect(not command.accepted, "unknown entity command rejected")
	command = sim.issue("move", [4], -12)
	expect(not command.accepted, "out-of-map target rejected")

func test_golden() -> void:
	if not FileAccess.file_exists("res://tests/golden/regression.json"):
		expect(false, "frozen golden must exist; test does not regenerate it")
		return
	var golden = Core.new()._integers(JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/regression.json")))
	equal(golden.classification, "C", "frozen golden experimental provenance")
	var sim = fresh()
	expect(sim.restore(golden.replay.initial_state), "frozen golden origin valid")
	for checkpoint in golden.checkpoints:
		while sim.state.tick < int(checkpoint.tick):
			var due: Array = []
			for command in golden.replay.commands:
				if int(command.tick) == sim.state.tick+1: due.append(command)
			sim.step(due)
		equal(sim.state_hash(), checkpoint.hash, "frozen golden checkpoint " + str(checkpoint.tick))

func sandbox():
	var sim = fresh()
	sim.state.w=9;sim.state.h=9;sim.state.cells=[]
	for _i in range(81):sim.state.cells.append({"terrain":0,"owner":-1,"bridge":0,"fence":0,"bridge_built":false})
	sim.state.bases=[];sim.state.units=[]
	for team in range(4):
		var pos: int=[0,8,72,80][team]
		sim.state.factions[team].home=pos
		sim.state.factions[team].funds=1000
		sim.state.factions[team].tax=0
		sim.state.leaders[team].pos=pos
		sim.state.leaders[team].target=pos
		sim.state.leaders[team].power=100
		sim.state.leaders[team].order="wait"
	return sim

func add_unit(sim, id: int, team: int, pos: int, power: int=100, order: String="wait", target: int=-1, manual: bool=true) -> Dictionary:
	var u: Dictionary={"id":id,"team":team,"pos":pos,"power":power,"order":order,"target":pos if target<0 else target,"manual":manual,"king":false}
	sim.state.units.append(u)
	return u

func test_population() -> void:
	var sim = sandbox()
	var b: Dictionary={"id":90,"team":0,"pos":40,"pop":16}
	sim.state.bases=[b]
	equal(sim.around(40).size(),8,"A population territory uses eight surrounding cells")
	equal(sim.population_limit(b),16,"A zero surrounding territory cap")
	for p in sim.around(40):sim.state.cells[p].owner=0
	equal(sim.population_limit(b),144,"A eight owned surrounding territory cap")
	sim.state.cells[30].owner=1
	equal(sim.population_limit(b),128,"foreign neighboring cell excluded from cap")
	sim.state.cells[30].owner=0;b.pop=145
	sim._population()
	equal(b.pop,1,"A population after sortie retains one")
	equal(sim.state.units.size(),1,"A overcrowded non-expandable base spawns one unit")
	equal(sim.state.units[0].power,144,"A spawned strength P-1")
	equal(sim.state.units[0].order,"auto","A default initial sortie command auto")
	b.pop=10
	sim._population()
	expect(b.pop>10,"population below cap grows")
	sim.state.units=[];b.pop=144
	sim._population()
	expect(b.pop>144,"C equality cap grows; unmeasured boundary")
	sim.state.cells[30].owner=-1;b.pop=145
	sim._population()
	equal(sim.state.cells[30].owner,0,"A territorial expansion before sortie")
	equal(sim.state.units.size(),0,"expansion postpones sortie")

func test_construction() -> void:
	var sim = sandbox()
	var u: Dictionary=add_unit(sim,91,0,40,100,"build_village")
	sim._work()
	equal(sim.state.factions[0].funds,900,"A village 100G deducted")
	equal(sim.get_base(40).team,0,"village established")
	equal(u.power,68,"C village population cost explicitly 32")
	equal(sim.get_base(40).pop,32,"C new village initial population explicitly 32")
	var owned:=0
	for p in sim.around(40):
		if sim.state.cells[p].owner==0:owned+=1
	equal(owned,8,"village claims surrounding eight cells")
	expect(not sim._can_build(30,0),"A diagonal own village adjacency blocks building")
	expect(not sim._can_build(39,0),"A cardinal own village adjacency blocks building")
	expect(sim._can_build(30,1),"A enemy village adjacency allowed")
	expect(sim._can_build(40,1),"A enemy village overlay allowed")
	expect(not sim._can_build(0,0),"castle center blocks village")
	u.pos=0;u.target=0;u.order="build_fence"
	sim._work()
	equal(sim.state.cells[0].fence,0,"castle center blocks fence")
	u.pos=40;u.target=40;u.order="destroy_village"
	sim._work()
	equal(sim.state.bases.size(),0,"C explicit village demolition removes selected base")
	u.pos=50;u.target=51;u.order="build_bridge"
	sim.state.cells[51].terrain=2
	var money: int=sim.state.factions[0].funds
	sim._work()
	equal(sim.state.cells[51].bridge,1,"A bridge passable at durability one")
	equal(sim.state.factions[0].funds,money-30,"A first bridge point costs 30G")
	u.order="destroy_bridge";sim._work()
	equal(sim.state.cells[51].bridge,0,"bridge destroyed")
	expect(sim.state.cells[51].bridge_built,"bridge historical construction remembered")
	u.order="build_bridge";money=sim.state.factions[0].funds;sim._work()
	equal(sim.state.factions[0].funds,money-2,"A damaged bridge point repair costs 2G")
	u.target=49;u.order="build_fence";money=sim.state.factions[0].funds;sim._work()
	equal(sim.state.cells[49].fence,4,"A fence gives four durability")
	equal(sim.state.factions[0].funds,money-1,"A fence four durability costs 1G")
	sim.state.factions[0].funds=0;u.target=59;u.order="build_village";u.pos=59
	sim._work()
	expect(sim.get_base(59).is_empty(),"insufficient funds cannot construct village")

func test_tax_and_decay() -> void:
	var sim = sandbox()
	var b: Dictionary={"id":90,"team":0,"pos":4,"pop":128}
	sim.state.bases=[b];sim.state.factions[0].tax=10
	# A single corridor prevents incidental alternate tax routes.
	for p in range(9,81):sim.state.cells[p].terrain=3
	expect(sim.can_tax(b),"A reachable village with home king taxes")
	sim.state.leaders[0].pos=1
	expect(not sim.can_tax(b),"A away king suspends tax")
	sim.state.leaders[0].pos=0;sim.state.factions[0].tax=0
	expect(not sim.can_tax(b),"A zero tax yields no taxation")
	sim.state.factions[0].tax=10;sim.state.cells[2].owner=1
	expect(not sim.can_tax(b),"A foreign territory blocks tax corridor")
	sim.state.cells[2].owner=0
	expect(sim.can_tax(b),"own territory passes tax")
	sim.state.cells[2].fence=4
	expect(not sim.can_tax(b),"A fence blocks tax corridor")
	sim.state.cells[2].fence=0;sim.state.cells[2].terrain=2
	expect(not sim.can_tax(b),"A unbridged water blocks tax corridor")
	sim.state.cells[2].bridge=1;sim.state.cells[2].bridge_built=true
	expect(sim.can_tax(b),"A bridge restores tax corridor")
	sim.state.bases.append({"id":93,"team":1,"pos":2,"pop":1})
	expect(not sim.can_tax(b),"A foreign village blocks tax corridor")
	sim.state.bases.pop_back()
	sim.state.factions[0].tax=0;sim.state.tick=sim.rules.decay_period
	var u: Dictionary=add_unit(sim,91,0,4,2047)
	var funds: int=sim.state.factions[0].funds
	sim._economy()
	equal(u.power,2047,"A own base immune to natural decay below upkeep threshold")
	equal(sim.state.factions[0].funds,funds,"2047 no upkeep")
	u.power=2048;sim._economy()
	equal(u.power,2048,"B candidate own base with funds maintains large force")
	equal(sim.state.factions[0].funds,funds-1,"C upkeep threshold begins at 2048")
	u.pos=3;funds=sim.state.factions[0].funds;sim._economy()
	expect(u.power<2048,"A outside base naturally decays")
	equal(sim.state.factions[0].funds,funds,"B candidate outside-base large force no upkeep")
	u.pos=4;u.power=2048;sim.state.factions[0].funds=0;sim._economy()
	expect(u.power<2048,"A insufficient upkeep funds decay even at own base")

func test_merging() -> void:
	var sim = sandbox()
	var a: Dictionary=add_unit(sim,91,0,40,10,"defend",40,true)
	var b: Dictionary=add_unit(sim,92,0,40,200,"auto",40,false)
	equal(sim._absorber(a,b).id,a.id,"A manual command priority before stronger unit")
	sim._contacts()
	equal(sim.state.units.size(),1,"A friendly contact merges")
	equal(a.power,210,"A merge population conserved")
	equal(a.order,"defend","A absorber retains command")
	sim.state.leaders[0].pos=40
	sim._contacts()
	equal(sim.state.leaders[0].power,310,"A king highest absorber priority")
	equal(sim.state.units.size(),0,"absorbed donor removed")
	sim = sandbox()
	a=add_unit(sim,91,0,40,10,"auto",40,false)
	b=add_unit(sim,92,0,41,100,"auto",41,false)
	add_unit(sim,93,0,50,20,"reinforce",40,false)
	equal(sim._absorber(a,b).id,a.id,"A reinforcement destination before stronger unit")
	sim.state.units.pop_back()
	equal(sim._absorber(a,b).id,b.id,"A stronger unit absorbs without priority flags")
	a.power=100
	equal(sim._absorber(a,b).id,a.id,"C equal priority stable lower id")

func test_leaders_and_result() -> void:
	var sim = sandbox()
	add_unit(sim,91,0,40,100)
	sim.state.bases.append({"id":92,"team":0,"pos":30,"pop":50})
	equal(sim.population(0),150,"A king reference excludes king itself")
	sim.state.leaders[0].power=100;sim._leaders()
	equal(sim.state.leaders[0].power,116,"C home king gradually recovers toward total population")
	sim.state.leaders[0].pos=1;sim._leaders()
	equal(sim.state.leaders[0].power,116,"A away king no home recovery")
	equal(sim._castle_factor(sim.state.leaders[0]),1,"C castle factor absent outside home")
	sim.state.leaders[0].pos=0
	equal(sim._castle_factor(sim.state.leaders[0]),4,"C exact king castle factor four")
	sim.state.units=[];sim.state.bases=[];sim._leaders()
	expect(not sim.state.leaders[0].alive,"A no bases and troops eliminates king")
	equal(sim.state.leaders[0].power,0,"A supportless king strength zero")
	sim._outcome()
	equal(sim.state.result,"defeat","player king loss defeat")
	sim=sandbox();var initial: int=sim.state.factions[0].funds
	sim.state.bases.append({"id":92,"team":1,"pos":30,"pop":50})
	add_unit(sim,91,1,40,100)
	sim._eliminate(1,0)
	equal(sim.state.bases[0].team,0,"A king capture transfers villages")
	equal(sim.state.units[0].team,0,"A king capture transfers units")
	equal(sim.state.factions[0].funds,initial+1000,"A king capture transfers funds")
	equal(sim.state.factions[1].funds,0,"captured treasury cleared")
	sim._eliminate(2,-1);sim._eliminate(3,-1);sim._outcome()
	equal(sim.state.result,"victory","three enemy kings gone victory")
	sim=sandbox();sim.state.day=sim.state.limit_days;sim._outcome()
	equal(sim.state.result,"defeat","A day limit timeout defeat")

func test_external_phase_order() -> void:
	var a = sandbox()
	var b = sandbox()
	add_unit(a,91,0,40)
	add_unit(b,91,0,40)
	a.state.tick=1;b.state.tick=1
	var phases: Array=b.rules.phase_order.duplicate()
	var movement: int=phases.find("movement")
	phases.remove_at(movement);phases.push_front("movement")
	b.rules.phase_order=phases
	a.step([a.issue("move",[91],41)])
	b.step([b.issue("move",[91],41)])
	equal(a.get_unit(91).pos,41,"C command-before-movement phase applies same tick")
	equal(b.get_unit(91).pos,40,"external phase order can defer movement")
	var sim=fresh()
	var start: String=sim.state_hash()
	var issued: Dictionary=sim.issue("wait",[4])
	equal(sim.state_hash(),start,"issuing UI command alone does not advance simulation")
	sim.step([issued,issued])
	equal(sim.command_log.size(),1,"duplicate sequence applied and logged only once")
	equal(sim.get_unit(4).order,"wait","queued manual command reaches simulation")

func test_development_ai() -> void:
	var sim = sandbox()
	var u: Dictionary = add_unit(sim, 91, 1, 40, 200, "auto", -1, false)
	sim.state.cells[41].terrain = 1
	sim._ai()
	equal(u.order, "build_base", "AI builds available housing before reclaiming nearby rough land")
	var first: int = u.target
	sim._ai()
	equal(u.target, first, "AI retains valid housing project while travelling")
	u.pos = first
	sim._work()
	expect(not sim.get_base(first).is_empty(), "enemy housing project completes")
	sim._ai()
	equal(u.order, "build_base", "enemy continues developing after first house")
	expect(u.target != first, "second housing location is different")
	var second: Dictionary = add_unit(sim, 92, 1, 40, 200, "auto", -1, false)
	sim._ai()
	expect(second.target != u.target and second.target not in sim.around(u.target), "builders reserve separate nonadjacent sites")
	# New explicit mode has no AI's seven-house cap and never issues an attack.
	sim = sandbox()
	sim.state.w = 16; sim.state.h = 16; sim.state.cells = []
	for _i in range(256): sim.state.cells.append({"terrain": 0, "owner": -1, "bridge": 0, "fence": 0, "bridge_built": false})
	for team in range(4):
		var home: int = [0, 15, 240, 255][team]
		sim.state.factions[team].home = home
		sim.state.factions[team].funds = 5000
		sim.state.leaders[team].pos = home
		sim.state.leaders[team].target = home
		sim.state.bases.append({"id": 80 + team, "team": team, "pos": home, "pop": 32})
	sim.state.next_id = 100
	u = add_unit(sim, 91, 0, 34, 1800, "wait")
	var cmd: Dictionary = sim.issue("develop", [91])
	expect(cmd.accepted, "housing auto is accepted without selecting destination")
	sim.step([cmd])
	equal(u.auto_mode, "develop", "housing mode recorded with command")
	var attacked: bool = false
	for _tick in range(480):
		sim.step()
		attacked = attacked or u.get("ai_job", "") == "attack"
	var houses: int = 0
	for base in sim.state.bases:
		if base.team == 0: houses += 1
	expect(houses > 7, "housing auto continues beyond regular AI development cap; houses=" + str(houses))
	expect(not attacked, "housing auto never changes into an attack")
	equal(u.auto_mode, "develop", "housing mode persists through repeated completed jobs")
	var copy = fresh()
	expect(copy.restore(sim.snapshot()), "housing mode survives save restore")
	equal(copy.get_unit(91).auto_mode, "develop", "restored housing mode preserved")
	sim.step([sim.issue("wait", [91])])
	equal(u.auto_mode, "", "manual wait cancels continuous housing mode")
	sim.step([sim.issue("initial_order", [], -1, {"order": "develop"})])
	equal(sim.state.factions[0].initial_order, "develop", "new sorties can start in housing mode")
	# Too weak/poor builders wait on their own supply village rather than becoming attackers.
	sim = sandbox()
	sim.state.bases = [{"id": 90, "team": 0, "pos": 40, "pop": 32}]
	u = add_unit(sim, 91, 0, 41, 10, "develop", -1, false)
	u["auto_mode"] = "develop"
	sim.state.factions[0].funds = 0
	sim._ai()
	equal(u.target, 40, "resource-starved housing unit returns to own village")
	equal(u.ai_job, "rally", "resource-starved builder gathers rather than attacks")

func test_ai_stalemate() -> void:
	# A developed enemy must keep founding villages, while retaining a field army.
	var sim = sandbox()
	sim.state.w = 16; sim.state.h = 16; sim.state.cells = []
	for _i in range(256): sim.state.cells.append({"terrain": 0, "owner": -1, "bridge": 0, "fence": 0, "bridge_built": false})
	for team in range(4):
		var home: int = [0, 15, 240, 255][team]
		sim.state.factions[team].home = home
		sim.state.factions[team].funds = 5000
		sim.state.leaders[team].pos = home
		sim.state.leaders[team].target = home
	for pos in [15, 43, 45, 75, 77, 107, 109]:
		sim.state.bases.append({"id": 100 + pos, "team": 1, "pos": pos, "pop": 32})
	sim.state.next_id = 500
	var builder: Dictionary = add_unit(sim, 300, 1, 140, 240, "auto", -1, false)
	var army: Dictionary = add_unit(sim, 301, 1, 142, 700, "auto", -1, false)
	sim._ai()
	equal(builder.order, "build_base", "ordinary enemy auto keeps developing after seven villages")
	expect(army.get("ai_job", "") != "develop", "development retains a separate field army")
	for _project in range(3):
		builder.pos = builder.target
		sim._work()
		sim._ai()
	equal(sim.state.bases.size(), 10, "ordinary enemy completes multiple villages beyond former cap")
	# Inadequate independent armies must meet and physically merge.
	sim = sandbox()
	sim.state.bases = [{"id": 90, "team": 1, "pos": 22, "pop": 32}, {"id": 93, "team": 1, "pos": 58, "pop": 32}]
	sim.state.factions[1].funds = 0
	var first: Dictionary = add_unit(sim, 91, 1, 22, 60, "auto", -1, false)
	var second: Dictionary = add_unit(sim, 92, 1, 58, 60, "auto", -1, false)
	sim._ai()
	equal(first.target, second.target, "weak armies converge on same supply village")
	for _move in range(12):
		sim._movement()
		sim._contacts()
	equal(sim.state.units.size(), 1, "rally produces a merged army rather than permanent scattered waits")
	equal(sim.state.units[0].power, 120, "rally preserves and combines both armies")
	# An enemy army cannot select a distant weak target behind an impassable
	# superior screen; a reachable detour must actually be used when one exists.
	sim = sandbox()
	sim.state.units = []
	var mover: Dictionary = add_unit(sim, 91, 1, 36, 100, "move", 44, false)
	mover["auto_mode"] = "auto"; mover["ai_job"] = "attack"
	add_unit(sim, 92, 0, 40, 5000, "wait")
	sim.state.leaders[0].power = 0; sim.state.leaders[2].power = 0; sim.state.leaders[3].power = 0
	for _move in range(24): sim._movement()
	equal(mover.pos, 44, "automatic army detours around superior enemy screen")
	# A sealed choke must make the target unreachable during planning.
	for pos in range(81):
		if pos / 9 != 4: sim.state.cells[pos].terrain = 2
	var reachable: Dictionary = sim._reachable(36, sim._threat_map(1), 100)
	expect(not reachable.has(44), "sealed dangerous choke is excluded from attack planning")
	# Regression for old-save builders repeatedly absorbed into a stationary army.
	sim = sandbox()
	sim.state.leaders[0].power = 0; sim.state.leaders[2].power = 0; sim.state.leaders[3].power = 0
	var worker: Dictionary = add_unit(sim, 91, 1, 36, 100, "build_base", 44, false)
	worker["auto_mode"] = "auto"; worker["ai_job"] = "develop"
	add_unit(sim, 92, 1, 40, 1000, "wait", -1, true)
	for _move in range(16):
		sim._movement(); sim._contacts()
	equal(worker.pos, 44, "builder detours around friendly army without losing its job")
	equal(sim.state.units.size(), 2, "construction worker is not absorbed into stationary army")
	sim._work()
	expect(not sim.get_base(44).is_empty(), "detoured builder actually founds its village")
	# Old saves remain valid without the new optional tuning fields.
	sim = fresh()
	var saved: Dictionary = sim.snapshot()
	saved.rules.erase("ai_builder_max"); saved.rules.erase("ai_builder_divisor")
	saved.checksum = sim.snapshot_hash(saved)
	expect(sim.restore(saved), "old saves without builder tuning remain loadable")
	saved.rules.ai_builder_divisor = 0; saved.checksum = sim.snapshot_hash(saved)
	expect(not sim.restore(saved), "zero builder divisor cannot enter restored rules")

func test_attack_judgment() -> void:
	var sim = sandbox()
	sim.rules.ai_development_bases = 1
	sim.state.factions[0].home = 40
	sim.state.leaders[0].pos = 40
	sim.state.leaders[0].power = 100
	sim.state.bases = [{"id": 90, "team": 1, "pos": 49, "pop": 32}]
	var u: Dictionary = add_unit(sim, 91, 1, 49, 96, "auto", -1, false)
	sim._ai()
	equal(u.ai_job, "rally", "weak army gathers instead of charging defended castle")
	equal(u.target, 49, "gathering happens at own village")
	equal(sim.state.leaders[1].target, 8, "weak enemy king remains at home")
	u.power = 700
	sim._ai()
	equal(u.ai_job, "attack", "army attacks after achieving effective strength advantage")
	equal(u.target, 40, "strong army targets nearby enemy castle")
	sim.state.leaders[0].power = 1000
	sim._ai()
	equal(u.ai_job, "rally", "attack is reconsidered when defenders grow stronger")
	u.power = 500
	u.target = 40; u.order = "move"; u["ai_job"] = "attack"
	sim._movement()
	equal(u.pos, 49, "automatic movement does not enter overwhelming defender zone between decisions")

func test_bank_work() -> void:
	var sim = sandbox()
	sim.state.cells[40].terrain = 2
	sim.state.cells[40].bridge = 8
	sim.state.cells[40].bridge_built = true
	var u: Dictionary = add_unit(sim, 91, 0, 40, 100, "destroy_bridge", 40)
	sim._work()
	equal(sim.state.cells[40].bridge, 8, "standing on a bridge cannot demolish it")
	sim._movement()
	expect(u.pos in sim.neighbors(40) and sim._land(u.pos), "unit steps from bridge onto adjacent land before demolition")
	var bank: int = u.pos
	sim._work()
	equal(sim.state.cells[40].bridge, 4, "bridge damaged from bank")
	sim._movement()
	equal(u.pos, bank, "unit remains on bank while bridge exists")
	sim._work()
	equal(sim.state.cells[40].bridge, 0, "bridge fully demolished from land")
	sim._movement()
	equal(u.pos, bank, "unit stays safely on land after bridge disappears")
	u.order = "build_bridge"; u.target = 40
	sim._work()
	equal(sim.state.cells[40].bridge, 1, "bridge repaired from bank")
	u.order = "build_bridge"
	sim._movement()
	equal(u.pos, bank, "repairing an existing bridge does not move onto it")
	u.pos = 39; u.target = 40; u.order = "destroy_bridge"
	sim.state.cells[39].terrain = 2; sim.state.cells[39].bridge = 1
	sim._work()
	equal(sim.state.cells[40].bridge, 1, "adjacent water bridge is not a valid land worksite")
	u.pos = 20; u.order = "build_fence"; u.target = 20
	sim._movement()
	expect(u.pos != 20 and u.pos in sim.neighbors(20), "fence construction moves off its target onto adjacent land")
	sim._work()
	equal(sim.state.cells[20].fence, 4, "fence built from adjacent land")
	for pos in sim.neighbors(40):
		sim.state.cells[pos].terrain = 2; sim.state.cells[pos].bridge = 0
	u.pos = 10
	var command: Dictionary = sim.issue("build_bridge", [91], 40)
	expect(not command.accepted, "bridge work rejected when no reachable adjacent land exists")
	# Preview uses the same bank destination as movement.
	sim = sandbox()
	sim.state.cells[40].terrain = 2; sim.state.cells[40].bridge = 4
	u = add_unit(sim, 91, 0, 10, 100)
	var preview: Array = sim.path_preview(91, 40, "destroy_bridge")
	expect(not preview.is_empty(), "bank work path preview exists")
	expect(preview.back() in sim.neighbors(40) and preview.back() != 40, "bank work preview ends on land, not bridge")
