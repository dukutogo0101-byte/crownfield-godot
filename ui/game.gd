extends Control
## UI host: wall-clock speed, input, presentation and file I/O never define rules.
const Simulation = preload("res://core/simulation.gd")
const Field = preload("res://ui/field_theme.gd")
const Board = preload("res://ui/board.gd")
const Food = preload("res://ui/food_theme.gd")
const ClearRecords = preload("res://core/clear_records.gd")
const COLORS = [Color("54b9f3"), Color("ee7771"), Color("e9b959"), Color("8bcfa6")]
const MAPS = [
	{"id": "four_rivers", "path": "res://data/maps/four_rivers.json", "name": "四つの川", "description": "従来のマップ。四方の川と橋を巡って争う標準面。"},
	{"id": "open_plains", "path": "res://data/maps/open_plains.json", "name": "開けた野", "description": "入門向け。広い平地で村を増やし、兵を集める基本を学ぶ。"},
	{"id": "twin_crossings", "path": "res://data/maps/twin_crossings.json", "name": "二つの渡し", "description": "橋の防衛と迂回を楽しむ面。各方面の複数の渡しを使おう。"},
	{"id": "borderlands", "path": "res://data/maps/borderlands.json", "name": "境界の半島", "description": "標準向け。半島の内政地を育て、中央の争奪地へ進もう。"},
	{"id": "succession_isthmus", "path": "res://data/maps/succession_isthmus.json", "name": "継承の地峡", "description": "既設橋と地峡で攻防。南の桟橋へ架橋すれば、海の向こうの国にも進める。"},
	{"id": "half_sea", "path": "res://data/maps/half_sea.json", "name": "片海", "description": "海で東西に分かれた戦場。各地峡を守り、北の桟橋から海を越えよう。"},
	{"id": "spiral_channel", "path": "res://data/maps/spiral_channel.json", "name": "渦の水路", "description": "4国が水路で隔てられた面。敵も架橋するので、内政と渡河のタイミングが重要。"},
	{"id": "shop_crossing", "path": "res://data/maps/shop_crossing.json", "name": "店先の踏切 — フーズパニック", "description": "ハンバーガー店を率いる48×48の商店街。線路で分かれた区画に出店しよう。右上の屋台連合は踏切が切れているが、自ら修理してくる。"}
]
const ORDERS = [
	["move", "移動", "選択した部隊を目的地へ移動。王に出せる行動命令は移動だけです。"],
	["wait", "待機", "現在地で停止。自国の村に待機すると自然減少を抑えられます。"],
	["auto", "オート", "住居建設を優先。戦力を集め、城の防御も含めて十分有利なときに攻撃します。"],
	["develop", "住居オート", "住居を繰り返し建設。必要な開墾も行い、兵力や資金が足りないときは、その場で待機して建設命令を保ちます。攻撃は行いません。"],
	["defend", "拠点防衛", "目的の自国拠点を防衛。"],
	["reinforce", "援軍", "目的地の味方へ合流。合流先の命令を維持します。"],
	["build_base", "村建設", "さら地に村を建設。資金100。人口移転量は暫定値です。"],
	["destroy_base", "村破壊", "目的地の村を破壊。"],
	["reclaim", "開墾", "荒れ地をさら地にします。"],
	["build_bridge", "橋建設", "隣の陸地から水面に橋を架けます。新設は耐久1ごと資金30、修理は2。"],
	["destroy_bridge", "橋破壊", "橋に隣接する陸地から破壊し、相手の進軍や税路を断ちます。"],
	["build_fence", "柵建設", "隣の陸地から柵を建設。耐久4ごと資金1。"],
	["destroy_fence", "柵破壊", "隣の陸地から目的地の柵を破壊。"],
	["seal_cave", "洞窟封鎖", "魔物の洞窟を封鎖。魔物の数値・周期は暫定値です。"]
]

var sim = Simulation.new()
var clear_records = ClearRecords.new()
var run_id: String = ""
var clear_status: String = ""
var record_eligible: bool = true
var board: Control
var selected: Array = []
var pending: Array = []
var active_order: String = ""
var paused: bool = true
var speed: int = 1
var accumulator: float = 0.0
var portrait: bool = false
var replay_initial: Dictionary = {}
var command_log: Array = []
var checkpoints: Array = []
var replay_playback: bool = false
var playback_data: Dictionary = {}
var playback_index: int = 0
var end_shown: bool = false
var modal: Control
var faction_grid: GridContainer
var bottom: PanelContainer
var status_label: Label
var selection_label: Label
var clock_label: Label
var faction_labels: Array = []
var pause_button: Button
var audio_player: AudioStreamPlayer
var _last_status_ms: int = 0
var _manual_status: String = ""
var selection_bar: PanelContainer
var overview_button: Button
var top_row: HBoxContainer
var ui_inset := Vector4.ZERO
var modal_panel: PanelContainer
var modal_scroll: ScrollContainer
var title_art: Control
var title_scroll: ScrollContainer
var title_content: VBoxContainer
var top_bar: PanelContainer
var menu_button: MenuButton
var initial_menu: MenuButton
var auto_menu: MenuButton
var command_menu: MenuButton
var command_cluster: HBoxContainer
var order_menu_actions: Dictionary = {}
var clear_button: Button
var tax_slider: HSlider
var tax_label: Button
var resource_label: Label
var _tax_syncing: bool = false
var web_file_callback
var selected_map_index: int = 0
var map_selector: OptionButton
var map_record_label: Label
var map_description: Label
var map_start_button: Button

func _ready() -> void:
	clear_records.load_records()
	_setup_theme()
	_setup_ui()
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	get_viewport().size_changed.connect(_adaptive_layout)
	_adaptive_layout()
	if not sim.new_game():
		_set_status("ゲームデータの読込に失敗しました。", true)
		return
	_new_recording()
	_refresh()
	_show_title()

func _setup_theme() -> void:
	theme = Field.setup(load("res://assets/fonts/ja.ttf"))

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func _button(text_value: String, callback: Callable, tooltip: String = "") -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	return button

