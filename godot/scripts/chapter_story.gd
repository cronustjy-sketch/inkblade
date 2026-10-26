extends Control

# A chapter story scene (CHS from the web game): two stickman figures on dark hills, a dialogue box with a typewriter
# effect, Chinese with English underneath. Space / Enter / click = next line, Esc = skip. Emits `finished`.

signal finished

const Kit := preload("res://scripts/ui_kit.gd")
const StoryData := preload("res://data/story_data.gd")
const ACCENTS: Array[String] = ["#7cc35a", "#e0703a", "#6a7a5a", "#a8d8ee", "#9ad0f0", "#5a4a7a", "#e8c66a"]
const TYPE_SPEED_CN: float = 18.0
const TYPE_SPEED_EN: float = 44.0
const TITLE_TIME: float = 1.6

var chapter: int = 1
var _lines: Array = []
var _i: int = -1
var _who: String = "t"
var _typed: float = 0.0
var _clock: float = 0.0
var _accent: Color = Color("f2b632")
var _foe_cn: String = "敌人"
var _foe_en: String = "Enemy"
var _dots: Array[Vector3] = []
var _box: PanelContainer
var _name_label: Label
var _cn_label: Label
var _en_label: Label
var _hint: Label
var _title_box: Control
var _gone: bool = false
var _full_cn: String = ""
var _full_en: String = ""
var _right: String = "m"

func setup(p_chapter: int) -> void:
	chapter = p_chapter

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var key: String = str(chapter)
	_lines = StoryData.CHS.get(key, [])
	_accent = Color(ACCENTS[(chapter - 1) % ACCENTS.size()])
	_foe_cn = StoryData.CHF.get(key, "敌人")
	_foe_en = StoryData.CHF_EN.get(key, "Enemy")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 40:
		_dots.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	_build_ui()
	if _lines.is_empty():
		_end()
		return
	get_tree().create_timer(TITLE_TIME).timeout.connect(func() -> void:
		if not _gone and _i < 0:
			_next())

func _build_ui() -> void:
	# Title card (chapter number + name), fades out when the first line appears.
	var ch: Dictionary = {}
	for c: Dictionary in StoryData.CHAPTERS:
		if int(c["n"]) == chapter:
			ch = c
	_title_box = VBoxContainer.new()
	_title_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_box.offset_top = 56.0
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_box)
	var cn_name: String = String(ch.get("t", "")).get_slice(" · ", 1)
	var en_name: String = String(ch.get("e", "")).get_slice(" · ", 1)
	_title_box.add_child(Kit.bilingual("第 %d 章" % chapter, "Chapter %d" % chapter, 22, 14, Color("dfe8f8"), Color("aab6d0"), 4))
	_title_box.add_child(Kit.bilingual(cn_name, en_name, 56, 24, Color.WHITE, _accent.lightened(0.3), 8, true))

	# Dialogue box.
	_box = PanelContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_left = 60.0
	_box.offset_right = -60.0
	_box.offset_top = -190.0
	_box.offset_bottom = -26.0
	_box.add_theme_stylebox_override("panel", Kit.flat(Color(0.07, 0.08, 0.13, 0.94), _accent, 5, 22, 16))
	_box.visible = false
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_box.add_child(v)
	_name_label = Kit.label("", 20, _accent.lightened(0.35), 4, true)
	v.add_child(_name_label)
	_cn_label = Kit.label("", 21, Color.WHITE, 0)
	_cn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_cn_label)
	_en_label = Kit.label("", 15, Color("b8c3da"), 0)
	_en_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_en_label)
	_hint = Kit.label("点击 / 空格 继续 · Esc 跳过    Click / Space: next · Esc: skip", 12, Color("7e89a6"), 0)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.offset_right = -70.0
	_hint.offset_bottom = -4.0
	add_child(_hint)
	var skip: Button = Kit.pill("跳过", "Skip", Kit.CREAM, Vector2(120, 44), _end, 17)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -20.0
	skip.offset_top = 18.0
	add_child(skip)

