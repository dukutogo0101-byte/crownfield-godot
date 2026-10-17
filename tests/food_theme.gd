extends SceneTree
const Food = preload("res://ui/food_theme.gd")
var checks: int = 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(740, 360)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame; await process_frame
	scene._reset_game("res://data/maps/shop_crossing.json")
	var hash_before: String = scene.sim.state_hash()
	check(Food.active(scene.sim.state), "shop map activates the food theme")
	check(scene._team_name(0) == "ウィバーガー" and scene._team_color(0) == Food.COLORS[0], "player is the red burger business")
	for action in ["build_base", "destroy_base", "build_bridge", "destroy_bridge", "build_fence", "destroy_fence", "reclaim"]:
		check(scene._order_name(action) == Food.ORDERS[action], "context command label: " + action)
	for id in scene.order_menu_actions:
		check(scene.command_menu.get_popup().get_item_text(scene.command_menu.get_popup().get_item_index(id)) == scene._order_name(scene.order_menu_actions[id]), "dropdown label follows its actual command ID")
	check(scene.order_buttons.develop.text == "出店オート", "persistent development button uses store language")
	check(scene.faction_labels[0].text.contains("ウィバーガー") and scene.resource_label.text.contains("従業員"), "HUD identifies restaurant setting")
	check(scene.board._map_layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pixel art uses nearest sampling")
	check(scene.board.textures.has("food_shop0") and scene.board.textures.has("food_manager3") and scene.board.textures.has("food_rail15"), "atlas covers shops, managers and rail junctions")
	var ford: int = 20 * 48 + 41
	check(Food.tile_key(scene.sim.state, scene.sim.state.factions[0].home) == "food_owned_pavement0", "player lot uses the original-style red paving palette")
	check(Food.tile_key(scene.sim.state, ford).begins_with("food_rail"), "unbridged water is displayed as rails")
	check(Food.crossing_key(scene.sim.state, ford).begins_with("food_crossing"), "bridge uses passable rail crossing overlay")
	var image: Image = scene.board._mini_texture.get_image()
	check(image.get_pixel(ford % 48, ford / 48).is_equal_approx(Color("252a22")), "rail is dark on the minimap, not blue water")
	var before: String = scene.sim.state_hash()
	scene._refresh(); scene._show_nations(); scene._close_modal()
	check(scene.sim.state_hash() == before and before == hash_before, "presentation never changes deterministic map state")
	scene._save_game()
	scene._reset_game(scene.MAPS[0].path)
	check(not Food.active(scene.sim.state) and scene._order_name("build_base") == "村建設", "normal map restores medieval labels")
	check(scene.board._map_layer.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE, "normal map restores its original filtering")
	check(scene._load_game() and Food.active(scene.sim.state) and scene.sim.state_hash() == hash_before, "save restores both the original state and food presentation")
	check(scene._order_name("build_bridge") == "踏切を作る", "loaded map restores themed command menu")
	scene.selected = [4]
	scene._choose_order("develop")
	scene._step_game()
	check(scene.sim.get_unit(4).get("auto_mode") == "develop", "store-auto still issues the shared development command")
	scene.paused = true
	scene._refresh()
	for _frame in range(4): await process_frame
	check(scene.bottom.get_global_rect().end.x <= scene.size.x and scene.bottom.size.y <= 64, "restaurant commands fit a short landscape phone")
	check(scene.board.cell_at(scene.board.cell_point(2303)) == 2303, "48x48 corner remains tappable")
	# Rasterize the actual imported atlas for visual inspection without a browser.
	var atlas: Image = Food.ATLAS.get_image()
	check(atlas != null and atlas.get_width() == 256 and atlas.get_height() == 192, "all 46 pixel tiles imported")
	atlas.save_png("/tmp/crownfield-food-atlas.png")
	var document: Dictionary = {"checks": checks, "passed": checks - failures.size(), "failed": failures, "scope": "Godot native/headless food skin, labels, pixel resources, minimap, input, save/load and state isolation; actual phone/browser not tested"}
	var file = FileAccess.open("res://tests/food_theme_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "\t")); file.close()
	print("FOOD THEME ", checks - failures.size(), "/", checks)
	scene.audio_player.stop(); scene.audio_player.stream = null
	await create_timer(0.1).timeout
	scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