func _label(value: String, font_size: int = 16) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _setup_ui() -> void:
	board = Board.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.cell_tapped.connect(_on_cell_tapped)
	board.range_selected.connect(_on_range_selected)
	board.cancel_requested.connect(_cancel_order)
	board.inspect_requested.connect(_inspect_cell)
	board.path_provider = Callable(self, "_preview_order_path")
	add_child(board)
	# The board owns the full viewport. Only the actual HUD rectangles intercept touches.
	top_bar = PanelContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 8; top_bar.offset_right = -8; top_bar.offset_top = 8
	top_bar.add_theme_stylebox_override("panel", _hud_style())
	add_child(top_bar)
	var row: HBoxContainer = HBoxContainer.new()
	top_row = row
	row.add_theme_constant_override("separation", 8)
	top_bar.add_child(row)
	menu_button = MenuButton.new()
	menu_button.flat = false
	Field.icon_on(menu_button, "menu", 19)
	menu_button.custom_minimum_size = Vector2(44, 44)
	menu_button.tooltip_text = "ゲームメニュー"
	row.add_child(menu_button)
	var menu: PopupMenu = menu_button.get_popup()
	menu.add_item("速度 1×", 0)
	menu.add_item("地図を全景表示", 1)
	menu.add_check_item("範囲選択", 2)
	menu.add_item("全画面表示／解除", 3)
	menu.add_separator()
	menu.add_item("各国の状況", 4)
	menu.add_separator()
	menu.add_item("保存", 6)
	menu.add_item("読込", 7)
	menu.add_item("保存・リプレイ・JSON", 8)
	menu.add_item("クリア記録", 11)
	if OS.has_feature("web"): menu.add_item("アプリをインストール", 12)
	menu.add_item("操作と説明", 9)
	menu.add_separator()
	menu.add_item("マップ選択・新しいゲーム", 10)
	menu.id_pressed.connect(_on_game_menu)
	pause_button = _compact_button("", _toggle_pause, "再開／一時停止：ワンタッチ")
	pause_button.custom_minimum_size.x = 46
	Field.gild(pause_button)
	row.add_child(pause_button)
	var coin := TextureRect.new()
	coin.texture = Field.glyph("coin")
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size.x = 19
	coin.modulate = Field.GOLD
	row.add_child(coin)
	resource_label = _label("", 15)
	resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_label.clip_text = true
	resource_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(resource_label)
	clock_label = _label("", 14)
	clock_label.add_theme_color_override("font_color", Field.MUTED)
	row.add_child(clock_label)
	var tax_row: HBoxContainer = HBoxContainer.new()
	tax_row.add_theme_constant_override("separation", 6)
	row.add_child(tax_row)
	tax_label = _compact_button("税10%", _show_tax, "税収・人口増加と徴税経路を確認")
	tax_label.add_theme_font_size_override("font_size", 14)
	tax_label.custom_minimum_size.x = 52
	tax_row.add_child(tax_label)
	tax_slider = HSlider.new()
	tax_slider.min_value = 0; tax_slider.max_value = 30; tax_slider.step = 1
	tax_slider.custom_minimum_size = Vector2(120, 42)
	tax_slider.tooltip_text = "税率：左で人口重視、右で資金重視"
	tax_slider.value_changed.connect(_on_tax_changed)
	tax_row.add_child(tax_slider)
	row.move_child(menu_button, -1)
	row.move_child(pause_button, row.get_child_count()-2)
	# Detailed country cards are available only inside the menu modal.
	faction_grid = GridContainer.new()
	faction_grid.hide()
	add_child(faction_grid)
	for i in 4:
		var label: Label = _label("", 15)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		faction_grid.add_child(label)
		faction_labels.append(label)
	status_label = _label("", 14)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.add_theme_color_override("font_outline_color", Field.INK)
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.hide()
	add_child(status_label)
	bottom = PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _hud_style())
	add_child(bottom)
	selection_bar = PanelContainer.new()
	selection_bar.add_theme_stylebox_override("panel", _hud_style())
	add_child(selection_bar)
	var roster := HBoxContainer.new()
	roster.add_theme_constant_override("separation", 4)
	selection_bar.add_child(roster)
	overview_button = _compact_button("", _toggle_view, "全景／自陣")
	Field.icon_on(overview_button, "map", 20)
	roster.add_child(overview_button)
	var army := _compact_button("全軍", _select_all, "自国の全部隊を選択")
	Field.icon_on(army, "troops", 17)
	roster.add_child(army)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	bottom.add_child(actions)
	selection_label = _label("", 14)
	selection_label.custom_minimum_size.x = 88
	selection_label.clip_text = true
	selection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	roster.add_child(selection_label)
	command_cluster = HBoxContainer.new()
	command_cluster.add_theme_constant_override("separation", 6)
	actions.add_child(command_cluster)
	initial_menu = _command_dropdown("初期 ▾", "新しく出兵する部隊の行動")
	for action in Simulation.Automation.INITIAL:
		initial_menu.get_popup().add_radio_check_item(_automatic_order_name(action), initial_menu.get_popup().item_count)
	initial_menu.get_popup().id_pressed.connect(_on_initial_menu)
	auto_menu = _command_dropdown("オート ▾", "選択した部隊の自動行動")
	for action in Simulation.Automation.MODES:
		auto_menu.get_popup().add_radio_check_item(_automatic_order_name(action), auto_menu.get_popup().item_count)
	auto_menu.get_popup().id_pressed.connect(_on_auto_menu)
	command_menu = _command_dropdown("単発 ▾", "選択した部隊に一度だけ指示。待機は即時、それ以外は目的地をタップ")
	var orders_popup: PopupMenu = command_menu.get_popup()
	for entry in ORDERS:
		if entry[0] in ["auto", "develop"]: continue
		if entry[0] == "build_base": orders_popup.add_separator("住居・地形")
		if entry[0] == "build_bridge": orders_popup.add_separator("橋・柵")
		var id: int = order_menu_actions.size()
		order_menu_actions[id] = entry[0]
		orders_popup.add_radio_check_item(entry[1], id)
	orders_popup.add_separator()
	orders_popup.add_item("目的地指定を取消", 99)
	orders_popup.id_pressed.connect(_on_order_menu)
	clear_button = _compact_button("", _clear_selection, "選択と目的地指定を解除")
	Field.icon_on(clear_button, "close", 15)
	roster.add_child(clear_button)
	for pair in [[initial_menu, "flag"], [auto_menu, "loop"], [command_menu, "cursor"]]:
		Field.icon_on(pair[0], pair[1], 16)
	selection_bar.resized.connect(_position_hud)
	bottom.resized.connect(_position_hud)

func _command_dropdown(label: String, tip: String) -> MenuButton:
	var button: MenuButton = MenuButton.new()
	button.text = label
	button.flat = false
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(76, 44)
	button.get_popup().add_theme_constant_override("v_separation", 12)
	command_cluster.add_child(button)
	return button

func _automatic_order_name(action: String) -> String:
	if action == "auto": return "おまかせ"
	if action == "develop": return "出店を続ける" if Food.active(sim.state) else "住居を増やす"
	var names: Dictionary = {"auto_build_bridge": "橋を架ける", "auto_destroy_base": "敵村を壊す", "auto_destroy_bridge": "敵側の橋を壊す", "auto_build_fence": "国境に柵を作る", "auto_destroy_fence": "敵柵を壊す", "auto_reclaim": "開墾を続ける", "auto_seal_cave": "洞窟を封鎖"}
	if Food.active(sim.state): names.merge({"auto_build_bridge": "踏切を作る", "auto_destroy_base": "敵店を閉める", "auto_destroy_bridge": "敵側の踏切を壊す", "auto_build_fence": "境界に生ゴミを置く", "auto_destroy_fence": "他店の生ゴミを片す", "auto_reclaim": "宅地造成を続ける", "auto_seal_cave": "暴力追放を続ける"}, true)
	return str(names[action]) if names.has(action) else _order_name(action)