func _process(delta: float) -> void:
	_clock += delta
	if _full_cn != "":
		_typed = minf(float(_full_cn.length()), _typed + delta * TYPE_SPEED_CN)
		_cn_label.text = _full_cn.substr(0, int(_typed))
		var frac: float = _typed / maxf(1.0, float(_full_cn.length()))
		_en_label.text = _full_en.substr(0, int(frac * _full_en.length()))
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if _gone:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_end()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_J]:
			_next()
			get_viewport().set_input_as_handled()

func _next() -> void:
	if _gone:
		return
	if _full_cn != "" and _typed < float(_full_cn.length()):
		_typed = float(_full_cn.length())
		return
	_i += 1
	if _i >= _lines.size():
		_end()
		return
	var line: Dictionary = _lines[_i]
	_who = line["w"]
	if line.get("x", "") != "":
		_right = line["x"]
	elif _who in ["m", "f", "s"]:
		_right = _who
	_box.visible = true
	_title_box.visible = false
	_name_label.text = _speaker(_who)
	_name_label.add_theme_color_override("font_color", _speaker_color(_who))
	_full_cn = line["t"]
	_full_en = line["en"]
	_typed = 0.0
	_cn_label.text = ""
	_en_label.text = ""

func _speaker(w: String) -> String:
	match w:
		"y":
			return "你  You"
		"m":
			return "墨老  Old Ink"
		"f":
			return "%s  %s" % [_foe_cn, _foe_en]
		"s":
			return "影  Shadow"
	return ""

func _speaker_color(w: String) -> Color:
	match w:
		"m":
			return Color("7fb8ff")
		"f":
			return Color("ff7a5a")
		"s":
			return Color("ff4a3a")
	return _accent.lightened(0.35)

func _end() -> void:
	if _gone:
		return
	_gone = true
	finished.emit()
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)

# ---------- drawing ----------

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# Background gradient.
	var top: Color = Color("2a0606") if _who == "s" else Color("1a1a22")
	for k in 24:
		var f0: float = float(k) / 24.0
		draw_rect(Rect2(0, h * f0, w, h / 24.0 + 1.0), top.lerp(Color("060608"), f0))
	draw_circle(Vector2(w * 0.5, h * 0.42), minf(w, h) * 0.32, Color(_accent, 0.18))
	# Hills.
	for k in 3:
		var pts := PackedVector2Array()
		var base: float = h * (0.62 + k * 0.06)
		pts.append(Vector2(0, h))
		for x in range(13):
			pts.append(Vector2(w * x / 12.0, base - absf(sin(x * 1.7 + k * 2.0)) * h * (0.14 - k * 0.03)))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.25 + k * 0.2))
	# Floating dust.
	for d: Vector3 in _dots:
		var yy: float = fposmod(d.y * h - _clock * 20.0 * (d.z + 0.2), h)
		draw_circle(Vector2(d.x * w, yy), 1.0 + d.z * 3.0, Color(1.0, 0.94, 0.82, 0.04 + d.z * 0.08))
	var s: float = minf(w * 0.22, h * 0.36)
	var gy: float = h * 0.72
	_figure(Vector2(w * 0.28, gy), s, "y", _who == "y", false)
	_figure(Vector2(w * 0.72, gy), s, _right, _who == _right, true)
	if _who == "n":
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.35))

