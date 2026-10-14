extends Control
## UI host: wall-clock speed, input, presentation and file I/O never define rules.
const Simulation = preload("res://core/simulation.gd")
const Board = preload("res://ui/board.gd")
const COLORS = [Color("54b9f3"), Color("ee7771"), Color("e9b959"), Color("8bcfa6")]
const ORDERS = [
	["move", "移動", "選択した部隊を目的地へ移動。王に出せる行動命令は移動だけです。"],
	["wait", "待機", "現在地で停止。自国の村に待機すると自然減少を抑えられます。"],
	["auto", "オート", "開墾を優先し、村の建設・進軍を自動判断。判断の細部は暫定ルールです。"],
	["defend", "拠点防衛", "目的の自国拠点を防衛。"],
	["reinforce", "援軍", "目的地の味方へ合流。合流先の命令を維持します。"],
	["build_base", "村建設", "さら地に村を建設。資金100。人口移転量は暫定値です。"],
	["destroy_base", "村破壊", "目的地の村を破壊。"],
	["reclaim", "開墾", "荒れ地をさら地にします。"],
	["build_bridge", "橋建設", "水面に橋を架けます。新設は耐久1ごと資金30、修理は2。"],
	["destroy_bridge", "橋破壊", "橋を破壊して相手の進軍や税路を断ちます。"],
	["build_fence", "柵建設", "柵で進軍・税路を遮断。耐久4ごと資金1。"],
	["destroy_fence", "柵破壊", "目的地の柵を破壊。"],
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
var root_column: VBoxContainer
var header_grid: GridContainer
var faction_grid: GridContainer
var commands_grid: GridContainer
var bottom: PanelContainer
var status_label: Label
var selection_label: Label
var hint_label: Label
var clock_label: Label
var faction_labels: Array = []
var order_buttons: Dictionary = {}
var pause_button: Button
var speed_button: Button
var range_button: Button
var tax_button: Button
var initial_button: Button
var audio_player: AudioStreamPlayer
var _last_status_ms: int = 0
var _manual_status: String = ""
var _layout_busy: bool = false

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
	ui_theme.default_font_size = 16
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
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("0c1722")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	root_column = VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 7)
	margin.add_child(root_column)
	var title_row: HBoxContainer = HBoxContainer.new()
	root_column.add_child(title_row)
	var brand: Label = _label("CROWNFIELD", 23)
	brand.add_theme_color_override("font_color", Color("f0d399"))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(brand)
	clock_label = _label("四国の境界", 16)
	title_row.add_child(clock_label)
	header_grid = GridContainer.new()
	header_grid.columns = 8
	header_grid.add_theme_constant_override("h_separation", 6)
	root_column.add_child(header_grid)
	pause_button = _button("▶ 開始", _toggle_pause, "Space：一時停止／再開")
	header_grid.add_child(pause_button)
	speed_button = _button("速度 1×", _cycle_speed)
	header_grid.add_child(speed_button)
	header_grid.add_child(_button("全景", _fit_map, "F：全景を表示。ホイール／ピンチで拡縮。"))
	range_button = _button("範囲選択", _toggle_range, "スマホ：このモードで1本指ドラッグ。移動は2本指。")
	header_grid.add_child(range_button)
	header_grid.add_child(_button("保存", _save_game))
	header_grid.add_child(_button("読込", _load_game))
	header_grid.add_child(_button("記録", _show_files))
	header_grid.add_child(_button("説明", _show_help))
	faction_grid = GridContainer.new()
	faction_grid.columns = 4
	faction_grid.add_theme_constant_override("h_separation", 6)
	root_column.add_child(faction_grid)
	for i in 4:
		var card: PanelContainer = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color("182935"), COLORS[i].darkened(0.3), 8))
		faction_grid.add_child(card)
		var label: Label = _label("", 14)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(label)
		faction_labels.append(label)
	status_label = _label("", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 38
	root_column.add_child(status_label)
	board = Board.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(0, 80)
	board.cell_tapped.connect(_on_cell_tapped)
	board.range_selected.connect(_on_range_selected)
	board.cancel_requested.connect(_cancel_order)
	board.inspect_requested.connect(_inspect_cell)
	board.path_provider = Callable(sim, "path_preview")
	root_column.add_child(board)
	bottom = PanelContainer.new()
	root_column.add_child(bottom)
	var bottom_column: VBoxContainer = VBoxContainer.new()
	bottom_column.add_theme_constant_override("separation", 6)
	bottom.add_child(bottom_column)
	var selection_row: HBoxContainer = HBoxContainer.new()
	bottom_column.add_child(selection_row)
	selection_label = _label("部隊を選択してください", 16)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_row.add_child(selection_label)
	selection_row.add_child(_button("全部隊", _select_all, "青国の王を除く全部隊を選択。"))
	selection_row.add_child(_button("解除", _clear_selection))
	var economy_row: HBoxContainer = HBoxContainer.new()
	bottom_column.add_child(economy_row)
	tax_button = _button("税率 10%", _show_tax, "王が城中央にいて、自国村への通路が接続していると徴税できます。")
	economy_row.add_child(tax_button)
	initial_button = _button("出兵時：オート", _show_initial_order)
	economy_row.add_child(initial_button)
	economy_row.add_child(_button("命令取消", _cancel_order))
	commands_grid = GridContainer.new()
	commands_grid.columns = 7
	commands_grid.add_theme_constant_override("h_separation", 5)
	commands_grid.add_theme_constant_override("v_separation", 5)
	bottom_column.add_child(commands_grid)
	for entry in ORDERS:
		var action: String = entry[0]
		var button: Button = _button(entry[1], func(): _choose_order(action), entry[2])
		commands_grid.add_child(button)
		order_buttons[action] = button
	hint_label = _label("部隊 → 命令 → 目的地。王の遠征中は税収が止まります。", 13)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_column.add_child(hint_label)

func _adaptive_layout() -> void:
	if _layout_busy:
		return
	_layout_busy = true
	var viewport: Window = get_window()
	var real_size: Vector2i = viewport.size
	portrait = real_size.y > real_size.x
	var logical_width: int = 600 if portrait else clampi(real_size.x, 960, 1280)
	var logical_height: int = int(float(logical_width) * float(real_size.y) / maxf(1, real_size.x))
	viewport.content_scale_size = Vector2i(logical_width, logical_height)
	header_grid.columns = 3 if portrait else 8
	faction_grid.columns = 2 if portrait else 4
	commands_grid.columns = 3 if portrait else 7
	bottom.custom_minimum_size.y = 350 if portrait else 228
	_layout_busy = false

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
	pause_button.text = "▶ 再開" if paused else "Ⅱ 停止"
	speed_button.text = "速度 " + str(speed) + "×"
	var day_ticks: int = int(sim.rules.get("day_ticks", 2))
	var remaining: int = int(sim.state.get("remaining_days", int(sim.rules.get("limit_days", 3000)) - int(sim.state.tick) / maxi(1, day_ticks)))
	clock_label.text = "残り " + str(remaining) + "日  ·  " + str(sim.state.tick) + " tick"
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
	tax_button.text = "税率 " + str(sim.state.factions[0].tax) + "%"
	initial_button.text = "出兵時：" + _order_name(str(sim.state.factions[0].get("initial_order", "auto")))
	var valid_ids: Array = []
	var power: int = 0
	var king_selected: bool = false
	for id in selected:
		var entity: Dictionary = _actor(int(id))
		if not entity.is_empty():
			valid_ids.append(id)
			power += int(entity.power)
			king_selected = king_selected or entity.get("is_leader", false)
	selected = valid_ids
	selection_label.text = "部隊を選択してください" if selected.is_empty() else str(selected.size()) + "隊選択  ·  強さ " + str(power) + ("  王を含む" if king_selected else "")
	for action in order_buttons:
		order_buttons[action].disabled = replay_playback or selected.is_empty() or (king_selected and action != "move")
		order_buttons[action].add_theme_stylebox_override("normal", _style(Color("65745a") if active_order == action else Color("253543"), Color("ead291") if active_order == action else Color("4b6068"), 8))
	if Time.get_ticks_msec() - _last_status_ms > 7000 or _manual_status.is_empty():
		status_label.text = "実験用プロファイル C  ·  数値／AIは原作未同定  ·  " + ("リプレイ再生中" if replay_playback else "4国の王を倒し、領地を制圧")
		status_label.add_theme_color_override("font_color", Color("c0c6af"))

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
	if action == "wait" or action == "auto":
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
		pending.append(result.command)
		_set_status(_order_name(action) + "を予約。" + ("再開すると適用します。" if paused else "次のtickで適用します。"))
		_play_cue("command")
	else:
		_set_status("命令できません：" + str(result.get("reason", "不明な理由")), true)

func _set_status(value: String, error: bool = false) -> void:
	_manual_status = value
	_last_status_ms = Time.get_ticks_msec()
	if is_instance_valid(status_label):
		status_label.text = value
		status_label.add_theme_color_override("font_color", Color("ffb3a2") if error else Color("f4dea3"))

func _order_name(action: String) -> String:
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
	range_button.text = "範囲：ON" if board.range_mode else "範囲選択"
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

func _load_game() -> void:
	if not FileAccess.file_exists("user://crownfield_save.json"):
		_set_status("保存データがありません。", true)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://crownfield_save.json"))
	if not data is Dictionary or not sim.restore(data.get("snapshot", {})):
		_set_status("保存データが壊れているか、互換性がありません。", true)
		return
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

func _show_files() -> void:
	var column: VBoxContainer = _open_modal("保存・リプレイ")
	_add_modal_text(column, "命令列と状態ハッシュを記録します。同じ初期状態・ルール・命令で結果を検証できます。保存／読込はアプリの保存領域に書き込みます。")
	column.add_child(_button("リプレイを書き出す", _export_replay))
	column.add_child(_button("保存したリプレイを再生・検証", _play_saved_replay))
	column.add_child(_button("JSONファイルを保存／取込（PC）", _show_file_dialog_choices))
	column.add_child(_button("新しいゲーム", _restart))
	column.add_child(_button("閉じる", _close_modal))

func _replay_document() -> Dictionary:
	return {"format": 1, "ruleset_id": sim.rules.get("id", "playable_experimental"), "rng_state": "unused", "initial_snapshot": replay_initial, "initial_hash": sim.snapshot_hash(replay_initial), "commands": command_log, "checkpoints": checkpoints, "final_tick": int(sim.state.tick), "final_hash": sim.state_hash()}

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

func _show_tax() -> void:
	var column: VBoxContainer = _open_modal("税率を変更")
	_add_modal_text(column, "低税率では人口増加を優先。高税率では資金を確保。王が城中央を離れたり、税路が途切れると収入が止まります。税率の範囲・収入額は実験用Cです。")
	for rate in [0, 5, 10, 15, 20, 25, 30]:
		column.add_child(_button(str(rate) + "%", func():
			_submit("tax", [], -1, {"team": 0, "rate": rate})
			_close_modal()
		))
	column.add_child(_button("閉じる", _close_modal))

func _show_initial_order() -> void:
	var column: VBoxContainer = _open_modal("出兵直後の行動")
	_add_modal_text(column, "村から新しく出た部隊へ自動的に与える行動です。")
	for action in ["auto", "wait"]:
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
	panel.custom_minimum_size = Vector2(550 if portrait else 690, 0)
	center.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(size.y - 60, 650))
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
	var column: VBoxContainer = _open_modal("CROWNFIELD  /  四国の境界")
	if ResourceLoader.exists("res://assets/title_landscape.svg"):
		var illustration: TextureRect = TextureRect.new()
		illustration.texture = load("res://assets/title_landscape.svg")
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		illustration.custom_minimum_size.y = 170
		column.add_child(illustration)
	_add_modal_text(column, "小さな村を育て、部隊を集め、四国の境界を越える。青国を指揮し、敵の3人の王を倒してください。\n\nWindows Onlineを研究基準とするクリーンルーム実装です。公式確定Aと独自補完Cを分離し、戦闘・人口・税収・AIの未同定部分には明示的な暫定数値を使用しています。原作完全一致を示すものではありません。")
	column.add_child(_button("実験用ルールでプレイ", func():
		_close_modal()
		paused = false
		_refresh()
	))
	column.add_child(_button("操作・勝ち方を見る", _show_help))

