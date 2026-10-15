extends Control
## UI host: wall-clock speed, input, presentation and file I/O never define rules.
const Simulation = preload("res://core/simulation.gd")
const Board = preload("res://ui/board.gd")
const COLORS = [Color("54b9f3"), Color("ee7771"), Color("e9b959"), Color("8bcfa6")]
const MAPS = [
	{"id": "four_rivers", "path": "res://data/maps/four_rivers.json", "name": "四つの川", "description": "従来のマップ。四方の川と橋を巡って争う標準面。"},
	{"id": "open_plains", "path": "res://data/maps/open_plains.json", "name": "開けた野", "description": "入門向け。広い平地で村を増やし、兵を集める基本を学ぶ。"},
	{"id": "twin_crossings", "path": "res://data/maps/twin_crossings.json", "name": "二つの渡し", "description": "橋の防衛と迂回を楽しむ面。各方面の複数の渡しを使おう。"},
	{"id": "borderlands", "path": "res://data/maps/borderlands.json", "name": "境界の半島", "description": "標準向け。半島の内政地を育て、中央の争奪地へ進もう。"},
	{"id": "succession_isthmus", "path": "res://data/maps/succession_isthmus.json", "name": "継承の地峡", "description": "既設橋と地峡で攻防。南の桟橋へ架橋すれば、海の向こうの国にも進める。"},
	{"id": "half_sea", "path": "res://data/maps/half_sea.json", "name": "片海", "description": "海で東西に分かれた戦場。各地峡を守り、北の桟橋から海を越えよう。"},
	{"id": "spiral_channel", "path": "res://data/maps/spiral_channel.json", "name": "渦の水路", "description": "4国が水路で隔てられた面。敵も架橋するので、内政と渡河のタイミングが重要。"}
]
const ORDERS = [
	["move", "移動", "選択した部隊を目的地へ移動。王に出せる行動命令は移動だけです。"],
	["wait", "待機", "現在地で停止。自国の村に待機すると自然減少を抑えられます。"],
	["auto", "オート", "住居建設を優先。戦力を集め、城の防御も含めて十分有利なときに攻撃します。"],
	["develop", "住居オート", "住居を繰り返し建設。必要な開墾も行い、兵力や資金が足りないときは自国の村で待機します。攻撃は行いません。"],
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
var order_buttons: Dictionary = {}
var pause_button: Button
var audio_player: AudioStreamPlayer
var _last_status_ms: int = 0
var _manual_status: String = ""
var top_bar: PanelContainer
var menu_button: MenuButton
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
var map_description: Label
var map_start_button: Button

func _ready() -> void:
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
	var ui_theme: Theme = Theme.new()
	if ResourceLoader.exists("res://assets/fonts/ja.ttf"):
		ui_theme.default_font = load("res://assets/fonts/ja.ttf")
	ui_theme.default_font_size = 14
	ui_theme.set_color("font_color", "Label", Color("e7ecea"))
	ui_theme.set_color("font_color", "Button", Color("e7ecea"))
	ui_theme.set_color("font_hover_color", "Button", Color("fff4c9"))
	ui_theme.set_stylebox("normal", "Button", _style(Color("253543"), Color("4b6068"), 8))
	ui_theme.set_stylebox("hover", "Button", _style(Color("344b58"), Color("b0ba98"), 8))
	ui_theme.set_stylebox("pressed", "Button", _style(Color("65745a"), Color("ead291"), 8))
	ui_theme.set_stylebox("disabled", "Button", _style(Color("1b2833"), Color("34434b"), 8))
	ui_theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), Color("f2d88e"), 8))
	ui_theme.set_stylebox("panel", "PanelContainer", _style(Color("15232f"), Color("3c4b52"), 10))
	theme = ui_theme

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
	row.add_theme_constant_override("separation", 8)
	top_bar.add_child(row)
	menu_button = MenuButton.new()
	menu_button.text = "☰"
	menu_button.custom_minimum_size = Vector2(44, 42)
	menu_button.tooltip_text = "ゲームメニュー"
	row.add_child(menu_button)
	var menu: PopupMenu = menu_button.get_popup()
	menu.add_item("速度 1×", 0)
	menu.add_item("地図を全景表示", 1)
	menu.add_check_item("範囲選択", 2)
	menu.add_item("全画面表示／解除", 3)
	menu.add_separator()
	menu.add_item("各国の状況", 4)
	menu.add_item("出兵時の行動", 5)
	menu.add_separator()
	menu.add_item("保存", 6)
	menu.add_item("読込", 7)
	menu.add_item("記録・JSON", 8)
	menu.add_item("操作と説明", 9)
	menu.add_separator()
	menu.add_item("マップ選択・新しいゲーム", 10)
	menu.id_pressed.connect(_on_game_menu)
	pause_button = _compact_button("▶", _toggle_pause, "再開／一時停止：ワンタッチ")
	pause_button.custom_minimum_size.x = 48
	row.add_child(pause_button)
	resource_label = _label("", 14)
	resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_label.clip_text = true
	resource_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(resource_label)
	clock_label = _label("", 14)
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
	status_label.hide()
	add_child(status_label)
	bottom = PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _hud_style())
	add_child(bottom)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	bottom.add_child(actions)
	selection_label = _label("部隊をタップ → 地点で移動", 14)
	selection_label.custom_minimum_size.x = 130
	selection_label.clip_text = true
	selection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	actions.add_child(selection_label)
	actions.add_child(_compact_button("全軍", _select_all, "青国の全部隊を選択。王は個別に選択します。"))
	command_cluster = HBoxContainer.new()
	command_cluster.add_theme_constant_override("separation", 6)
	actions.add_child(command_cluster)
	for action in ["wait", "auto", "develop"]:
		var label: String = "住居オート" if action == "develop" else _order_name(action)
		var button: Button = _compact_button(label, func(): _choose_order(action))
		command_cluster.add_child(button)
		order_buttons[action] = button
	command_menu = MenuButton.new()
	command_menu.text = "建設・命令 ▾"
	command_menu.custom_minimum_size = Vector2(116, 42)
	command_cluster.add_child(command_menu)
	var orders_popup: PopupMenu = command_menu.get_popup()
	for entry in ORDERS:
		if entry[0] in ["move", "wait", "auto", "develop"]: continue
		if entry[0] == "defend": orders_popup.add_separator("部隊")
		if entry[0] == "build_base": orders_popup.add_separator("住居・地形")
		if entry[0] == "build_bridge": orders_popup.add_separator("橋・柵")
		var id: int = order_menu_actions.size()
		order_menu_actions[id] = entry[0]
		orders_popup.add_item(entry[1], id)
	orders_popup.add_separator()
	orders_popup.add_item("移動に戻す／命令取消", 99)
	orders_popup.id_pressed.connect(_on_order_menu)
	clear_button = _compact_button("✕", _clear_selection, "選択と目的地指定を解除")
	actions.add_child(clear_button)
	bottom.resized.connect(_position_hud)

