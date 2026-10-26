extends CanvasLayer

# HUD for the 3D Boss Raid: boss HP bar (Chinese + English name) on top, hero HP bottom-left, skill buttons
# with cooldowns, countdown / result panels, and touch controls (joystick + buttons) on phones.

signal attack_pressed
signal dodge_pressed
signal skill_pressed(id: String)
signal next_pressed
signal retry_pressed
signal menu_pressed

const UnitData := preload("res://data/units.gd")
const InkFont := preload("res://scripts/inkfont.gd")
const OUTLINE := Color("0d0d12")
const GOLD := Color("f2b632")
const RED := Color("e0463b")
const CREAM := Color("fff3d1")
const NAVY := Color("1f2a4d")
const SKY := Color("9fd8ff")
const SKILLS: Array[String] = ["slash", "dash", "rally", "rain", "special"]
const GLYPH: Dictionary = {"slash": "斩", "dash": "冲", "rally": "吼", "rain": "雨", "special": "旋"}

static var _disc_tex: ImageTexture

var joystick: Vector2 = Vector2.ZERO # -1..1, x right, y up (forward)

var _root: Control
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_phase: Label
var _hero_bar: ProgressBar
var _hero_label: Label
var _timer_label: Label
var _center_label: Label
var _skill_buttons: Dictionary = {}
var _touch_controls: Control
var _stick_base: Control
var _stick_knob: Control
var _stick_touch: int = -1
var _stick_center: Vector2 = Vector2.ZERO
var _damage_flash: ColorRect
var _hint: Label
var _result: Control
var _best_label: Label
var _move_label: Label
var _move_tween: Tween

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.9, 0.1, 0.05, 0.0)
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_damage_flash)
	_build_top()
	_build_bottom()
	_build_touch()
	_build_center()

# ---------- public API ----------

func show_boss(name_cn: String, name_en: String, hp: float, max_hp: float) -> void:
	_boss_name.text = "%s  %s" % [name_cn, name_en]
	_boss_bar.max_value = max_hp
	_boss_bar.value = hp
	_boss_phase.visible = false
	_boss_box.visible = true

func hide_boss() -> void:
	_boss_box.visible = false

func set_best(seconds: float) -> void:
	_best_label.text = "最佳 Best  %s" % _fmt(seconds)

func clear_result() -> void:
	if _result != null and is_instance_valid(_result):
		_result.queue_free()
	_result = null

func set_boss_hp(hp: float, max_hp: float, phase2: bool) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = hp
	_boss_phase.visible = phase2

func set_hero_hp(hp: float, max_hp: float) -> void:
	_hero_bar.max_value = max_hp
	_hero_bar.value = hp
	_hero_label.text = "%d / %d" % [ceili(hp), int(max_hp)]

func flash_damage() -> void:
	_damage_flash.color.a = 0.35
	var tw: Tween = _damage_flash.create_tween()
	tw.tween_property(_damage_flash, "color:a", 0.0, 0.35)

func set_time(seconds: float) -> void:
	_timer_label.text = "%d:%05.2f" % [floori(seconds / 60.0), fmod(seconds, 60.0)]

# Shows the boss move that just started ("冲锋 · 往旁边闪") under the health bar for a moment.
func show_move(name_cn: String, tip: String) -> void:
	_move_label.text = "%s · %s" % [name_cn, tip] if tip != "" else name_cn
	_move_label.modulate.a = 1.0
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_interval(1.4)
	_move_tween.tween_property(_move_label, "modulate:a", 0.0, 0.5)

func set_center(text: String, size: int = 96) -> void:
	_center_label.text = text
	_center_label.add_theme_font_size_override("font_size", size)
	_center_label.visible = text != ""

func update_skills(hero: Node) -> void:
	for id: String in _skill_buttons:
		var s: Dictionary = UnitData.HERO_SKILLS[id]
		var b: Button = _skill_buttons[id]
		var left: float = hero.skill_cd.get(id, 0.0)
		(b.get_node("Pie") as TextureProgressBar).value = left / s["cooldown"] * 100.0
		(b.get_node("Cd") as Label).text = "%d" % ceili(left) if left > 0.0 else ""
		b.modulate = Color(1, 1, 1, 0.8) if left > 0.0 else Color.WHITE

func show_touch(on: bool) -> void:
	_touch_controls.visible = on
	_hint.visible = not on

func is_touch_shown() -> bool:
	return _touch_controls.visible