func _show_help() -> void:
	var column: VBoxContainer = _open_modal("操作と勝ち方")
	_add_modal_text(column, "目標：制限日数内に他の3国の王を倒す。青国の王が倒れると敗北。\n\n①村と部隊を観察。村人口の限界は（周囲の領地数＋1）×16。領地を広げ、拡張不能になると部隊が出ます。\n②部隊を選択 → 下部の命令 → 目的地。『オート』で開墾・村建設・進軍を任せられます。援軍で兵力を集め、前線の村で消耗を抑えてください。\n③資金100で村を建設。橋や柵に資金を使い、交通と税路を作ります。低税率は人口、高税率は資金を重視します。\n④王は城で防御が強く、遠征中は税収が止まります。王が敵王を倒すと敵国の残存資産を接収。王へは移動だけ命令できます。\n\nPC：左クリック選択。左ドラッグ範囲選択。Shiftで追加。右ドラッグでパン、右クリックで命令取消。ホイールでズーム。Spaceで停止、Fで全景。\n\nスマホ：タップで選択・目的地。長押しで詳細。2本指パン／ピンチは命令指定を取り消します。『範囲選択』ONで1本指ドラッグ選択。ジェスチャ後の離指では命令しません。\n\n一時停止中にも命令を予約でき、再開後に適用します。保存・読込・JSONリプレイを利用できます。\n\n研究上の注意：時間周期、戦闘式、成長・徴税・維持費の量、AI判断値は暫定C。原作の画像・音楽・マップは同梱していません。Android端末での操作確認は納品レポートを参照してください。")
	column.add_child(_button("閉じる", _close_modal))

func _show_outcome() -> void:
	var won: bool = str(sim.state.result) == "victory"
	var column: VBoxContainer = _open_modal("VICTORY — 青国の勝利" if won else "DEFEAT — 青国の敗北")
	_add_modal_text(column, "経過 tick：" + str(sim.state.tick) + "\n最終状態ハッシュ：\n" + sim.state_hash() + "\n\n成績（丸め方など暫定Cを含む）：\n" + JSON.stringify(sim.state.get("score", {}), "\t"))
	column.add_child(_button("リプレイを書き出す", _export_replay))
	column.add_child(_button("もう一度プレイ", _restart))
	column.add_child(_button("盤面を見る", _close_modal))
	_play_cue("victory" if won else "defeat")

func _restart() -> void:
	_close_modal()
	sim.new_game()
	selected.clear()
	pending.clear()
	active_order = ""
	accumulator = 0.0
	paused = true
	_new_recording()
	board.fit_map()
	_refresh()
	_show_title()

func _play_cue(name_value: String) -> void:
	var path: String = "res://assets/audio/" + name_value + ".wav"
	if ResourceLoader.exists(path):
		audio_player.stream = load(path)
		audio_player.volume_db = -15
		audio_player.play()
