extends Control
## Presentation only. All game state is supplied by the integer simulation.
signal cell_tapped(cell: int, additive: bool)
signal range_selected(cells: Array, additive: bool)
signal cancel_requested
signal inspect_requested(cell: int)

const COLORS = [Color("54b9f3"), Color("ee7771"), Color("e9b959"), Color("8bcfa6")]
const LAND = [Color("77946c"), Color("586f53"), Color("356782"), Color("4c5759")]
var state: Dictionary = {}
var selected: Array = []
var path_provider: Callable
var target_preview: int = -1
var range_mode: bool = false
var input_enabled: bool = true
var pixels_per_cell: float = 20.0
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var textures: Dictionary = {}
var font: Font
var touches: Dictionary = {}
var gesture_active: bool = false
var _touch_start: Vector2
var _touch_start_ms: int = 0
var _touch_moved: bool = false
var _long_press_fired: bool = false
var _left_down: bool = false
var _right_down: bool = false
var _press_position: Vector2
var _last_position: Vector2
var _drag_end: Vector2
var _dragging_range: bool = false
var _additive: bool = false
var _last_two_center: Vector2
var _last_two_distance: float = 0.0
var _minimap: Rect2 = Rect2()
var _fitted: bool = false
var view_padding: Vector4 = Vector4(8, 68, 8, 72)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/fonts/ja.ttf"):
		font = load("res://assets/fonts/ja.ttf")
	for kind in ["grass", "rough", "water", "cave"]:
		_load_texture(kind, "res://assets/terrain/" + kind + ".svg")
	for kind in ["castle", "village", "unit", "leader", "bridge", "fence"]:
		_load_texture(kind, "res://assets/entities/" + kind + ".svg")
	resized.connect(_resize_board)

