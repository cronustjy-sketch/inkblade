extends RefCounted

# Shared flat-cartoon UI pieces (thick black outlines, flat colours, round buttons) for the menu and story screens.

const InkFont := preload("res://scripts/inkfont.gd")
const OUTLINE := Color("0d0d12")
const GOLD := Color("f2b632")
const RED := Color("e0463b")
const CREAM := Color("fff3d1")
const NAVY := Color("1f2a4d")
const SKY := Color("9fd8ff")
const GREEN := Color("6cc070")
const GREY := Color("8c93a3")

static func flat(bg: Color, border: Color = OUTLINE, border_w: int = 5, radius: int = 24, margin: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s

static func label(text: String, size: int, color: Color = Color.WHITE, outline: int = 0, ink_font: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", OUTLINE)
		l.add_theme_constant_override("outline_size", outline)
	if ink_font:
		InkFont.apply(l)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# A two-line label: Chinese on top, English underneath.
static func bilingual(cn: String, en: String, cn_size: int, en_size: int, cn_color: Color = Color.WHITE, en_color: Color = Color("c9d4e8"), outline: int = 4, ink_font: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a: Label = label(cn, cn_size, cn_color, outline, ink_font)
	a.horizontal_alignment = align
	box.add_child(a)
	var b: Label = label(en, en_size, en_color, maxi(outline - 1, 0))
	b.horizontal_alignment = align
	box.add_child(b)
	return box

# Pill button with a bilingual caption.
static func pill(cn: String, en: String, fill: Color, min_size: Vector2, action: Callable, cn_size: int = 22) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	var r: int = int(min_size.y * 0.5)
	b.add_theme_stylebox_override("normal", flat(fill, OUTLINE, 5, r))
	b.add_theme_stylebox_override("hover", flat(fill.lightened(0.25), OUTLINE, 5, r))
	b.add_theme_stylebox_override("pressed", flat(fill.darkened(0.15), OUTLINE, 5, r))
	b.add_theme_stylebox_override("disabled", flat(fill.darkened(0.3), Color(OUTLINE, 0.6), 5, r))
	var caption := VBoxContainer.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.alignment = BoxContainer.ALIGNMENT_CENTER
	caption.add_theme_constant_override("separation", -3)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a: Label = label(cn, cn_size, OUTLINE)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_child(a)
	if en != "":
		var e: Label = label(en, int(cn_size * 0.55), Color(OUTLINE, 0.8))
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_child(e)
	b.add_child(caption)
	b.pressed.connect(action)
	return b

# Round button with a big glyph and a bilingual caption underneath. Returns the column container; the button is child 0.
static func round_tile(glyph: String, cn: String, en: String, fill: Color, diameter: float, action: Callable) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(diameter, diameter)
	var r: int = int(diameter * 0.5)
	b.add_theme_stylebox_override("normal", flat(fill, OUTLINE, 5, r))
	b.add_theme_stylebox_override("hover", flat(fill.lightened(0.25), OUTLINE, 5, r))
	b.add_theme_stylebox_override("pressed", flat(fill.darkened(0.15), OUTLINE, 5, r))
	var g: Label = label(glyph, int(diameter * 0.46), Color.WHITE, 6, true)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(g)
	b.pressed.connect(action)
	col.add_child(b)
	col.add_child(bilingual(cn, en, 15, 11, Color.WHITE, Color("dfe8f8"), 4))
	return col

# Modal panel with a message and an OK button; added to `parent` and removed on close.
static func message_box(parent: Control, cn_title: String, en_title: String, cn: String, en: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", flat(CREAM, OUTLINE, 6, 28, 26))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(bilingual(cn_title, en_title, 34, 16, GOLD, NAVY, 6, true))
	var a: Label = label(cn, 18, NAVY)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	a.custom_minimum_size = Vector2(420, 0)
	box.add_child(a)
	var e: Label = label(en, 14, Color("4a5678"))
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(420, 0)
	box.add_child(e)
	box.add_child(pill("好的", "OK", GOLD, Vector2(200, 50), func() -> void: dim.queue_free(), 20))

# A vertical sky gradient texture used as a background.
static func sky_texture(top: Color, bottom: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([top, bottom])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	return tex