func _hud_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _style(Color(0.05, 0.09, 0.13, 0.94), Color("3c5662"), 10)
	style.content_margin_left = 8; style.content_margin_right = 8
	style.content_margin_top = 5; style.content_margin_bottom = 5
	return style

func _compact_button(value: String, callback: Callable, tip: String = "") -> Button:
	var button: Button = _button(value, callback, tip)
	button.custom_minimum_size = Vector2(42, 42)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button

func _adaptive_layout() -> void:
	# Keep the project reference size fixed. EXPAND handles rotation with uniform
	# scaling; changing content_scale_size in size_changed can race a Web resize.
	var logical_size: Vector2 = get_viewport_rect().size
	portrait = logical_size.y > logical_size.x
	menu_button.get_popup().max_size = Vector2i(0, maxi(160, int(logical_size.y) - 24))
	command_menu.get_popup().max_size = menu_button.get_popup().max_size
	tax_slider.custom_minimum_size.x = 100 if logical_size.x < 850 else 120
	call_deferred("_position_hud")

func _position_hud() -> void:
	if not is_instance_valid(bottom): return
	var minimum: Vector2 = bottom.get_combined_minimum_size()
	bottom.size = minimum
	bottom.position = Vector2(maxf(8, (size.x - minimum.x) * 0.5), maxf(68, size.y - minimum.y - 8))
	status_label.position = Vector2(16, bottom.position.y - 28)
	status_label.size = Vector2(maxf(0, size.x - 32), 24)
	board.view_padding = Vector4(8, 68, 8, minimum.y + 20)