func _load_texture(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		textures[key] = load(path)

func set_state(value: Dictionary) -> void:
	state = value
	if not _fitted and not state.is_empty() and size.x > 0:
		fit_map()
	queue_redraw()

func _resize_board() -> void:
	if not state.is_empty():
		fit_map()

func fit_map() -> void:
	if state.is_empty():
		return
	var usable: Vector2 = size - Vector2(view_padding.x + view_padding.z, view_padding.y + view_padding.w)
	pixels_per_cell = minf(usable.x / int(state.w), usable.y / int(state.h))
	pixels_per_cell = maxf(3.0, pixels_per_cell)
	zoom = 1.0
	pan = Vector2.ZERO
	_fitted = true
	queue_redraw()

func map_origin() -> Vector2:
	var usable: Vector2 = size - Vector2(view_padding.x + view_padding.z, view_padding.y + view_padding.w)
	return Vector2(view_padding.x, view_padding.y) + (usable - Vector2(int(state.get("w", 1)), int(state.get("h", 1))) * cell_size()) * 0.5 + pan

func cell_size() -> float:
	return pixels_per_cell * zoom

func cell_point(cell: int) -> Vector2:
	var width: int = int(state.get("w", 1))
	return map_origin() + Vector2(cell % width + 0.5, cell / width + 0.5) * cell_size()

func cell_at(point: Vector2) -> int:
	if state.is_empty():
		return -1
	var p: Vector2 = (point - map_origin()) / cell_size()
	var x: int = floori(p.x)
	var y: int = floori(p.y)
	if x < 0 or y < 0 or x >= int(state.w) or y >= int(state.h):
		return -1
	return y * int(state.w) + x

func zoom_at(factor: float, point: Vector2) -> void:
	if state.is_empty():
		return
	var old_origin: Vector2 = map_origin()
	var old_cell: float = cell_size()
	var world_point: Vector2 = (point - old_origin) / old_cell
	zoom = clampf(zoom * factor, 0.55, 6.0)
	pan += point - (map_origin() + world_point * cell_size())
	queue_redraw()

func clear_gestures() -> void:
	touches.clear()
	gesture_active = false
	_left_down = false
	_right_down = false
	_dragging_range = false
	queue_redraw()

func _process(_delta: float) -> void:
	if input_enabled and touches.size() == 1 and not gesture_active and not _touch_moved and not _long_press_fired and not range_mode:
		if Time.get_ticks_msec() - _touch_start_ms >= 550:
			_long_press_fired = true
			inspect_requested.emit(cell_at(_touch_start))

func _gui_input(event: InputEvent) -> void:
	if not input_enabled or state.is_empty():
		return
	if event is InputEventScreenTouch:
		_touch(event)
		accept_event()
	elif event is InputEventScreenDrag:
		_touch_drag(event)
		accept_event()
	elif event is InputEventMouseButton:
		if event.device == -1:
			return
		_mouse_button(event)
		accept_event()
	elif event is InputEventMouseMotion:
		if event.device == -1:
			return
		if _right_down:
			pan += event.position - _last_position
			_last_position = event.position
		elif _left_down:
			_drag_end = event.position
			_dragging_range = _press_position.distance_to(event.position) > 8.0
		else:
			target_preview = cell_at(event.position)
		queue_redraw()

func _mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_at(1.15, event.position)
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_at(1.0 / 1.15, event.position)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_right_down = event.pressed
		if event.pressed:
			_press_position = event.position
			_last_position = event.position
		elif _press_position.distance_to(event.position) < 8.0:
			cancel_requested.emit()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _minimap.has_point(event.position):
				var normalized: Vector2 = (event.position - _minimap.position) / _minimap.size
				var position: Vector2 = Vector2(normalized.x * int(state.w), normalized.y * int(state.h)) * cell_size()
				pan += size * 0.5 - (map_origin() + position)
				queue_redraw()
				return
			_left_down = true
			_press_position = event.position
			_drag_end = event.position
			_dragging_range = false
			_additive = event.shift_pressed
		else:
			if _left_down:
				if _dragging_range:
					_emit_range(_press_position, event.position, _additive)
				else:
					cell_tapped.emit(cell_at(event.position), event.shift_pressed)
			_left_down = false
			_dragging_range = false
	queue_redraw()

func _touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touches[event.index] = event.position
		if touches.size() == 1:
			_touch_start = event.position
			_touch_start_ms = Time.get_ticks_msec()
			_touch_moved = false
			_long_press_fired = false
			_press_position = event.position
			_drag_end = event.position
		elif touches.size() >= 2:
			gesture_active = true
			_dragging_range = false
			cancel_requested.emit()
			_update_two_reference()
	else:
		var was_gesture: bool = gesture_active
		if touches.has(event.index):
			touches.erase(event.index)
		if not was_gesture and not _long_press_fired:
			if range_mode and _touch_moved:
				_emit_range(_touch_start, event.position, false)
			elif not _touch_moved:
				cell_tapped.emit(cell_at(event.position), false)
		if touches.is_empty():
			gesture_active = false
			_dragging_range = false
		elif touches.size() >= 2:
			_update_two_reference()
	queue_redraw()

func _update_two_reference() -> void:
	if touches.size() < 2:
		return
	var values: Array = touches.values()
	_last_two_center = (values[0] + values[1]) * 0.5
	_last_two_distance = values[0].distance_to(values[1])

func _touch_drag(event: InputEventScreenDrag) -> void:
	if not touches.has(event.index):
		return
	touches[event.index] = event.position
	if touches.size() >= 2:
		var values: Array = touches.values()
		var center: Vector2 = (values[0] + values[1]) * 0.5
		var distance: float = values[0].distance_to(values[1])
		pan += center - _last_two_center
		if _last_two_distance > 1.0:
			zoom_at(distance / _last_two_distance, center)
		_last_two_center = center
		_last_two_distance = distance
	elif not gesture_active:
		_touch_moved = _touch_start.distance_to(event.position) > 10.0
		_drag_end = event.position
		_dragging_range = range_mode and _touch_moved
	queue_redraw()

func _emit_range(first: Vector2, last: Vector2, additive: bool) -> void:
	var rect: Rect2 = Rect2(first, last - first).abs()
	var result: Array = []
	for cell in int(state.w) * int(state.h):
		if rect.has_point(cell_point(cell)):
			result.append(cell)
	range_selected.emit(result, additive)

func _sprite(kind: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if textures.has(kind):
		draw_texture_rect(textures[kind], rect, false, tint)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101c29"))
	if state.is_empty():
		return
	var cs: float = cell_size()
	var origin: Vector2 = map_origin()
	var width: int = int(state.w)
	var world_rect: Rect2 = Rect2(origin, Vector2(width, int(state.h)) * cs)
	draw_rect(world_rect.grow(7), Color("080f18"))
	draw_rect(world_rect.grow(4), Color("394746"), false, 2)
	for cell in state.cells.size():
		var data: Dictionary = state.cells[cell]
		var terrain: int = int(data.get("terrain", 0))
		var owner: int = int(data.get("owner", -1))
		var rect: Rect2 = Rect2(origin + Vector2(cell % width, cell / width) * cs, Vector2(cs, cs))
		if not rect.intersects(Rect2(Vector2.ZERO, size)):
			continue
		draw_rect(rect, LAND[clampi(terrain, 0, 3)])
		_sprite(["grass", "rough", "water", "cave"][clampi(terrain, 0, 3)], rect)
		if owner >= 0 and owner < 4 and terrain != 2:
			draw_rect(rect, Color(COLORS[owner], 0.22))
			if cell % width == 0 or int(state.cells[cell - 1].get("owner", -1)) != owner:
				draw_line(rect.position, rect.position + Vector2(0, cs), Color(COLORS[owner], 0.7), 1.2)
			if cell < width or int(state.cells[cell - width].get("owner", -1)) != owner:
				draw_line(rect.position, rect.position + Vector2(cs, 0), Color(COLORS[owner], 0.7), 1.2)
		if int(data.get("bridge", 0)) > 0:
			_sprite("bridge", rect.grow(cs * 0.12))
		if int(data.get("fence", 0)) > 0:
			_sprite("fence", rect)
		if cs > 28:
			draw_rect(rect, Color(0, 0, 0, 0.08), false, 0.7)
	for base in state.bases:
		var team: int = int(base.team)
		var p: Vector2 = cell_point(int(base.pos))
		var rect: Rect2 = Rect2(p - Vector2(cs * 0.65, cs * 0.75), Vector2(cs * 1.3, cs * 1.3))
		_sprite("village", rect)
		_draw_flag(p + Vector2(cs * 0.3, -cs * 0.32), COLORS[team], cs)
		if cs >= 21:
			_text(str(int(base.pop)), p + Vector2(0, cs * 0.5), 11, Color("f3f1df"))
	for faction in state.factions:
		if not bool(faction.alive):
			continue
		var p: Vector2 = cell_point(int(faction.home))
		_sprite("castle", Rect2(p - Vector2(cs, cs * 1.25), Vector2(cs * 2, cs * 2)))
		_draw_flag(p + Vector2(cs * 0.15, -cs), COLORS[int(faction.id)], cs * 1.2)
	if path_provider.is_valid() and target_preview >= 0 and not selected.is_empty():
		var path: Array = path_provider.call(int(selected[0]), target_preview)
		if path.size() > 1:
			var points: PackedVector2Array = PackedVector2Array()
			for cell in path:
				points.append(cell_point(int(cell)))
			draw_polyline(points, Color(1, 0.91, 0.63, 0.8), 2.0)
			draw_circle(points[-1], 4.0, Color("f7dd91"))
	for unit in state.units:
		_draw_entity(unit, false, cs)
	for leader in state.leaders:
		if bool(leader.get("alive", true)):
			_draw_entity(leader, true, cs)
	if _dragging_range:
		var rect: Rect2 = Rect2(_press_position, _drag_end - _press_position).abs()
		draw_rect(rect, Color(0.44, 0.77, 0.95, 0.16))
		draw_rect(rect, Color("8bd6f6"), false, 1.5)
	_draw_minimap()

func _draw_entity(entity: Dictionary, leader: bool, cs: float) -> void:
	var team: int = int(entity.team)
	var p: Vector2 = cell_point(int(entity.pos))
	var power: int = int(entity.power)
	var radius: float = maxf(5.0, cs * 0.34)
	if selected.has(int(entity.id)):
		draw_arc(p, radius + 5, 0, TAU, 28, Color("fff0ac"), 2.0)
		draw_circle(p, radius + 3, Color(1, 0.94, 0.7, 0.14))
	draw_ellipse_shadow(p + Vector2(0, cs * 0.27), Vector2(radius, radius * 0.36))
	var extent: float = maxf(14.0, cs * (1.15 if leader else 0.95))
	_sprite("leader" if leader else "unit", Rect2(p - Vector2(extent * 0.5, extent * 0.65), Vector2(extent, extent)))
	_draw_flag(p + Vector2(extent * 0.24, -extent * 0.28), COLORS[team], maxf(cs * 0.8, 12.0))
	if cs >= 17 or selected.has(int(entity.id)):
		var text_value: String = str(power)
		if cs < 27 and power >= 1000:
			text_value = str(power / 1000) + "k"
		_text(text_value, p + Vector2(0, extent * 0.54), 11, Color("fff2d6"))
	if power >= 1000:
		var tier: String = "L" if power >= 10000 else "M"
		_text(tier, p + Vector2(-extent * 0.5, -extent * 0.35), 10, Color("fce39a"))

func draw_ellipse_shadow(center: Vector2, radii: Vector2) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in 16:
		var angle: float = TAU * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, Color(0.02, 0.04, 0.04, 0.34))

func _draw_flag(p: Vector2, color: Color, cs: float) -> void:
	var height: float = maxf(7.0, cs * 0.4)
	draw_line(p + Vector2(0, height * 0.6), p - Vector2(0, height), Color("e1d5a4"), 1.1)
	draw_colored_polygon(PackedVector2Array([p - Vector2(0, height), p + Vector2(height * 0.85, -height * 0.8), p + Vector2(0, -height * 0.3)]), color)

func _text(value: String, position: Vector2, font_size: int, color: Color) -> void:
	var offset: Vector2 = Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5, 0)
	draw_string_outline(font, position - offset, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color("15201e"))
	draw_string(font, position - offset, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_minimap() -> void:
	var width: float = minf(108, size.x * 0.18)
	var height: float = width * float(state.h) / float(state.w)
	_minimap = Rect2(Vector2(size.x - width - 12, size.y - height - view_padding.w - 8), Vector2(width, height))
	draw_rect(_minimap.grow(4), Color("101b25"))
	var mini_cell: Vector2 = _minimap.size / Vector2(int(state.w), int(state.h))
	for cell in state.cells.size():
		var data: Dictionary = state.cells[cell]
		var owner: int = int(data.get("owner", -1))
		var color: Color = LAND[clampi(int(data.get("terrain", 0)), 0, 3)]
		if owner >= 0 and owner < 4:
			color = COLORS[owner].darkened(0.2)
		draw_rect(Rect2(_minimap.position + Vector2(cell % int(state.w), cell / int(state.w)) * mini_cell, mini_cell + Vector2(0.1, 0.1)), color)
	for leader in state.leaders:
		if bool(leader.get("alive", true)):
			var p: Vector2 = _minimap.position + Vector2(int(leader.pos) % int(state.w) + 0.5, int(leader.pos) / int(state.w) + 0.5) * mini_cell
			draw_circle(p, 2.7, Color("ffffdc"))
	draw_rect(_minimap, Color("a1ad92"), false, 1)