func _on_initial_menu(id: int) -> void:
	var actions: Array = Simulation.Automation.INITIAL
	if id < 0 or id >= actions.size(): return
	_submit("initial_order", [], -1, {"team": 0, "order": actions[id]})
	_refresh()

func _on_auto_menu(id: int) -> void:
	if id >= 0 and id < Simulation.Automation.MODES.size(): _choose_order(Simulation.Automation.MODES[id])

func _hud_style() -> StyleBoxFlat:
	return Field.panel()

func _compact_button(value: String, callback: Callable, tip: String = "") -> Button:
	var button: Button = _button(value, callback, tip)
	button.custom_minimum_size = Vector2(44, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button

func _adaptive_layout() -> void:
	# Keep the project reference size fixed. EXPAND handles rotation with uniform
	# scaling; changing content_scale_size in size_changed can race a Web resize.
	var logical_size: Vector2 = get_viewport_rect().size
	portrait = logical_size.y > logical_size.x
	menu_button.get_popup().max_size = Vector2i(0, maxi(160, int(logical_size.y) - 24))
	for dropdown in [initial_menu, auto_menu, command_menu]:
		dropdown.get_popup().max_size = menu_button.get_popup().max_size
	tax_slider.custom_minimum_size.x = 100 if logical_size.x < 850 else 120
	ui_inset = Vector4.ZERO
	if OS.has_feature("web"):
		var safe = JavaScriptBridge.eval("typeof crownfieldSafeArea==='function' ? crownfieldSafeArea() : ''")
		if safe is String:
			var f: PackedFloat32Array = safe.split_floats(",")
			if f.size() == 4: ui_inset = Vector4(f[0]*logical_size.x, f[1]*logical_size.y, f[2]*logical_size.x, f[3]*logical_size.y)
	elif OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		var sr := DisplayServer.get_display_safe_area()
		var screen := Vector2(DisplayServer.screen_get_size())
		if screen.x > 0 and screen.y > 0 and sr.has_area():
			ui_inset = Vector4(sr.position.x/screen.x*logical_size.x, sr.position.y/screen.y*logical_size.y, (screen.x-sr.end.x)/screen.x*logical_size.x, (screen.y-sr.end.y)/screen.y*logical_size.y)
	top_bar.offset_left = 8 + ui_inset.x
	top_bar.offset_right = -8 - ui_inset.z
	top_bar.offset_top = 5 + ui_inset.y
	top_bar.offset_bottom = top_bar.offset_top + top_bar.get_combined_minimum_size().y
	call_deferred("_position_hud")
	if is_instance_valid(title_art): call_deferred("_title_layout")
	elif is_instance_valid(modal_panel): call_deferred("_modal_layout")

func _position_hud() -> void:
	if not is_instance_valid(bottom): return
	var minimum: Vector2 = bottom.get_combined_minimum_size()
	bottom.size = minimum
	bottom.position = Vector2(size.x - minimum.x - 8 - ui_inset.z, size.y - minimum.y - 6 - ui_inset.w)
	selection_label.visible = not selected.is_empty() and size.x - ui_inset.x - ui_inset.z >= 600
	selection_bar.size = selection_bar.get_combined_minimum_size()
	selection_bar.position = Vector2(8 + ui_inset.x, bottom.position.y)
	status_label.position = Vector2(10 + ui_inset.x, bottom.position.y - 28)
	status_label.size = Vector2(maxf(0, size.x - 20 - ui_inset.x - ui_inset.z), 24)
	board.pad_view(Vector4(8 + ui_inset.x, top_bar.offset_bottom + 4, 8 + ui_inset.z, minimum.y + 12 + ui_inset.w))

func _on_game_menu(id: int) -> void:
	match id:
		0: _cycle_speed()
		1: _fit_map()
		2: _toggle_range()
		3: _toggle_fullscreen()
		4: _show_nations()
		6: _save_game()
		7: _load_game()
		8: _show_files()
		9: _show_help()
		10: _show_title()
		11: _show_clear_records()
		12: _show_install()

func _show_install() -> void:
	paused = true
	board.clear_gestures()
	_refresh()
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").CrownfieldInstall.open()

func _on_order_menu(id: int) -> void:
	if id == 99: _cancel_order()
	elif order_menu_actions.has(id): _choose_order(order_menu_actions[id])

func _on_tax_changed(value: float) -> void:
	tax_label.text = "税" + str(int(value)) + "%"
	if _tax_syncing or sim.state.is_empty() or replay_playback: return
	# A drag reserves its latest rate, instead of filling the command log with every pixel.
	for i in range(pending.size() - 1, -1, -1):
		if pending[i].action == "tax": pending.remove_at(i)
	_submit("tax", [], -1, {"value": int(value)})
	var forecast: Dictionary = sim.economy_forecast(0, int(value))
	_set_status(_tax_summary(forecast) + ("。再開後に適用。" if paused else "。次の更新で適用。"))

func _team_color(team: int) -> Color:
	return Food.COLORS[team] if Food.active(sim.state) else COLORS[team]

func _team_name(team: int) -> String:
	return Food.NAMES[team] if Food.active(sim.state) else str(sim.state.factions[team].name)

func _show_nations() -> void:
	var column: VBoxContainer = _open_modal("各店の状況" if Food.active(sim.state) else "各国の状況")
	for i in 4:
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color("182935"), _team_color(i).darkened(0.3), 8))
		column.add_child(card)
		var label: Label = _label(faction_labels[i].text, 16)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var plan = sim.state.factions[i].get("ai_plan", {})
		if i > 0 and plan is Dictionary and not plan.is_empty():
			label.text += "\n方針：" + {"develop": "内政・拡張", "assemble": "戦力集結", "defend": "防衛", "engineer": "経路の整備", "attack": "攻勢"}.get(plan.get("phase", ""), "状況を判断中")
		card.add_child(label)
	column.add_child(_button("閉じる", _close_modal))

func _enter_fullscreen() -> void:
	if DisplayServer.get_name() == "headless": return
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").crownfieldFullscreen(false)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").crownfieldFullscreen(true)
	else:
		var mode: int = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(delta: float) -> void:
	if sim.state.is_empty() or paused or is_instance_valid(modal):
		return
	accumulator = minf(accumulator + minf(delta, 0.25) * float(speed), 0.4)
	var began: int = Time.get_ticks_usec()
	var count: int = 0
	while accumulator >= 0.2 and count < 2:
		accumulator -= 0.2
		_step_game()
		count += 1
		if paused or str(sim.state.get("result", "playing")) != "playing" or Time.get_ticks_usec() - began >= 6000:
			break
	if count > 0:
		_refresh()

