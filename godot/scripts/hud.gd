extends CanvasLayer

# Battle HUD in an ink-brush style: dark ink panels with gold borders, Chinese titles with English underneath.
# Everything is built in code. Layout: castle HP + level along the top, three panels along the bottom
# (orders | army with energy and unit buttons | hero skills with the ultimate bar).

signal spawn_requested(key: String)
signal skill_requested(id: String)
signal order_requested(order: int)
signal ult_requested
signal retry_requested
signal next_level_requested
signal map_requested

const UnitData := preload("res://data/units.gd")
const SpriteMeta := preload("res://data/sprite_meta.gd")
const GOLD := Color("e8b44a")
const RED := Color("de4b3f")
const INK := Color(0.075, 0.086, 0.105, 0.94)
const INK_LIGHT := Color(0.13, 0.145, 0.175, 0.96)
const PARCHMENT := Color("efe6cf")
const MUTED := Color("a79f8a")
const ORDERS: Array[Array] = [["进攻", "Attack"], ["防守", "Defend"], ["撤退", "Retreat"]]

var _root: Control
var _energy_bar: ProgressBar
var _energy_label: Label
var _pop_label: Label
var _level_cn: Label
var _level_en: Label
var _unit_buttons: Dictionary = {}
var _skill_buttons: Dictionary = {}
var _order_buttons: Array[Button] = []
var _ult_bar: ProgressBar
var _ult_button: Button
var _hero_panel: PanelContainer
var _unit_row: HBoxContainer
var _skill_row: HBoxContainer
var _control_label: Label
var _player_hp: ProgressBar
var _enemy_hp: ProgressBar
var _player_hp_label: Label
var _enemy_hp_label: Label
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _max_energy: float = 200.0
var _max_pop: int = 50

func _init() -> void:
	# Must keep working while the tree is paused on the result screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_top()
	_build_bottom()

# ---------- public API ----------

func setup(level: int, max_energy: float, max_pop: int, skills: Array[String] = []) -> void:
	_max_energy = max_energy
	_max_pop = max_pop
	_energy_bar.max_value = max_energy
	_level_cn.text = "第 %d 关" % level
	_level_en.text = "Level %d" % level
	for key: String in UnitData.UNITS:
		var d: Dictionary = UnitData.UNITS[key]
		if d["unlock"] > level:
			continue
		var b: Button = _unit_button(key, d)
		_unit_row.add_child(b)
		_unit_buttons[key] = b
	for id: String in skills:
		var b: Button = _skill_button(id)
		_skill_row.add_child(b)
		_skill_buttons[id] = b
	_hero_panel.visible = not skills.is_empty()

func update_state(energy: float, pop: int) -> void:
	_energy_bar.value = energy
	_energy_label.text = "%d / %d" % [int(energy), int(_max_energy)]
	_pop_label.text = "%d / %d" % [pop, _max_pop]
	for key: String in _unit_buttons:
		var d: Dictionary = UnitData.UNITS[key]
		var b: Button = _unit_buttons[key]
		b.disabled = energy < d["cost"] or pop + int(d["pop"]) > _max_pop
		b.modulate = Color(1, 1, 1, 0.42) if b.disabled else Color.WHITE

func update_castles(player_hp: float, player_max: float, enemy_hp: float, enemy_max: float) -> void:
	_player_hp.max_value = player_max
	_player_hp.value = player_hp
	_player_hp_label.text = "%d / %d" % [ceili(player_hp), int(player_max)]
	_enemy_hp.max_value = enemy_max
	_enemy_hp.value = enemy_hp
	_enemy_hp_label.text = "%d / %d" % [ceili(enemy_hp), int(enemy_max)]