func _on_game_menu(id: int) -> void:
	match id:
		0: _cycle_speed()
		1: _fit_map()
		2: _toggle_range()
		3: _toggle_fullscreen()
		4: _show_nations()
		5: _show_initial_order()
		6: _save_game()
		7: _load_game()
		8: _show_files()
		9: _show_help()
		10: _show_title()

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

func _show_nations() -> void:
	var column: VBoxContainer = _open_modal("各国の状況")
	for i in 4:
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color("182935"), COLORS[i].darkened(0.3), 8))
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
	accumulator += delta * float(speed)
	var count: int = 0
	while accumulator >= 0.2 and count < 20:
		accumulator -= 0.2
		_step_game()
		count += 1
		if paused or str(sim.state.get("result", "playing")) != "playing":
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
	board.set_state(sim.state)
	pause_button.text = "▶" if paused else "Ⅱ"
	pause_button.tooltip_text = "再開" if paused else "一時停止"
	menu_button.get_popup().set_item_text(0, "速度 " + str(speed) + "×")
	menu_button.get_popup().set_item_checked(2, board.range_mode)
	var day_ticks: int = int(sim.rules.get("day_ticks", 2))
	var remaining: int = int(sim.state.get("remaining_days", int(sim.rules.get("limit_days", 3000)) - int(sim.state.tick) / maxi(1, day_ticks)))
	clock_label.text = str(remaining) + "日"
	resource_label.text = "資金 " + str(sim.state.factions[0].funds) + "  ·  人口 " + str(sim.population(0))
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
		faction_labels[i].text = ("● " if bool(faction.alive) else "× ") + str(faction.name) + ("  [あなた]" if i == 0 else "") + "\n資金 " + str(faction.funds) + "  ·  人口 " + str(population) + "  ·  部隊 " + str(units)
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
	selection_label.text = "部隊をタップ → 地点で移動" if selected.is_empty() else str(selected.size()) + "隊 · " + str(power) + (" 王" if king_selected else "")
	if developers > 0: selection_label.text += " · 住居"
	command_cluster.visible = not selected.is_empty()
	clear_button.visible = not selected.is_empty()
	command_menu.text = (_order_name(active_order) + " ▾") if not active_order.is_empty() else "建設・命令 ▾"
	for action in order_buttons:
		order_buttons[action].disabled = replay_playback or selected.is_empty() or (king_selected and action != "wait")
		var highlighted: bool = active_order == action or (action == "develop" and developers == selected.size() and developers > 0)
		order_buttons[action].add_theme_stylebox_override("normal", _style(Color("65745a") if highlighted else Color("253543"), Color("ead291") if highlighted else Color("4b6068"), 8))
	command_menu.disabled = replay_playback or selected.is_empty() or king_selected
	status_label.visible = not _manual_status.is_empty() and Time.get_ticks_msec() - _last_status_ms < 5000
	if portrait:
		status_label.text = "スマホを横向きにすると、盤面を広く使えます"
		status_label.show()
	call_deferred("_position_hud")

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
	if action in ["wait", "auto", "develop"]:
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
	var info: String = ["さら地", "荒れ地", "水面", "洞窟"][clampi(terrain, 0, 3)]
	for base in sim.state.bases:
		if int(base.pos) == cell:
			info += "  ·  村人口 " + str(base.pop)
	for unit in sim.state.units:
		if int(unit.pos) == cell:
			info += "  ·  強さ " + str(unit.power) + " / " + _order_name(str(unit.order))
	for leader in sim.state.leaders:
		if int(leader.pos) == cell and bool(leader.get("alive", true)):
			info += "  ·  王の強さ " + str(leader.power)
	if int(data.get("bridge", 0)) > 0:
		info += "  ·  橋耐久 " + str(data.bridge)
	if int(data.get("fence", 0)) > 0:
		info += "  ·  柵耐久 " + str(data.fence)
	_set_status("(" + str(cell % int(sim.state.w)) + ", " + str(cell / int(sim.state.w)) + ")  " + info)