func _step_game() -> void:
	var commands: Array = pending.duplicate(true)
	pending.clear()
	var next_tick: int = int(sim.state.tick) + 1
	if replay_playback:
		commands.clear()
		var log: Array = playback_data.get("commands", [])
		while playback_index < log.size() and int(log[playback_index].apply_tick) == next_tick:
			commands.append(log[playback_index].command)
			playback_index += 1
	else:
		for command in commands:
			command_log.append({"apply_tick": next_tick, "command": command.duplicate(true)})
	sim.step(commands)
	if replay_playback:
		for checkpoint in playback_data.get("checkpoints", []):
			if int(checkpoint.tick) == int(sim.state.tick) and str(checkpoint.hash) != sim.state_hash():
				paused = true
				_set_status("リプレイ不一致：tick " + str(sim.state.tick), true)
		if int(sim.state.tick) >= int(playback_data.get("final_tick", 0)):
			paused = true
			var match_hash: bool = sim.state_hash() == str(playback_data.get("final_hash", ""))
			_set_status("リプレイ検証：" + ("最終ハッシュ一致" if match_hash else "最終ハッシュ不一致"), not match_hash)
	else:
		if int(sim.state.tick) % 100 == 0:
			checkpoints.append({"tick": int(sim.state.tick), "hash": sim.state_hash()})
	if str(sim.state.get("result", "playing")) != "playing" and not end_shown:
		paused = true
		end_shown = true
		_record_clear()
		call_deferred("_show_outcome")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or is_instance_valid(modal):
		return
	if event.keycode == KEY_SPACE:
		_toggle_pause()
	elif event.keycode == KEY_F:
		_fit_map()
	elif event.keycode == KEY_ESCAPE:
		_cancel_order()
	elif event.keycode == KEY_A and event.ctrl_pressed:
		_select_all()
	elif event.keycode == KEY_S and event.ctrl_pressed:
		_save_game()
	get_viewport().set_input_as_handled()

func _refresh() -> void:
	if sim.state.is_empty():
		return
	board.selected = selected
	board.animation_enabled = not paused and not is_instance_valid(modal)
	board.movement_duration = float(sim.rules.move_period) * 0.2 / float(speed)
	board.prefer_actor_taps = active_order.is_empty()
	board.set_state(sim.state)
	Field.icon_on(pause_button, "play" if paused else "pause", 18)
	pause_button.tooltip_text = "再開" if paused else "一時停止"
	menu_button.get_popup().set_item_text(0, "速度 " + str(speed) + "×")
	menu_button.get_popup().set_item_checked(2, board.range_mode)
	var day_ticks: int = int(sim.rules.get("day_ticks", 2))
	var remaining: int = int(sim.state.get("remaining_days", int(sim.rules.get("limit_days", 3000)) - int(sim.state.tick) / maxi(1, day_ticks)))
	clock_label.text = str(remaining) + "日"
	var food: bool = Food.active(sim.state)
	resource_label.text = "資金 " + str(sim.state.factions[0].funds) + ("  ·  従業員 " if food else "  ·  人口 ") + str(sim.population(0))
	for i in 4:
		var faction: Dictionary = sim.state.factions[i]
		var population: int = 0
		var units: int = 0
		for base in sim.state.bases:
			if int(base.team) == i:
				population += int(base.pop)
		for unit in sim.state.units:
			if int(unit.team) == i:
				population += int(unit.power)
				units += 1
		faction_labels[i].text = ("● " if bool(faction.alive) else "× ") + _team_name(i) + ("  [あなた]" if i == 0 else "") + "\n資金 " + str(faction.funds) + ("  ·  従業員 " if food else "  ·  人口 ") + str(population) + ("  ·  配達隊 " if food else "  ·  部隊 ") + str(units)
	var display_rate: int = sim.state.factions[0].tax
	for command in pending:
		if command.action == "tax": display_rate = int(command.extra.value)
	_tax_syncing = true
	tax_slider.set_value_no_signal(display_rate)
	tax_label.text = "税" + str(display_rate) + "%"
	tax_slider.tooltip_text = _tax_summary(sim.economy_forecast(0, display_rate)) + "（税率ボタンで詳細）"
	_tax_syncing = false
	tax_slider.editable = not replay_playback and sim.state.result == "playing"
	var valid_ids: Array = []
	var power: int = 0
	var king_selected: bool = false
	var developers: int = 0
	for id in selected:
		var entity: Dictionary = _actor(int(id))
		if not entity.is_empty():
			valid_ids.append(id)
			power += int(entity.power)
			king_selected = king_selected or entity.get("is_leader", false)
			if entity.get("auto_mode", "") == "develop": developers += 1
	selected = valid_ids
	selection_label.text = "" if selected.is_empty() else str(selected.size()) + "隊 · " + str(power) + ((" 店長" if food else " 王") if king_selected else "")
	if developers > 0: selection_label.text += " · 出店" if food else " · 住居"
	clear_button.visible = not selected.is_empty()
	_refresh_command_menus(king_selected)
	menu_button.get_popup().set_item_text(menu_button.get_popup().get_item_index(4), "各店の状況" if food else "各国の状況")
	status_label.visible = not _manual_status.is_empty() and Time.get_ticks_msec() - _last_status_ms < 5000
	if portrait:
		status_label.text = "スマホを横向きにすると、盤面を広く使えます"
		status_label.show()
	call_deferred("_position_hud")

func _refresh_command_menus(king_selected: bool) -> void:
	var locked: bool = replay_playback or sim.state.result != "playing"
	var initial: String = str(sim.state.factions[0].initial_order)
	for command in pending:
		if command.action == "initial_order": initial = str(command.extra.order)
	initial_menu.disabled = locked
	initial_menu.tooltip_text = "新しく出兵する部隊：" + _automatic_order_name(initial)
	var initial_actions: Array = Simulation.Automation.INITIAL
	for id in initial_actions.size():
		initial_menu.get_popup().set_item_text(id, _automatic_order_name(initial_actions[id]))
		initial_menu.get_popup().set_item_checked(id, initial == initial_actions[id])
	auto_menu.disabled = locked or selected.is_empty() or king_selected
	var shared_mode: String = ""
	for index in selected.size():
		var actor: Dictionary = _actor(int(selected[index]))
		var mode: String = str(actor.get("auto_mode", ""))
		if mode.is_empty() and actor.get("order", "") in Simulation.Automation.MODES: mode = str(actor.order)
		for command in pending:
			if command.actors.has(selected[index]): mode = str(command.action) if command.action in Simulation.Automation.MODES else ""
		if index == 0: shared_mode = mode
		elif mode != shared_mode: shared_mode = "mixed"
	for id in Simulation.Automation.MODES.size():
		var action: String = Simulation.Automation.MODES[id]
		auto_menu.get_popup().set_item_text(id, _automatic_order_name(action))
		auto_menu.get_popup().set_item_checked(id, shared_mode == action)
	auto_menu.tooltip_text = "選択した部隊の自動行動" + ("：" + _automatic_order_name(shared_mode) if shared_mode in Simulation.Automation.MODES else "")
	command_menu.disabled = locked or selected.is_empty()
	var popup: PopupMenu = command_menu.get_popup()
	for item in range(popup.item_count):
		if popup.is_item_separator(item):
			if popup.get_item_text(item) in ["住居・地形", "店舗・用地"]: popup.set_item_text(item, "店舗・用地" if Food.active(sim.state) else "住居・地形")
			if popup.get_item_text(item) in ["橋・柵", "踏切・生ゴミ"]: popup.set_item_text(item, "踏切・生ゴミ" if Food.active(sim.state) else "橋・柵")
	for id in order_menu_actions:
		var action: String = str(order_menu_actions[id])
		var item: int = popup.get_item_index(id)
		popup.set_item_text(item, _order_name(action))
		popup.set_item_checked(item, active_order == action)
		popup.set_item_disabled(item, king_selected and action not in ["move", "wait"])
	popup.set_item_disabled(popup.get_item_index(99), active_order.is_empty())
	command_menu.tooltip_text = "目的地を指定中：" + _order_name(active_order) if not active_order.is_empty() else "選択した部隊へ一度だけ指示。待機は即時、ほかは目的地をタップ"
	if not active_order.is_empty():
		command_menu.add_theme_stylebox_override("normal", theme.get_stylebox("pressed","Button"))
	elif command_menu.has_theme_stylebox_override("normal"):
		command_menu.remove_theme_stylebox_override("normal")