# hero is the hero node: needs can_cast(id) and skill_cd.
func update_skills(hero: Node3D) -> void:
	for id: String in _skill_buttons:
		var s: Dictionary = UnitData.HERO_SKILLS[id]
		var b: Button = _skill_buttons[id]
		var left: float = hero.skill_cd.get(id, 0.0)
		var frac: float = left / s["cooldown"]
		b.disabled = not hero.can_cast(id)
		b.modulate = Color(1, 1, 1, 0.55) if b.disabled else Color.WHITE
		var shade: ColorRect = b.get_node("Shade")
		shade.anchor_top = 1.0 - frac
		var cd: Label = b.get_node("Cd")
		cd.text = "%.0f" % ceilf(left) if left > 0.0 else ""

func update_ink(value: float, max_value: float) -> void:
	_ult_bar.max_value = max_value
	_ult_bar.value = value
	var is_full: bool = value >= max_value
	_ult_button.disabled = not is_full
	_ult_button.text = "墨刃·终 Ink Blade Final  [Space]" if is_full else "墨刃·终 Ink Blade Final  %d%%" % int(value / max_value * 100.0)
	_ult_button.modulate = Color.WHITE if is_full else Color(1, 1, 1, 0.8)

func set_order(order: int) -> void:
	for i in _order_buttons.size():
		_order_buttons[i].button_pressed = i == order

func set_control_text(text: String) -> void:
	_control_label.text = text
	_control_label.visible = text != ""

func show_orders() -> void:
	pass # orders are always part of the bottom bar

func show_boss(name_cn: String, name_en: String, max_hp: float) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp
	_boss_name.text = "%s  %s" % [name_cn, name_en]
	_boss_panel.visible = true

func update_boss(hp: float) -> void:
	_boss_bar.value = hp

func hide_boss() -> void:
	_boss_panel.visible = false

# Full-screen black flash for the ultimate.
func flash() -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.03, 0.03, 0.05, 0.85)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.55)
	tw.tween_callback(rect.queue_free)

func show_result(won: bool, level: int, has_next: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel: PanelContainer = _panel_box()
	panel.add_theme_stylebox_override("panel", _ink_style(INK, GOLD, 3, 14, 26))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "胜利" if won else "失败"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", GOLD if won else RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var title_en := Label.new()
	title_en.text = "Victory" if won else "Defeat"
	title_en.add_theme_font_size_override("font_size", 22)
	title_en.add_theme_color_override("font_color", PARCHMENT)
	title_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_en)

	var sub := Label.new()
	sub.text = "第 %d 关  Level %d" % [level, level]
	sub.add_theme_color_override("font_color", MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	if won and not has_next:
		var done := Label.new()
		done.text = "恭喜通关！ All levels cleared!  —  Junyuan"
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.add_theme_color_override("font_color", GOLD)
		box.add_child(done)
	if won and has_next:
		box.add_child(_result_button("下一关", "Next Level", next_level_requested))
	box.add_child(_result_button("重试", "Retry", retry_requested))
	box.add_child(_result_button("地图", "Map", map_requested))

# ---------- layout ----------

func _build_top() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12.0
	top.offset_right = -12.0
	top.offset_top = 10.0
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)

	var left: Array = _castle_panel("我方城堡", "Your Castle", GOLD)
	top.add_child(left[0])
	_player_hp = left[1]
	_player_hp_label = left[2]

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(mid)
	var level_panel: PanelContainer = _panel_box()
	level_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(level_panel)
	var level_box := VBoxContainer.new()
	level_box.add_theme_constant_override("separation", -2)
	level_panel.add_child(level_box)
	_level_cn = _label("", 17, GOLD)
	_level_cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_box.add_child(_level_cn)
	_level_en = _label("", 11, MUTED)
	_level_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_box.add_child(_level_en)

	_boss_panel = _panel_box()
	_boss_panel.visible = false
	_boss_panel.custom_minimum_size = Vector2(360, 0)
	_boss_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(_boss_panel)
	var boss_box := VBoxContainer.new()
	boss_box.add_theme_constant_override("separation", 3)
	_boss_panel.add_child(boss_box)
	_boss_name = _label("", 14, RED)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(_boss_name)
	_boss_bar = _bar(RED, 14)
	boss_box.add_child(_boss_bar)

	var right: Array = _castle_panel("敌方城堡", "Enemy Castle", RED)
	top.add_child(right[0])
	_enemy_hp = right[1]
	_enemy_hp_label = right[2]

	_control_label = _label("", 13, GOLD)
	_control_label.position = Vector2(16, 84)
	_control_label.visible = false
	_control_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_control_label.add_theme_constant_override("outline_size", 5)
	_root.add_child(_control_label)

