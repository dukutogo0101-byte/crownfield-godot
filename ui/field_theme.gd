extends RefCounted
## Appearance only. All glyphs are drawn from the same high-resolution sheet.
const SHEET = preload("res://assets/interface/glyphs.svg")
const ICONS = ["menu","play","pause","flag","loop","cursor","crown","map","close","troops","coin","sun","down","record","help"]
const INK = Color("#102b30")
const PANEL = Color("#143337")
const EDGE = Color("#536c64")
const PAPER = Color("#faf1d8")
const MUTED = Color("#baccc1")
const GOLD = Color("#f2cb82")
static var _icons: Dictionary = {}

static func glyph(key: String) -> Texture2D:
	if not _icons.has(key):
		var tile := AtlasTexture.new()
		tile.atlas = SHEET
		tile.region = Rect2(ICONS.find(key) * 96, 0, 96, 96)
		tile.filter_clip = true
		_icons[key] = tile
	return _icons[key]

static func box(bg: Color, line: Color, r: int, mx: float = 10, my: float = 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = line
	s.set_border_width_all(1)
	s.set_corner_radius_all(r)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	return s

static func panel() -> StyleBoxFlat:
	var s := box(Color("#102c30fa"), Color("#667a6c"), 9, 5, 4)
	s.shadow_color = Color("#07161960")
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	return s

static func setup(font: Font) -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 15
	t.set_color("font_color", "Label", PAPER)
	for cls in ["Button","MenuButton","OptionButton"]:
		t.set_color("font_color", cls, PAPER)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_disabled_color", cls, Color("#9aaea4"))
		t.set_color("icon_normal_color", cls, GOLD)
		t.set_color("icon_disabled_color", cls, Color("#849b92"))
		t.set_constant("icon_max_width", cls, 18)
		t.set_constant("h_separation", cls, 5)
		t.set_stylebox("normal", cls, box(Color("#214447"), Color("#4c6862"), 6))
		t.set_stylebox("hover", cls, box(Color("#315552"), Color("#b6b591"), 6))
		t.set_stylebox("pressed", cls, box(Color("#3d5750"), GOLD, 6))
		t.set_stylebox("disabled", cls, box(Color("#1a3538"), Color("#344e4c"), 6))
		t.set_stylebox("focus", cls, box(Color.TRANSPARENT, GOLD, 6))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, EDGE, 9, 12, 9))
	t.set_stylebox("panel", "PopupMenu", box(INK, Color("#809280"), 8, 9, 5))
	t.set_stylebox("hover", "PopupMenu", box(Color("#34544c"), Color("#748877"), 4))
	t.set_color("font_color","PopupMenu",PAPER)
	t.set_color("font_separator_color","PopupMenu",GOLD)
	t.set_constant("v_separation","PopupMenu",10)
	t.set_stylebox("slider","HSlider",box(Color("#0a2023"),EDGE,2,1,2))
	t.set_stylebox("grabber_area","HSlider",box(Color("#d6b476"),Color("#d6b476"),2,1,2))
	t.set_stylebox("grabber_area_highlight","HSlider",t.get_stylebox("grabber_area","HSlider"))
	return t

static func icon_on(b: Button, key: String, width: int = 18) -> void:
	b.icon = glyph(key)
	b.add_theme_constant_override("icon_max_width", width)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

static func gild(b: Button) -> void:
	for state in ["normal","hover","pressed"]:
		var c: Color = {"normal": GOLD, "hover": Color("#ffe1a5"), "pressed": Color("#d7ad68")}[state]
		b.add_theme_stylebox_override(state, box(c, Color("#ffe3a8"), 6))
		b.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", INK)
		b.add_theme_color_override("icon_" + state + "_color", INK)