func _actor(id: int) -> Dictionary:
	for unit in sim.state.units:
		if int(unit.id) == id:
			var result: Dictionary = unit.duplicate()
			result.is_leader = false
			return result
	for leader in sim.state.leaders:
		if int(leader.id) == id and bool(leader.get("alive", true)):
			var result: Dictionary = leader.duplicate()
			result.is_leader = true
			return result
	return {}

func _on_cell_tapped(cell: int, additive: bool) -> void:
	if cell < 0:
		return
	if not active_order.is_empty() and not selected.is_empty():
		_submit(active_order, selected, cell)
		active_order = ""
		_refresh()
		return
	var hits: Array = []
	for leader in sim.state.leaders:
		if int(leader.team) == 0 and int(leader.pos) == cell and bool(leader.get("alive", true)):
			hits.append(int(leader.id))
	for unit in sim.state.units:
		if int(unit.team) == 0 and int(unit.pos) == cell:
			hits.append(int(unit.id))
	if hits.is_empty() and not selected.is_empty() and not additive and not board.range_mode:
		_submit("move", selected, cell)
		_refresh()
		return
	if not additive:
		selected.clear()
	for id in hits:
		if not selected.has(id):
			selected.append(id)
	if hits.is_empty():
		_inspect_cell(cell)
	else:
		_play_cue("select")
	_refresh()

func _on_range_selected(cells: Array, additive: bool) -> void:
	active_order = ""
	if not additive:
		selected.clear()
	for unit in sim.state.units:
		if int(unit.team) == 0 and cells.has(int(unit.pos)) and not selected.has(int(unit.id)):
			selected.append(int(unit.id))
	_set_status(str(selected.size()) + "隊を範囲選択しました。王は個別に選択します。")
	_refresh()

func _choose_order(action: String) -> void:
	if selected.is_empty():
		return
	if action == "wait" or action in Simulation.Automation.MODES:
		_submit(action, selected, -1)
		active_order = ""
	else:
		active_order = action
		_set_status(_order_name(action) + "：盤面の目的地をタップしてください。")
	_refresh()

func _submit(action: String, actors: Array, target: int = -1, extra: Dictionary = {}) -> void:
	if replay_playback:
		_set_status("再生中は命令できません。新しいゲームを開始してください。", true)
		return
	var result: Dictionary = sim.issue(action, actors, target, extra)
	if bool(result.get("accepted", false)):
		pending.append(result)
		_set_status(_order_name(action) + "を予約。" + ("再開すると適用します。" if paused else "すぐに適用します。"))
		_play_cue("command")
	else:
		_set_status("命令できません：" + str(result.get("reason", "不明な理由")), true)

func _preview_order_path(id: int, target: int) -> Array:
	return sim.path_preview(id, target, active_order)

func _set_status(value: String, error: bool = false) -> void:
	_manual_status = value
	_last_status_ms = Time.get_ticks_msec()
	if is_instance_valid(status_label):
		status_label.text = value
		status_label.show()
		status_label.add_theme_color_override("font_color", Color("ffb3a2") if error else Color("f4dea3"))

func _order_name(action: String) -> String:
	if Simulation.Automation.WORK.has(action): return _automatic_order_name(action)
	if Food.active(sim.state) and Food.ORDERS.has(action): return Food.ORDERS[action]
	if action == "tax": return "税率変更"
	if action == "initial_order": return "出兵時の行動"
	for order in ORDERS:
		if str(order[0]) == action:
			return str(order[1])
	return action

func _toggle_pause() -> void:
	paused = not paused
	accumulator = 0.0
	_refresh()

func _cycle_speed() -> void:
	speed = 2 if speed == 1 else (4 if speed == 2 else 1)
	_refresh()

func _fit_map() -> void:
	board.fit_map()

func _toggle_view() -> void:
	if board.is_overview(): board.focus_home()
	else: board.fit_map()

func _toggle_range() -> void:
	board.range_mode = not board.range_mode
	menu_button.get_popup().set_item_checked(2, board.range_mode)
	_cancel_order()
	_set_status("範囲選択：1本指で囲む。2本指でパン／ピンチ。" if board.range_mode else "通常タップに戻りました。")

func _cancel_order() -> void:
	active_order = ""
	_set_status("命令の目的地指定を取り消しました。")
	_refresh()

func _select_all() -> void:
	selected.clear()
	for unit in sim.state.units:
		if int(unit.team) == 0:
			selected.append(int(unit.id))
	_refresh()

func _clear_selection() -> void:
	selected.clear()
	active_order = ""
	_refresh()

func _inspect_cell(cell: int) -> void:
	if cell < 0 or cell >= sim.state.cells.size():
		return
	var data: Dictionary = sim.state.cells[cell]
	var terrain: int = int(data.get("terrain", 0))
	var food: bool = Food.active(sim.state)
	var info: String = (["舗装地", "未整備の土地", "線路", "事務所"] if food else ["さら地", "荒れ地", "水面", "洞窟"])[clampi(terrain, 0, 3)]
	for base in sim.state.bases:
		if int(base.pos) == cell:
			info += ("  ·  店員 " if food else "  ·  村人口 ") + str(base.pop)
	for unit in sim.state.units:
		if int(unit.pos) == cell:
			info += "  ·  強さ " + str(unit.power) + " / " + _order_name(str(unit.order))
	for leader in sim.state.leaders:
		if int(leader.pos) == cell and bool(leader.get("alive", true)):
			info += ("  ·  店長の強さ " if food else "  ·  王の強さ ") + str(leader.power)
	if int(data.get("bridge", 0)) > 0:
		info += ("  ·  踏切耐久 " if food else "  ·  橋耐久 ") + str(data.bridge)
	if int(data.get("fence", 0)) > 0:
		info += ("  ·  生ゴミ " if food else "  ·  柵耐久 ") + str(data.fence)
	_set_status("(" + str(cell % int(sim.state.w)) + ", " + str(cell / int(sim.state.w)) + ")  " + info)