# Returns [panel, hp bar, hp label].
func _castle_panel(cn: String, en: String, color: Color) -> Array:
	var panel: PanelContainer = _panel_box()
	panel.custom_minimum_size = Vector2(250, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	box.add_child(_title(cn, en, color))
	var bar: ProgressBar = _bar(color, 14)
	box.add_child(bar)
	var label: Label = _label("", 11, PARCHMENT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return [panel, bar, label]

func _build_bottom() -> void:
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 10.0
	bottom.offset_right = -10.0
	bottom.offset_bottom = -8.0
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)

	# Orders
	var orders: PanelContainer = _panel_box()
	bottom.add_child(orders)
	var ob := VBoxContainer.new()
	ob.add_theme_constant_override("separation", 4)
	orders.add_child(ob)
	ob.add_child(_title("号令", "Orders", GOLD))
	var orow := HBoxContainer.new()
	orow.add_theme_constant_override("separation", 4)
	ob.add_child(orow)
	for i in ORDERS.size():
		var b: Button = _button()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(52, 50)
		_two_line(b, ORDERS[i][0], ORDERS[i][1], 15)
		var order: int = i
		b.pressed.connect(func() -> void: order_requested.emit(order))
		orow.add_child(b)
		_order_buttons.append(b)

	# Army
	var army: PanelContainer = _panel_box()
	army.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(army)
	var ab := VBoxContainer.new()
	ab.add_theme_constant_override("separation", 4)
	army.add_child(ab)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	ab.add_child(head)
	head.add_child(_title("军队", "Army", GOLD))
	var energy_icon: Label = _label("⚡", 14, GOLD)
	head.add_child(energy_icon)
	_energy_bar = _bar(GOLD, 16)
	_energy_bar.custom_minimum_size = Vector2(150, 16)
	_energy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_energy_bar)
	_energy_label = _label("", 12, PARCHMENT)
	head.add_child(_energy_label)
	head.add_child(_label("人口 Pop", 12, MUTED))
	_pop_label = _label("", 13, PARCHMENT)
	head.add_child(_pop_label)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab.add_child(scroll)
	_unit_row = HBoxContainer.new()
	_unit_row.add_theme_constant_override("separation", 4)
	scroll.add_child(_unit_row)

	# Hero skills + ultimate
	_hero_panel = _panel_box()
	bottom.add_child(_hero_panel)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	_hero_panel.add_child(hb)
	hb.add_child(_title("英雄技能", "Hero Skills", GOLD))
	_skill_row = HBoxContainer.new()
	_skill_row.add_theme_constant_override("separation", 5)
	hb.add_child(_skill_row)
	_ult_bar = _bar(Color("0d0d0f"), 8)
	_ult_bar.add_theme_stylebox_override("background", _flat(Color(0.2, 0.2, 0.24), GOLD, 1, 3))
	hb.add_child(_ult_bar)
	_ult_button = _button()
	_ult_button.custom_minimum_size = Vector2(0, 26)
	_ult_button.add_theme_font_size_override("font_size", 12)
	_ult_button.text = "墨刃·终 Ink Blade Final"
	_ult_button.pressed.connect(func() -> void: ult_requested.emit())
	hb.add_child(_ult_button)

# ---------- widgets ----------

# A unit spawn button: sprite portrait, Chinese + English name, energy cost.
func _unit_button(key: String, d: Dictionary) -> Button:
	var b: Button = _button()
	b.custom_minimum_size = Vector2(60, 80)
	b.pressed.connect(func() -> void: spawn_requested.emit(key))
	b.tooltip_text = "%s %s" % [d["name_cn"], d["name_en"]]
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 3.0
	box.offset_bottom = -2.0
	box.add_theme_constant_override("separation", -1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var portrait := TextureRect.new()
	portrait.texture = _portrait(key)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(0, 38)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait)
	box.add_child(_centered(d["name_cn"], 13, PARCHMENT))
	box.add_child(_centered(d["name_en"], 8, MUTED))
	box.add_child(_centered("⚡%d" % d["cost"], 11, GOLD))
	return b