func _figure(origin: Vector2, s: float, kind: String, active: bool, flip: bool) -> void:
	var sx: float = -1.0 if flip else 1.0
	var bob: float = sin(_clock * 2.0 + (1.0 if flip else 0.0)) * s * 0.02
	var base := Vector2(origin.x, origin.y + bob)
	var fade: float = 1.0 if active else 0.45
	var col: Color
	var glow: Color
	match kind:
		"m":
			col = Color("9cc8ff")
			glow = Color("7fb8ff")
		"f":
			col = Color("2a0e0e")
			glow = Color("ff5a3a")
		"s":
			col = Color("050507")
			glow = Color("ff2a1a")
		_:
			col = Color("121216")
			glow = _accent
	col.a = fade
	var p := func(x: float, y: float) -> Vector2:
		return base + Vector2(x * sx, y) * s
	# Soft glow behind the figure, then every limb is drawn twice: a coloured rim, then the body colour.
	draw_circle(p.call(0.05, -0.55), s * 0.62, Color(glow, (0.2 if active else 0.07)))
	draw_circle(p.call(0.05, -0.55), s * 0.4, Color(glow, (0.2 if active else 0.07)))
	var lw: float = s * 0.075
	var rim := Color(glow, 0.85 * fade)
	var limb := func(pts: Array, width: float) -> void:
		var poly := PackedVector2Array()
		for pt: Vector2 in pts:
			poly.append(pt)
		draw_polyline(poly, rim, width + s * 0.035, true)
		draw_polyline(poly, col, width, true)
	if kind == "m":
		# Ghost: a teardrop body (two quadratic curves, like the web version).
		var ghost := PackedVector2Array()
		var tail: float = 0.05 + sin(_clock * 3.0) * 0.03
		for k in 13:
			var t: float = float(k) / 12.0
			var a := Vector2(-0.12, -0.45)
			var c1 := Vector2(-0.25, -0.1)
			var b := Vector2(0.0, tail)
			ghost.append(p.call(lerpf(lerpf(a.x, c1.x, t), lerpf(c1.x, b.x, t), t), lerpf(lerpf(a.y, c1.y, t), lerpf(c1.y, b.y, t), t)))
		for k in 13:
			var t: float = float(k) / 12.0
			var b2 := Vector2(0.0, tail)
			var c2 := Vector2(0.2, -0.1)
			var e := Vector2(0.12, -0.45)
			ghost.append(p.call(lerpf(lerpf(b2.x, c2.x, t), lerpf(c2.x, e.x, t), t), lerpf(lerpf(b2.y, c2.y, t), lerpf(c2.y, e.y, t), t)))
		draw_colored_polygon(ghost, Color(col, 0.85 * fade))
	else:
		limb.call([p.call(0.0, -0.45), p.call(-0.2, -0.05), p.call(-0.28, 0.0)], lw)
		limb.call([p.call(0.0, -0.45), p.call(0.18, -0.06), p.call(0.26, 0.0)], lw)
	limb.call([p.call(0.0, -0.45), p.call(0.03, -0.85)], lw)
	limb.call([p.call(0.03, -0.82), p.call(0.22, -0.62), p.call(0.36, -0.68)], lw)
	limb.call([p.call(0.03, -0.82), p.call(-0.16, -0.6), p.call(-0.22, -0.45)], lw)
	draw_circle(p.call(0.05, -1.0), s * 0.14 + s * 0.02, rim)
	draw_circle(p.call(0.05, -1.0), s * 0.14, col)
	var eye: Color = Color("ff2a1a") if kind in ["f", "s"] else Color.WHITE
	eye.a = fade
	draw_circle(p.call(0.12, -1.01), s * 0.04, eye)
	if kind == "y":
		var band_a: Vector2 = p.call(-0.04, -0.86)
		var band_b: Vector2 = p.call(0.1, -0.86)
		draw_line(band_a, band_b, Color(_accent, fade), s * 0.07, true)
		var scarf: Array = []
		for k in 7:
			var f: float = float(k) / 6.0
			scarf.append(p.call(-0.02 - 0.45 * f, -0.83 + f * 0.13 + sin(_clock * 4.0 + f * 3.0) * 0.045))
		draw_polyline(PackedVector2Array(scarf), Color(_accent, fade), s * 0.05, true)
	if kind in ["y", "s", "f"]:
		var blade: Color = Color("f2b632") if kind == "y" else (Color("ff4a3a") if kind == "s" else Color("ff7a5a"))
		blade.a = fade
		draw_line(p.call(0.36, -0.68), p.call(0.98, -1.13), blade, s * 0.04, true)
	if kind == "f":
		draw_colored_polygon(PackedVector2Array([p.call(-0.05, -1.12), p.call(0.02, -1.34), p.call(0.08, -1.12)]), Color(_accent, fade))
		draw_colored_polygon(PackedVector2Array([p.call(0.08, -1.1), p.call(0.2, -1.29), p.call(0.18, -1.06)]), Color(_accent, fade))