func _new_recording(restored_run_id: String = "", eligible: bool = true) -> void:
	record_eligible = eligible
	run_id = restored_run_id if not restored_run_id.is_empty() else clear_records.new_run_id()
	clear_status = ""
	board.reset_motion()
	replay_initial = sim.snapshot().duplicate(true)
	command_log.clear()
	checkpoints = [{"tick": int(sim.state.tick), "hash": sim.state_hash()}]
	replay_playback = false
	end_shown = false

func _save_game() -> void:
	var file: FileAccess = FileAccess.open("user://crownfield_save.json", FileAccess.WRITE)
	if file == null:
		_set_status("保存に失敗しました。", true)
		return
	file.store_string(JSON.stringify({"format": 1, "run_id": run_id, "record_eligible": record_eligible and not replay_playback, "snapshot": sim.snapshot(), "pending": pending, "replay_initial": replay_initial, "commands": command_log, "checkpoints": checkpoints}, "\t"))
	_set_status("ゲームを保存しました。読込でこの状態へ戻れます。")

func _load_game() -> bool:
	if not FileAccess.file_exists("user://crownfield_save.json"):
		_set_status("保存データがありません。", true)
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://crownfield_save.json"))
	if not data is Dictionary or not sim.restore(data.get("snapshot", {})):
		_set_status("保存データが壊れているか、互換性がありません。", true)
		return false
	run_id = _run_id_from_save(data)
	record_eligible = data.get("record_eligible", true) == true
	clear_status = ""
	paused = true
	accumulator = 0.0
	selected.clear()
	pending = data.get("pending", [])
	replay_initial = data.get("replay_initial", sim.snapshot())
	command_log = data.get("commands", [])
	checkpoints = data.get("checkpoints", [])
	replay_playback = false
	end_shown = false
	active_order = ""
	_record_clear()
	_set_status("保存状態を読み込みました。再開で時間が進みます。")
	board.reset_motion()
	_refresh()
	return true

func _show_files() -> void:
	var column: VBoxContainer = _open_modal("保存・リプレイ")
	_add_modal_text(column, "命令列と状態ハッシュを記録します。同じ初期状態・ルール・命令で結果を検証できます。保存／読込はアプリの保存領域に書き込みます。")
	column.add_child(_button("リプレイを書き出す", _export_replay))
	column.add_child(_button("保存したリプレイを再生・検証", _play_saved_replay))
	column.add_child(_button("JSONファイルを保存／取込（PC）", _show_file_dialog_choices))
	column.add_child(_button("マップ選択・新しいゲーム", _show_title))
	column.add_child(_button("閉じる", _close_modal))

func _replay_document() -> Dictionary:
	return {"format": 1, "ruleset_id": sim.rules.get("id", "playable_experimental"), "rng_state": "unused", "initial_snapshot": replay_initial, "initial_hash": sim.snapshot_state_hash(replay_initial), "commands": command_log, "checkpoints": checkpoints, "final_tick": int(sim.state.tick), "final_hash": sim.state_hash()}

func _export_replay() -> void:
	var file: FileAccess = FileAccess.open("user://crownfield_replay.json", FileAccess.WRITE)
	if file == null:
		_set_status("リプレイの保存に失敗しました。", true)
		return
	file.store_string(JSON.stringify(_replay_document(), "\t"))
	_close_modal()
	_set_status("リプレイJSONを保存しました。tick " + str(sim.state.tick) + " / " + str(command_log.size()) + "命令。")

func _play_saved_replay() -> void:
	if not FileAccess.file_exists("user://crownfield_replay.json"):
		_close_modal()
		_set_status("先にリプレイを書き出してください。", true)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://crownfield_replay.json"))
	_start_playback(data)

func _start_playback(data) -> void:
	if not data is Dictionary or not data.has("initial_snapshot") or not sim.restore(data.initial_snapshot):
		_close_modal()
		_set_status("リプレイを読み込めません。", true)
		return
	if sim.state_hash() != str(data.get("initial_hash", "")):
		_close_modal()
		_set_status("リプレイの初期状態ハッシュが一致しません。", true)
		return
	board.reset_motion()
	playback_data = data
	playback_index = 0
	replay_playback = true
	record_eligible = false
	pending.clear()
	selected.clear()
	active_order = ""
	end_shown = false
	paused = false
	accumulator = 0.0
	_close_modal()
	_set_status("リプレイ再生：チェックポイントと最終ハッシュを検証します。")
	_refresh()

func _show_file_dialog_choices() -> void:
	_close_modal()
	var column: VBoxContainer = _open_modal("JSONファイル")
	column.add_child(_button("リプレイJSONを書き出す", func(): _file_dialog(true, true)))
	column.add_child(_button("保存状態JSONを書き出す", func(): _file_dialog(true, false)))
	column.add_child(_button("リプレイ／保存状態JSONを取り込む", func(): _file_dialog(false, false)))
	column.add_child(_button("閉じる", _close_modal))

func _file_dialog(save: bool, replay: bool) -> void:
	_close_modal()
	paused = true
	if OS.has_feature("web"):
		if save:
			var document: Dictionary = _replay_document() if replay else {"format": 1, "run_id": run_id, "record_eligible": record_eligible and not replay_playback, "snapshot": sim.snapshot(), "pending": pending}
			JavaScriptBridge.download_buffer(JSON.stringify(document, "\t").to_utf8_buffer(), "crownfield_replay.json" if replay else "crownfield_save.json", "application/json")
			_set_status("JSONファイルをダウンロードしました。")
		else:
			web_file_callback = JavaScriptBridge.create_callback(_web_import_json)
			JavaScriptBridge.get_interface("window").crownfieldPickJSON(web_file_callback)
		return
	board.input_enabled = false
	var dialog: FileDialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; JSON"])
	dialog.current_file = "crownfield_replay.json" if replay else "crownfield_save.json"
	add_child(dialog)
	dialog.file_selected.connect(func(path):
		if save:
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(_replay_document() if replay else {"format": 1, "run_id": run_id, "record_eligible": record_eligible and not replay_playback, "snapshot": sim.snapshot()}, "\t"))
				_set_status("JSONファイルを書き出しました。")
			else:
				_set_status("ファイルを書き出せません。", true)
		else:
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary and data.has("initial_snapshot"):
				_start_playback(data)
			elif data is Dictionary and sim.restore(data.get("snapshot", data)):
				_new_recording(_run_id_from_save(data), data.get("record_eligible", true) == true)
				_record_clear()
				selected.clear()
				pending.clear()
				_refresh()
				_set_status("JSONから状態を読み込みました。")
			else:
				_set_status("互換性のあるJSONではありません。", true)
		board.input_enabled = true
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		board.input_enabled = true
		dialog.queue_free()
	)
	dialog.popup_centered_ratio(0.8)

func _web_import_json(arguments: Array) -> void:
	if arguments.is_empty(): return
	var data = JSON.parse_string(str(arguments[0]))
	if data is Dictionary and data.has("initial_snapshot"):
		_start_playback(data)
	elif data is Dictionary and sim.restore(data.get("snapshot", data)):
		_new_recording(_run_id_from_save(data), data.get("record_eligible", true) == true)
		_record_clear()
		pending = data.get("pending", [])
		selected.clear()
		active_order = ""
		paused = true
		_refresh()
		_set_status("JSONから状態を読み込みました。再開で続けられます。")
	else:
		_set_status("互換性のあるJSONではありません。", true)