func show_result(won: bool, seconds: float, best: float, has_next: bool, boss_name: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_result = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(CREAM, OUTLINE, 6, 28, 28))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title: Label = _outlined("胜利" if won else "失败", 64, GOLD if won else RED, 8)
	InkFont.apply(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var title_en: Label = _outlined("Victory" if won else "Defeat", 24, Color.WHITE, 5)
	title_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_en)
	var sub: Label = _plain(boss_name, 18, NAVY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	if won:
		var time_label: Label = _plain("用时 Time  %s" % _fmt(seconds), 20, NAVY)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(time_label)
		var best_text: String = "最佳 Best  %s" % _fmt(best)
		if best > 0.0 and absf(best - seconds) < 0.005:
			best_text += "   新纪录！ New record!"
		var best_label: Label = _plain(best_text, 16, NAVY)
		best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(best_label)
	if won and has_next:
		box.add_child(_big_button("下一位首领  Next Boss", GOLD, next_pressed))
	elif won:
		var done: Label = _plain("全部首领已击败！ All bosses defeated!", 18, NAVY)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(done)
	box.add_child(_big_button("重试  Retry", SKY, retry_pressed))
	box.add_child(_big_button("菜单  Menu", CREAM, menu_pressed))

# ---------- layout ----------

func _build_top() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_box.custom_minimum_size = Vector2(620, 0)
	_boss_box.offset_left = -310.0
	_boss_box.offset_right = 310.0
	_boss_box.offset_top = 12.0
	_boss_box.visible = false
	_root.add_child(_boss_box)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 14)
	_boss_box.add_child(name_row)
	_boss_name = _outlined("", 24, Color.WHITE, 6)
	name_row.add_child(_boss_name)
	_boss_phase = _outlined("第二阶段 PHASE 2", 16, RED.lightened(0.3), 5)
	_boss_phase.visible = false
	name_row.add_child(_boss_phase)
	_boss_bar = _bar(RED, 26)
	_boss_box.add_child(_boss_bar)
	_move_label = _outlined("", 22, Color("ffb09a"), 6)
	_move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_move_label.modulate.a = 0.0
	_boss_box.add_child(_move_label)

	_best_label = _outlined("", 15, Color("ffe9a8"), 5)
	_best_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_best_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_best_label.offset_right = -14.0
	_best_label.offset_top = 84.0
	_root.add_child(_best_label)
	_timer_label = _outlined("0:00.00", 22, Color.WHITE, 6)
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_timer_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_timer_label.offset_right = -14.0
	_timer_label.offset_top = 52.0
	_root.add_child(_timer_label)

	_hint = _outlined("WASD 移动 Move · 空格 翻滚 Roll · 左键 攻击 Attack · Q E R F 技能 Skills · 滚轮 缩放 Zoom", 15, Color.WHITE, 5)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_left = 16.0
	_hint.offset_bottom = -14.0
	_root.add_child(_hint)

func _build_bottom() -> void:
	var hero_box := VBoxContainer.new()
	hero_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hero_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hero_box.offset_left = 16.0
	hero_box.offset_bottom = -44.0
	hero_box.custom_minimum_size = Vector2(320, 0)
	_root.add_child(hero_box)
	hero_box.add_child(_outlined("英雄 Hero", 15, GOLD, 5))
	_hero_bar = _bar(Color("5fd36a"), 22)
	hero_box.add_child(_hero_bar)
	_hero_label = _outlined("", 14, Color.WHITE, 4)
	_hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_box.add_child(_hero_label)

	var skills := HBoxContainer.new()
	skills.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skills.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skills.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skills.offset_right = -16.0
	skills.offset_bottom = -14.0
	skills.add_theme_constant_override("separation", 8)
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(skills)
	for id: String in SKILLS:
		var b: Button = _skill_button(id)
		skills.add_child(b)
		_skill_buttons[id] = b

func _build_touch() -> void:
	_touch_controls = Control.new()
	_touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_controls.visible = false
	_root.add_child(_touch_controls)
	# Joystick: a base ring with a knob; it listens to touches in the lower-left quarter.
	_stick_base = Panel.new()
	_stick_base.custom_minimum_size = Vector2(150, 150)
	_stick_base.size = Vector2(150, 150)
	_stick_base.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_stick_base.offset_left = 30.0
	_stick_base.offset_top = -190.0
	_stick_base.offset_right = 180.0
	_stick_base.offset_bottom = -40.0
	_stick_base.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.25), OUTLINE, 4, 75, 0))
	_stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_controls.add_child(_stick_base)
	_stick_knob = Panel.new()
	_stick_knob.size = Vector2(64, 64)
	_stick_knob.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.8), OUTLINE, 4, 32, 0))
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_base.add_child(_stick_knob)
	_stick_knob.position = Vector2(43, 43)
	# Action buttons (right side, above the skill row).
	var atk: Button = _round_button(92.0, RED)
	atk.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	atk.offset_left = -130.0
	atk.offset_right = -38.0
	atk.offset_top = -270.0
	atk.offset_bottom = -178.0
	_glyph(atk, "攻", 40)
	atk.pressed.connect(func() -> void: attack_pressed.emit())
	_touch_controls.add_child(atk)
	var roll: Button = _round_button(70.0, SKY)
	roll.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	roll.offset_left = -222.0
	roll.offset_right = -152.0
	roll.offset_top = -216.0
	roll.offset_bottom = -146.0
	_glyph(roll, "闪", 30)
	roll.pressed.connect(func() -> void: dodge_pressed.emit())
	_touch_controls.add_child(roll)

