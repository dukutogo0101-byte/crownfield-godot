extends RefCounted
## Pure presentation: map/rules/save hashes never depend on this skin.
const COLORS = [Color("e65b45"), Color("f4f0d8"), Color("f4c345"), Color("5796ed")]
const NAMES = ["ウィバーガー", "全国屋台連合", "タコ商会", "ハチマキ寿司"]
const ORDERS = {"wait": "臨時休業", "develop": "出店オート", "defend": "待ち伏せ", "reinforce": "応援", "build_base": "新装開店", "destroy_base": "店じまい", "reclaim": "宅地造成", "build_bridge": "踏切を作る", "destroy_bridge": "踏切を壊す", "build_fence": "生ゴミ捨てる", "destroy_fence": "生ゴミかたす", "seal_cave": "暴力追放運動"}
const ATLAS = preload("res://assets/foods/atlas.svg")

static func active(state: Dictionary) -> bool:
	return state.get("id", "") == "shop_crossing"

static func install(textures: Dictionary) -> void:
	var names: Array = ["pavement", "lot", "office", "refuse", "crossing_h", "crossing_v"]
	for kind in ["shop", "hq", "courier", "manager"]:
		for team in range(4): names.append(kind + str(team))
	for mask in range(16): names.append("rail" + str(mask))
	for kind in ["owned_pavement", "owned_lot"]:
		for team in range(4): names.append(kind + str(team))
	for index in range(names.size()):
		var tile: AtlasTexture = AtlasTexture.new()
		tile.atlas = ATLAS
		tile.region = Rect2((index % 8) * 32, (index / 8) * 32, 32, 32)
		textures["food_" + names[index]] = tile

static func rail_mask(state: Dictionary, pos: int) -> int:
	var mask: int = 0
	var width: int = state.w
	var x: int = pos % width
	var y: int = pos / width
	if y > 0 and state.cells[pos - width].terrain == 2: mask |= 1
	if x + 1 < width and state.cells[pos + 1].terrain == 2: mask |= 2
	if y + 1 < state.h and state.cells[pos + width].terrain == 2: mask |= 4
	if x > 0 and state.cells[pos - 1].terrain == 2: mask |= 8
	return mask

static func tile_key(state: Dictionary, pos: int) -> String:
	var terrain: int = state.cells[pos].terrain
	if terrain == 2: return "food_rail" + str(rail_mask(state, pos))
	var owner: int = state.cells[pos].owner
	if owner >= 0 and owner < 4 and terrain in [0,1]: return "food_owned_" + ("pavement" if terrain == 0 else "lot") + str(owner)
	return ["food_pavement", "food_lot", "food_rail0", "food_office"][clampi(terrain, 0, 3)]

static func crossing_key(state: Dictionary, pos: int) -> String:
	var mask: int = rail_mask(state, pos)
	return "food_crossing_h" if mask & 5 else "food_crossing_v"