func _tax_summary(forecast: Dictionary) -> String:
	return "税" + str(forecast.rate) + "%：税収 約+" + str(forecast.income) + "/" + str(int(forecast.tax_days)) + "日・村人口 +" + str(forecast.growth) + "/" + str(int(forecast.growth_days)) + "日"

func _show_tax() -> void:
	var column: VBoxContainer = _open_modal("税率・徴税の状況")
	var rate: int = int(tax_slider.value)
	var forecast: Dictionary = sim.economy_forecast(0, rate)
	_add_modal_text(column, _tax_summary(forecast) + "\n徴税路がつながる村：" + str(forecast.connected) + "/" + str(forecast.villages) + "\n次回徴税の目安：+" + str(forecast.next_income) + "（" + str(ceili(float(forecast.collection_ticks) / sim.rules.day_ticks)) + "日後）")
	if forecast.reason != "": _add_modal_text(column, forecast.reason)
	_add_modal_text(column, "税収は村の居住人口・税率・徴税できた時間から積算します。低税率は人口、高税率は資金を優先。王の外出や税路の断絶で新たな積算が止まります。表示は現在の人口・経路が続く場合の概算で、出兵・建設・軍の維持費は含みません。村人口は上限を超えると出兵します。0%にしても、それ以前に積算した税は徴収されます。")
	for value in [0, 5, 10, 15, 20, 25, 30]:
		column.add_child(_button(str(value) + "%", func():
			tax_slider.value = value
			_close_modal()
		))
	column.add_child(_button("閉じる", _close_modal))

func _open_modal(title: String) -> VBoxContainer:
	if is_instance_valid(modal):
		_close_modal()
	board.input_enabled = false
	board.animation_enabled = false
	board.clear_gestures()
	var overlay: Panel = Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_stylebox_override("panel", _style(Color(0.025, 0.055, 0.08, 0.96), Color("0b1520"), 0))
	add_child(overlay)
	modal = overlay
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	modal_panel = panel
	center.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	modal_scroll = scroll
	_modal_layout()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	var heading: Label = _label(title, 25)
	heading.add_theme_color_override("font_color", Color("f0d399"))
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	return column

func _modal_layout() -> void:
	if not is_instance_valid(modal_panel) or not is_instance_valid(modal_scroll): return
	# Centered reference frame leaves room on both sides even with a one-sided notch.
	modal_panel.custom_minimum_size.x = minf(640, size.x - 32 - 2*maxf(ui_inset.x,ui_inset.z))
	modal_scroll.custom_minimum_size.y = maxf(100, minf(size.y - 42 - 2*maxf(ui_inset.y,ui_inset.w),650))

func _add_modal_text(column: VBoxContainer, value: String) -> void:
	var label: Label = _label(value, 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)

func _close_modal() -> void:
	modal_panel = null
	modal_scroll = null
	title_art = null
	title_scroll = null
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal = null
	if is_instance_valid(board):
		board.input_enabled = true
		board.animation_enabled = not paused
	accumulator = 0.0