func _new_recording() -> void:
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
	file.store_string(JSON.stringify({"format": 1, "snapshot": sim.snapshot(), "pending": pending, "replay_initial": replay_initial, "commands": command_log, "checkpoints": checkpoints}, "\t"))
	_set_status("ゲームを保存しました。読込でこの状態へ戻れます。")

func _load_game() -> bool:
	if not FileAccess.file_exists("user://crownfield_save.json"):
		_set_status("保存データがありません。", true)
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://crownfield_save.json"))
	if not data is Dictionary or not sim.restore(data.get("snapshot", {})):
		_set_status("保存データが壊れているか、互換性がありません。", true)
		return false
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
	_set_status("保存状態を読み込みました。再開で時間が進みます。")
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
	playback_data = data
	playback_index = 0
	replay_playback = true
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
			var document: Dictionary = _replay_document() if replay else {"format": 1, "snapshot": sim.snapshot(), "pending": pending}
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
				file.store_string(JSON.stringify(_replay_document() if replay else {"format": 1, "snapshot": sim.snapshot()}, "\t"))
				_set_status("JSONファイルを書き出しました。")
			else:
				_set_status("ファイルを書き出せません。", true)
		else:
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary and data.has("initial_snapshot"):
				_start_playback(data)
			elif data is Dictionary and sim.restore(data.get("snapshot", data)):
				_new_recording()
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
		_new_recording()
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

func _show_initial_order() -> void:
	var column: VBoxContainer = _open_modal("出兵直後の行動")
	_add_modal_text(column, "村から新しく出た部隊へ自動的に与える行動です。")
	for action in ["auto", "develop", "wait"]:
		column.add_child(_button(_order_name(action), func():
			_submit("initial_order", [], -1, {"team": 0, "order": action})
			_close_modal()
		))
	column.add_child(_button("閉じる", _close_modal))

func _open_modal(title: String) -> VBoxContainer:
	if is_instance_valid(modal):
		_close_modal()
	board.input_enabled = false
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
	panel.custom_minimum_size = Vector2(minf(size.x - 32, 640), 0)
	center.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, maxf(120, minf(size.y - 32, 650)))
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