# A hero skill button: key letter, names, cooldown shade and countdown.
func _skill_button(id: String) -> Button:
	var s: Dictionary = UnitData.HERO_SKILLS[id]
	var b: Button = _button()
	b.custom_minimum_size = Vector2(54, 54)
	b.pressed.connect(func() -> void: skill_requested.emit(id))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", -2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	box.add_child(_centered(s["key"], 18, GOLD))
	box.add_child(_centered(s["name_cn"], 12, PARCHMENT))
	box.add_child(_centered(s["name_en"], 8, MUTED))
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.anchor_top = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(shade)
	var cd := Label.new()
	cd.name = "Cd"
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd.add_theme_font_size_override("font_size", 22)
	cd.add_theme_color_override("font_color", Color.WHITE)
	cd.add_theme_color_override("font_outline_color", Color.BLACK)
	cd.add_theme_constant_override("outline_size", 6)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cd)
	return b

# First walk frame of the unit's gold sprite sheet, cropped tight.
func _portrait(key: String) -> Texture2D:
	if not SpriteMeta.META.has(key):
		return null
	var tex: Texture2D = load("res://sprites/%s_gold.png" % key)
	var meta: Dictionary = SpriteMeta.META[key]
	var cell := Rect2i(0, 0, meta["cell_w"], meta["cell_h"])
	var used: Rect2i = tex.get_image().get_region(cell).get_used_rect()
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(used).grow(4.0)
	return atlas

func _result_button(cn: String, en: String, sig: Signal) -> Button:
	var b: Button = _button()
	b.custom_minimum_size = Vector2(260, 54)
	_two_line(b, cn, en, 18)
	b.pressed.connect(func() -> void: sig.emit())
	return b

func _button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	return b

# Fills a button with a Chinese line and a smaller English line under it.
func _two_line(b: Button, cn: String, en: String, cn_size: int) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	box.add_child(_centered(cn, cn_size, PARCHMENT))
	box.add_child(_centered(en, maxi(8, int(cn_size * 0.6)), MUTED))

func _title(cn: String, en: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -3)
	box.add_child(_label(cn, 15, color))
	box.add_child(_label(en, 9, MUTED))
	return box

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _centered(text: String, size: int, color: Color) -> Label:
	var l: Label = _label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.add_theme_stylebox_override("fill", _flat(color, Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("background", _flat(Color(0.03, 0.035, 0.045), Color(color, 0.7), 1, 3))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _panel_box() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _ink_style(INK, GOLD, 2, 8, 6))
	return p

# ---------- styling ----------

func _flat(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s

# Dark ink panel with a gold brush-line border and a soft shadow.
func _ink_style(bg: Color, border: Color, border_w: int, radius: int, margin: int) -> StyleBoxFlat:
	var s: StyleBoxFlat = _flat(bg, Color(border, 0.85), border_w, radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	return s

func _make_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _flat(INK_LIGHT, Color(GOLD, 0.55), 2, 6))
	t.set_stylebox("hover", "Button", _flat(Color(0.19, 0.2, 0.24, 0.98), GOLD, 2, 6))
	t.set_stylebox("pressed", "Button", _flat(Color(0.30, 0.24, 0.1, 0.98), GOLD, 2, 6))
	t.set_stylebox("hover_pressed", "Button", _flat(Color(0.34, 0.27, 0.11, 0.98), GOLD, 2, 6))
	t.set_stylebox("disabled", "Button", _flat(Color(0.08, 0.085, 0.1, 0.9), Color(GOLD, 0.2), 2, 6))
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font_size("font_size", "Button", 14)
	t.set_font_size("font_size", "Label", 14)
	t.set_color("font_color", "Label", PARCHMENT)
	return t