func _show_title() -> void:
	clear_records.load_records()
	paused = true
	_refresh()
	_close_modal()
	board.input_enabled = false
	board.animation_enabled = false
	board.clear_gestures()
	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_stylebox_override("panel", Field.box(Field.INK, Field.INK, 0, 0, 0))
	add_child(overlay)
	modal = overlay
	title_art = Control.new()
	title_art.clip_contents = true
	overlay.add_child(title_art)
	var picture := TextureRect.new()
	picture.texture = load("res://assets/title_chart.svg")
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_art.add_child(picture)
	var mast := PanelContainer.new()
	mast.add_theme_stylebox_override("panel", Field.box(Color("#112c30ec"),Color("#8c9a7c"),0,12,7))
	mast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	mast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	title_art.add_child(mast)
	var lockup := VBoxContainer.new()
	lockup.add_theme_constant_override("separation",2)
	mast.add_child(lockup)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/interface/wordmark.svg")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size.y = 27
	lockup.add_child(logo)
	var sub := _label("四 国 の 境 界",14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color",Field.MUTED)
	lockup.add_child(sub)
	title_scroll = ScrollContainer.new()
	title_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(title_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_scroll.add_child(center)
	title_content = VBoxContainer.new()
	title_content.add_theme_constant_override("separation", 7)
	center.add_child(title_content)
	var column := title_content
	var heading := _label("戦場を選択", 21)
	heading.add_theme_color_override("font_color", Field.GOLD)
	column.add_child(heading)
	selected_map_index = _map_index_from_state()
	map_selector = OptionButton.new()
	map_selector.custom_minimum_size.y = 42
	for entry in MAPS:
		map_selector.add_item(entry.name + ("  ✓" if clear_records.summary(entry.id).count > 0 else ""))
	map_selector.select(selected_map_index)
	map_selector.item_selected.connect(_on_map_selected)
	column.add_child(map_selector)
	map_description = _label(MAPS[selected_map_index].description, 14)
	map_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_description.add_theme_color_override("font_color", Field.MUTED)
	column.add_child(map_description)
	map_start_button = _button("このマップで開始", _start_selected_map)
	Field.icon_on(map_start_button, "flag")
	Field.gild(map_start_button)
	column.add_child(map_start_button)
	map_record_label = _label(clear_records.describe(MAPS[selected_map_index].id), 13)
	map_record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_record_label.add_theme_color_override("font_color", Field.MUTED)
	column.add_child(map_record_label)
	var links := HBoxContainer.new()
	column.add_child(links)
	var records := _button("クリア記録", _show_clear_records)
	var help := _button("操作説明", _show_help)
	for pair in [[records,"record"],[help,"help"]]:
		Field.icon_on(pair[0],pair[1],15)
		pair[0].custom_minimum_size.y = 40
		links.add_child(pair[0])
	if FileAccess.file_exists("user://crownfield_save.json"):
		column.add_child(_button("保存したゲームを読込", func():
			if _load_game(): _close_modal()
		))
	if sim.state.tick > 0:
		column.add_child(_button("今の盤面へ戻る", _close_modal))
		_add_modal_text(column,"開始すると新しいゲームになります。")
	_title_layout()

func _title_layout() -> void:
	if not is_instance_valid(title_art): return
	var tall := size.y > size.x
	var frame := Rect2(Vector2(ui_inset.x,ui_inset.y),size - Vector2(ui_inset.x + ui_inset.z,ui_inset.y + ui_inset.w))
	var art_size := Vector2(frame.size.x, frame.size.y * 0.37) if tall else Vector2(floorf(frame.size.x * 0.43),frame.size.y)
	title_art.position = frame.position
	title_art.size = art_size
	var offset := Vector2(0,art_size.y) if tall else Vector2(art_size.x,0)
	title_scroll.position = frame.position + offset + Vector2(12,6)
	title_scroll.size = frame.size - offset - Vector2(24,12)
	title_content.custom_minimum_size.x = minf(415, maxf(100,title_scroll.size.x - 24))
	map_selector.get_popup().max_size = Vector2i(0, maxi(130,int(frame.size.y)-18))

func _map_index_from_state() -> int:
	for index in range(MAPS.size()):
		if MAPS[index].id == sim.state.get("id", ""): return index
	return 0

func _on_map_selected(index: int) -> void:
	if index < 0 or index >= MAPS.size(): return
	selected_map_index = index
	map_description.text = MAPS[index].description
	map_record_label.text = clear_records.describe(MAPS[index].id)

func _start_selected_map() -> void:
	if not _reset_game(MAPS[selected_map_index].path): return
	_enter_fullscreen()
	paused = false
	_refresh()

func _show_help() -> void:
	var column: VBoxContainer = _open_modal("操作と勝ち方")
	if Food.active(sim.state): _add_modal_text(column, "フーズパニック：赤いハンバーガー店があなたです。村→店舗、王→店長、兵→配達員、水面→線路、橋→踏切として表示します。線路は踏切がある場所だけ通れます。『新装開店』『出店オート』で店を増やそう。以下は共通ルールです。")
	_add_modal_text(column, "目標：600日以内に敵3国の王を倒す。自国の王が倒れると敗北です。\n\n移動：部隊をタップ → 地点をタップ。移動ボタンは不要。別の味方をタップすると選び直せます。\n\n下部：『初期』は新しく出兵する部隊の行動。『オート』は選択部隊のおまかせ、住居・橋・国境の柵の建設、敵村・敵側の橋・敵柵の破壊、開墾、洞窟封鎖を継続します。初期にも同じ継続命令を設定できます。対象や資金が足りなければ、その場で待機します。『単発』は移動・待機・建設・破壊・援軍・防衛です。待機は選ぶと即指示、ほかの単発命令は選んでから目的地をタップ。住居を増やすオートは攻撃へ切り替わりません。\n\n上部：▶／Ⅱで再開と停止。税率はスライダーで変更。低税率は人口、高税率は資金を重視します。☰に速度、全景、範囲選択、各国の状況、保存／読込、記録をまとめています。\n\nスマホ：横持ち・全画面でプレイ。1本指で地図をドラッグ、2本指でピンチ、長押しで詳細。左下の地図ボタンで全景と自陣を切り替え、小地図をタップして移動。範囲選択をONにすると1本指ドラッグで複数選択。ジェスチャの離指では移動しません。\n\nPC：左クリック選択、左ドラッグ範囲選択、Shift追加。右ドラッグでパン、ホイールでズーム。Space停止、F全景、Ctrl+A全軍、Ctrl+S保存。\n\n攻略：村で人口を増やして出兵し、援軍で兵を合流させる。自国の村で待機すると消耗を抑えられます。村は資金100で建設。王は城の防御が強く、遠征中は税収が止まります。王が敵王を倒すと残存資産を引き継ぎます。\n\n勝利するとクリア回数・最短日数・直近日時を自動保存します。☰→クリア記録で確認できます。記録はこの端末・ブラウザ内に保存され、ブラウザのサイトデータを消すと失われます。\n\n停止中にも命令を予約できます。保存・リプレイ・JSON→JSONファイルで進行を端末へバックアップできます。ブラウザとAPKは自動同期しません。\n\nフーズパニックの表示素材は参照画面を基に新規作成しています。原作の画像・音楽ファイルは同梱していません。戦闘・人口・経済・AIの数値は一部独自調整を含みます。")
	column.add_child(_button("閉じる", _close_modal))

func _run_id_from_save(data: Dictionary) -> String:
	if data.get("run_id") is String and not data.run_id.is_empty(): return data.run_id
	# Old saves have no session ID. Their replay origin identifies repeated loads.
	var origin: Dictionary = sim.replay_origin if not sim.replay_origin.is_empty() else sim.snapshot(false)
	return "legacy-" + sim.snapshot_state_hash(origin)

func _record_clear() -> void:
	var name_value: String = str(sim.state.get("id", ""))
	for entry in MAPS:
		if entry.id == name_value: name_value = entry.name; break
	var result: String = clear_records.record_victory(run_id, sim.state, sim.rules, name_value, replay_playback or not record_eligible)
	match result:
		"added": clear_status = "クリア記録を保存しました。"
		"duplicate":
			if clear_status.is_empty(): clear_status = "このゲームのクリアは記録済みです。"
		"error": clear_status = clear_records.last_error
		"ignored":
			if replay_playback or not record_eligible: clear_status = "リプレイ再生はクリア記録に加算しません。"

func _show_clear_records() -> void:
	clear_records.load_records()
	var column: VBoxContainer = _open_modal("クリア記録")
	_add_modal_text(column, "マップ別の勝利回数と最短日数。記録はこの端末・ブラウザに保存されます。リプレイ再生は含みません。")
	if not clear_records.last_error.is_empty(): _add_modal_text(column, clear_records.last_error)
	for entry in MAPS:
		_add_modal_text(column, entry.name + "\n" + clear_records.describe(entry.id))
	column.add_child(_button("マップを選ぶ", _show_title))
	column.add_child(_button("盤面に戻る", _close_modal))

func _show_outcome() -> void:
	var won: bool = str(sim.state.result) == "victory"
	var food: bool = Food.active(sim.state)
	_record_clear()
	var column: VBoxContainer = _open_modal(("VICTORY — ウィバーガーの勝利" if food else "VICTORY — 青国の勝利") if won else ("DEFEAT — 閉店" if food else "DEFEAT — 青国の敗北"))
	if won:
		_add_modal_text(column, clear_status + "\n" + clear_records.describe(str(sim.state.id)))
	_add_modal_text(column, "経過 tick：" + str(sim.state.tick) + "\n最終状態ハッシュ：\n" + sim.state_hash() + "\n\n成績（丸め方など暫定Cを含む）：\n" + JSON.stringify(sim.state.get("score", {}), "\t"))
	column.add_child(_button("リプレイを書き出す", _export_replay))
	column.add_child(_button("クリア記録を見る", _show_clear_records))
	column.add_child(_button("もう一度プレイ", _restart))
	column.add_child(_button("盤面を見る", _close_modal))
	_play_cue("victory" if won else "defeat")

func _reset_game(map_path: String) -> bool:
	if not sim.new_game(map_path):
		_set_status("マップを読み込めませんでした。", true)
		return false
	_close_modal()
	selected.clear()
	pending.clear()
	active_order = ""
	accumulator = 0.0
	paused = true
	_new_recording()
	board.set_state(sim.state)
	board.focus_home()
	_refresh()
	return true

func _restart() -> void:
	if not _reset_game(MAPS[_map_index_from_state()].path): return
	_show_title()

func _play_cue(name_value: String) -> void:
	var path: String = "res://assets/audio/" + name_value + ".wav"
	if ResourceLoader.exists(path):
		audio_player.stream = load(path)
		audio_player.volume_db = -15
		audio_player.play()