func _build_center() -> void:
	_center_label = _outlined("", 96, Color.WHITE, 14)
	_center_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.visible = false
	_root.add_child(_center_label)

# ---------- touch joystick ----------

func _input(event: InputEvent) -> void:
	if not _touch_controls.visible:
		return
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		if te.pressed and _stick_touch == -1 and te.position.x < get_viewport().get_visible_rect().size.x * 0.4 and te.position.y > get_viewport().get_visible_rect().size.y * 0.4:
			_stick_touch = te.index
			_stick_center = _stick_base.global_position + _stick_base.size * 0.5
			_move_stick(te.position)
			get_viewport().set_input_as_handled()
		elif not te.pressed and te.index == _stick_touch:
			_stick_touch = -1
			joystick = Vector2.ZERO
			_stick_knob.position = Vector2(43, 43)
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _stick_touch:
		_move_stick((event as InputEventScreenDrag).position)
		get_viewport().set_input_as_handled()

func _move_stick(pos: Vector2) -> void:
	var stick_offset: Vector2 = (pos - _stick_center).limit_length(60.0)
	_stick_knob.position = Vector2(43, 43) + stick_offset
	joystick = Vector2(stick_offset.x, -stick_offset.y) / 60.0

# ---------- widgets ----------

func _skill_button(id: String) -> Button:
	var s: Dictionary = UnitData.HERO_SKILLS[id]
	var b: Button = _round_button(64.0, SKY)
	b.pressed.connect(func() -> void: skill_pressed.emit(id))
	b.tooltip_text = "%s %s  [%s]" % [s["name_cn"], s["name_en"], s["key"]]
	var pie := TextureProgressBar.new()
	pie.name = "Pie"
	pie.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pie.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	pie.texture_progress = _disc()
	pie.tint_progress = Color(0.05, 0.05, 0.1, 0.6)
	pie.nine_patch_stretch = true
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pie)
	_glyph(b, GLYPH[id], 28)
	var key: Label = _outlined(s["key"], 13, Color.WHITE, 4)
	key.position = Vector2(4.0, -2.0)
	b.add_child(key)
	var cd: Label = _outlined("", 24, Color.WHITE, 6)
	cd.name = "Cd"
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cd)
	return b

func _round_button(diameter: float, fill: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(diameter, diameter)
	var r: int = int(diameter * 0.5)
	b.add_theme_stylebox_override("normal", _flat(fill, OUTLINE, 4, r, 0))
	b.add_theme_stylebox_override("hover", _flat(fill.lightened(0.25), OUTLINE, 4, r, 0))
	b.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.15), OUTLINE, 4, r, 0))
	return b

func _glyph(b: Button, text: String, size: int) -> void:
	var l: Label = _outlined(text, size, Color.WHITE, 6)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)

func _big_button(text: String, fill: Color, sig: Signal) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.custom_minimum_size = Vector2(300, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", OUTLINE)
	b.add_theme_color_override("font_hover_color", OUTLINE)
	b.add_theme_stylebox_override("normal", _flat(fill, OUTLINE, 5, 27, 0))
	b.add_theme_stylebox_override("hover", _flat(fill.lightened(0.25), OUTLINE, 5, 27, 0))
	b.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.15), OUTLINE, 5, 27, 0))
	b.pressed.connect(func() -> void: sig.emit())
	return b

func _bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	var r: int = int(height * 0.5)
	bar.add_theme_stylebox_override("fill", _flat(color, Color(0, 0, 0, 0), 0, r, 0))
	bar.add_theme_stylebox_override("background", _flat(Color("3a4056"), OUTLINE, 4, r, 0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _outlined(text: String, size: int, color: Color, outline: int) -> Label:
	var l: Label = _plain(text, size, color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	return l

func _plain(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _flat(bg: Color, border: Color, border_w: int, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s

func _fmt(seconds: float) -> String:
	if seconds <= 0.0:
		return "--"
	return "%d:%05.2f" % [floori(seconds / 60.0), fmod(seconds, 60.0)]

static func _disc() -> ImageTexture:
	if _disc_tex == null:
		var size: int = 128
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c: float = size * 0.5
		for y in size:
			for x in size:
				if Vector2(x + 0.5 - c, y + 0.5 - c).length() <= c - 1.0:
					img.set_pixel(x, y, Color.WHITE)
		_disc_tex = ImageTexture.create_from_image(img)
	return _disc_tex