func _add_modal_text(column: VBoxContainer, value: String) -> void:
	var label: Label = _label(value, 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal = null
	if is_instance_valid(board):
		board.input_enabled = true
	accumulator = 0.0

func _show_title() -> void:
	paused = true
	_refresh()
	var column: VBoxContainer = _open_modal("CROWNFIELD  /  四国の境界")
	column.add_theme_constant_override("separation", 8)
	if size.y >= 480 and ResourceLoader.exists("res://assets/title_landscape.svg"):
		var illustration: TextureRect = TextureRect.new()
		illustration.texture = load("res://assets/title_landscape.svg")
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		illustration.custom_minimum_size.y = 100
		column.add_child(illustration)
	_add_modal_text(column, "村を育て、兵を集め、敵3国の王を倒そう。")
	selected_map_index = _map_index_from_state()
	map_selector = OptionButton.new()
	map_selector.custom_minimum_size.y = 48
	map_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in MAPS: map_selector.add_item(entry.name)
	map_selector.select(selected_map_index)
	map_selector.item_selected.connect(_on_map_selected)
	column.add_child(map_selector)
	map_description = _label(MAPS[selected_map_index].description, 16)
	map_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(map_description)
	map_start_button = _button("このマップで開始", _start_selected_map)
	column.add_child(map_start_button)
	if FileAccess.file_exists("user://crownfield_save.json"):
		column.add_child(_button("保存したゲームを読込", func():
			if _load_game(): _close_modal()
		))
	if sim.state.tick > 0:
		_add_modal_text(column, "開始すると新しいゲームになります。現在の進行を残すには、盤面に戻って保存してください。")
		column.add_child(_button("今の盤面へ戻る", _close_modal))
	column.add_child(_button("操作・勝ち方を見る", _show_help))

func _map_index_from_state() -> int:
	for index in range(MAPS.size()):
		if MAPS[index].id == sim.state.get("id", ""): return index
	return 0

func _on_map_selected(index: int) -> void:
	if index < 0 or index >= MAPS.size(): return
	selected_map_index = index
	map_description.text = MAPS[index].description

func _start_selected_map() -> void:
	if not _reset_game(MAPS[selected_map_index].path): return
	_enter_fullscreen()
	paused = false
	_refresh()

func _show_help() -> void:
	var column: VBoxContainer = _open_modal("操作と勝ち方")
	_add_modal_text(column, "目標：600日以内に敵3国の王を倒す。自国の王が倒れると敗北です。\n\n移動：部隊をタップ → 地点をタップ。移動ボタンは不要。別の味方をタップすると選び直せます。\n\n下部：待機／オート／住居オート。建設・破壊・援軍・防衛は『建設・命令』から選び、その後に目的地をタップします。住居オートは村を増やし続け、攻撃には切り替わりません。\n\n上部：▶／Ⅱで再開と停止。税率はスライダーで変更。低税率は人口、高税率は資金を重視します。☰に速度、全景、範囲選択、各国の状況、出兵時行動、保存／読込、記録をまとめています。\n\nスマホ：横持ち・全画面でプレイ。2本指でパン／ピンチ、長押しで詳細。範囲選択をONにすると1本指ドラッグで複数選択。ジェスチャの離指では移動しません。\n\nPC：左クリック選択、左ドラッグ範囲選択、Shift追加。右ドラッグでパン、ホイールでズーム。Space停止、F全景、Ctrl+A全軍、Ctrl+S保存。\n\n攻略：村で人口を増やして出兵し、援軍で兵を合流させる。自国の村で待機すると消耗を抑えられます。村は資金100で建設。王は城の防御が強く、遠征中は税収が止まります。王が敵王を倒すと残存資産を引き継ぎます。\n\n停止中にも命令を予約できます。記録→JSONファイルで保存データを端末へバックアップできます。ブラウザとAPKは自動同期しません。\n\n原作の画像・音楽・マップは使用していません。戦闘・人口・経済・AIの数値は一部独自調整を含みます。")
	column.add_child(_button("閉じる", _close_modal))

func _show_outcome() -> void:
	var won: bool = str(sim.state.result) == "victory"
	var column: VBoxContainer = _open_modal("VICTORY — 青国の勝利" if won else "DEFEAT — 青国の敗北")
	_add_modal_text(column, "経過 tick：" + str(sim.state.tick) + "\n最終状態ハッシュ：\n" + sim.state_hash() + "\n\n成績（丸め方など暫定Cを含む）：\n" + JSON.stringify(sim.state.get("score", {}), "\t"))
	column.add_child(_button("リプレイを書き出す", _export_replay))
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
	board.fit_map()
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
