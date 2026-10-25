extends CanvasLayer

# Battle HUD in a flat cartoon style: round buttons with thick black outlines and flat colours.
#   top-left     round unit buttons (portrait + energy cost underneath)
#   top-right    energy + population + level + castle HP
#   bottom-left  orders (round)        bottom-right  hero skills (round) and the ultimate (big ring)
# Chinese text with English underneath wherever there is room.

signal spawn_requested(key: String)
signal skill_requested(id: String)
signal order_requested(order: int)
signal ult_requested
signal retry_requested
signal next_level_requested
signal map_requested

const UnitData := preload("res://data/units.gd")
const SpriteMeta := preload("res://data/sprite_meta.gd")
const OUTLINE := Color("0d0d12")
const GOLD := Color("f2b632")
const RED := Color("e0463b")
const CREAM := Color("fff3d1")
const NAVY := Color("1f2a4d")
const SKY := Color("9fd8ff")
const ORDERS: Array[Array] = [["攻", "Attack"], ["守", "Defend"], ["退", "Retreat"]]
const SKILL_GLYPH: Dictionary = {"slash": "斩", "dash": "冲", "rally": "吼", "rain": "雨", "special": "旋"}

static var _disc_tex: ImageTexture

var _root: Control
var _unit_row: HBoxContainer
var _skill_row: HBoxContainer
var _orders_row: HBoxContainer
var _unit_buttons: Dictionary = {}
var _skill_buttons: Dictionary = {}
var _order_buttons: Array[Button] = []
var _energy_bar: ProgressBar
var _energy_label: Label
var _pop_label: Label
var _level_label: Label
var _player_bar: ProgressBar
var _enemy_bar: ProgressBar
var _player_label: Label
var _enemy_label: Label
var _ult_button: Button
var _ult_ring: TextureProgressBar
var _ult_label: Label
var _control_label: Label
var _boss_box: VBoxContainer
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
	add_child(_root)
	_build_top()
	_build_bottom()

# ---------- public API ----------

func setup(level: int, max_energy: float, max_pop: int, skills: Array[String] = []) -> void:
	_max_energy = max_energy
	_max_pop = max_pop
	_energy_bar.max_value = max_energy
	_level_label.text = "第 %d 关  Level %d" % [level, level]
	for key: String in UnitData.UNITS:
		var d: Dictionary = UnitData.UNITS[key]
		if d["unlock"] > level:
			continue
		var column: VBoxContainer = _unit_button(key, d)
		_unit_row.add_child(column)
		_unit_buttons[key] = column.get_child(0)
	for id: String in skills:
		var b: Button = _skill_button(id)
		_skill_row.add_child(b)
		_skill_buttons[id] = b
	_skill_row.visible = not skills.is_empty()

func update_state(energy: float, pop: int) -> void:
	_energy_bar.value = energy
	_energy_label.text = "%d" % int(energy)
	_pop_label.text = "%d/%d" % [pop, _max_pop]
	for key: String in _unit_buttons:
		var d: Dictionary = UnitData.UNITS[key]
		var b: Button = _unit_buttons[key]
		b.disabled = energy < d["cost"] or pop + int(d["pop"]) > _max_pop
		b.get_parent().modulate = Color(1, 1, 1, 0.5) if b.disabled else Color.WHITE

func update_castles(player_hp: float, player_max: float, enemy_hp: float, enemy_max: float) -> void:
	_player_bar.max_value = player_max
	_player_bar.value = player_hp
	_player_label.text = "我方 %d" % ceili(player_hp)
	_enemy_bar.max_value = enemy_max
	_enemy_bar.value = enemy_hp
	_enemy_label.text = "敌方 %d" % ceili(enemy_hp)

# hero is the hero node: needs can_cast(id) and skill_cd.
func update_skills(hero: Node3D) -> void:
	for id: String in _skill_buttons:
		var s: Dictionary = UnitData.HERO_SKILLS[id]
		var b: Button = _skill_buttons[id]
		var left: float = hero.skill_cd.get(id, 0.0)
		b.disabled = not hero.can_cast(id)
		var pie: TextureProgressBar = b.get_node("Pie")
		pie.value = left / s["cooldown"] * 100.0
		(b.get_node("Cd") as Label).text = "%d" % ceili(left) if left > 0.0 else ""
		b.modulate = Color(1, 1, 1, 0.8) if b.disabled else Color.WHITE

func update_ink(value: float, max_value: float) -> void:
	_ult_ring.max_value = max_value
	_ult_ring.value = max_value - value
	var is_full: bool = value >= max_value
	_ult_button.disabled = not is_full
	_ult_label.text = "READY" if is_full else "%d%%" % int(value / max_value * 100.0)
	_ult_button.modulate = Color.WHITE if is_full else Color(1, 1, 1, 0.85)

func set_order(order: int) -> void:
	for i in _order_buttons.size():
		_order_buttons[i].button_pressed = i == order

func set_control_text(text: String) -> void:
	_control_label.text = text
	_control_label.visible = text != ""

func show_orders() -> void:
	pass # orders are always visible

func show_boss(name_cn: String, name_en: String, max_hp: float) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp
	_boss_name.text = "%s  %s" % [name_cn, name_en]
	_boss_box.visible = true

func update_boss(hp: float) -> void:
	_boss_bar.value = hp

func hide_boss() -> void:
	_boss_box.visible = false

# Full-screen white flash for the ultimate.
func flash() -> void:
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 0.9)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.5)
	tw.tween_callback(rect.queue_free)

func show_result(won: bool, level: int, has_next: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
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
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var title_en: Label = _outlined("Victory" if won else "Defeat", 24, Color.WHITE, 5)
	title_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_en)
	var sub: Label = _plain("第 %d 关  Level %d" % [level, level], 16, NAVY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	if won and not has_next:
		var done: Label = _plain("恭喜通关！ All levels cleared!  —  Junyuan", 16, NAVY)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(done)
	if won and has_next:
		box.add_child(_result_button("下一关  Next Level", GOLD, next_level_requested))
	box.add_child(_result_button("重试  Retry", SKY, retry_requested))
	box.add_child(_result_button("地图  Map", CREAM, map_requested))

# ---------- layout ----------

func _build_top() -> void:
	# Left: unit buttons.
	_unit_row = HBoxContainer.new()
	_unit_row.position = Vector2(14.0, 10.0)
	_unit_row.add_theme_constant_override("separation", 8)
	_unit_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_unit_row)

	# Right: energy, population, level, castle HP.
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -12.0
	panel.offset_top = 10.0
	panel.add_theme_stylebox_override("panel", _flat(NAVY, OUTLINE, 4, 16, 10))
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	_level_label = _outlined("", 14, Color.WHITE, 4)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_level_label)

	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 6)
	col.add_child(energy_row)
	energy_row.add_child(_coin(22.0))
	_energy_bar = _bar(GOLD, 20)
	_energy_bar.custom_minimum_size = Vector2(170, 20)
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_row.add_child(_energy_bar)
	_energy_label = _outlined("", 18, GOLD, 5)
	_energy_label.custom_minimum_size = Vector2(44, 0)
	energy_row.add_child(_energy_label)

	var pop_row := HBoxContainer.new()
	pop_row.add_theme_constant_override("separation", 6)
	col.add_child(pop_row)
	pop_row.add_child(_outlined("人口 Pop", 14, Color.WHITE, 4))
	_pop_label = _outlined("", 18, Color.WHITE, 5)
	pop_row.add_child(_pop_label)

	_player_bar = _bar(GOLD, 12)
	_player_label = _outlined("", 12, GOLD, 4)
	_enemy_bar = _bar(RED, 12)
	_enemy_label = _outlined("", 12, RED.lightened(0.3), 4)
	for pair: Array in [[_player_label, _player_bar], [_enemy_label, _enemy_bar]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label: Label = pair[0]
		label.custom_minimum_size = Vector2(62, 0)
		row.add_child(label)
		var bar: ProgressBar = pair[1]
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		col.add_child(row)

	# Boss bar, centred under the unit row.
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.offset_left = -220.0
	_boss_box.offset_right = 220.0
	_boss_box.offset_top = 124.0
	_boss_box.visible = false
	_root.add_child(_boss_box)
	_boss_name = _outlined("", 18, RED.lightened(0.35), 5)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(RED, 18)
	_boss_box.add_child(_boss_bar)

	_control_label = _outlined("", 14, GOLD, 5)
	_control_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_control_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_control_label.offset_left = 16.0
	_control_label.offset_bottom = -112.0
	_control_label.visible = false
	_root.add_child(_control_label)

func _build_bottom() -> void:
	# Orders, bottom-left.
	_orders_row = HBoxContainer.new()
	_orders_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_orders_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_orders_row.offset_left = 14.0
	_orders_row.offset_bottom = -12.0
	_orders_row.add_theme_constant_override("separation", 8)
	_orders_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_orders_row)
	for i in ORDERS.size():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var b: Button = _round_button(58.0, SKY, GOLD)
		b.toggle_mode = true
		var order: int = i
		b.pressed.connect(func() -> void: order_requested.emit(order))
		_glyph(b, ORDERS[i][0], 28)
		col.add_child(b)
		var label: Label = _outlined(ORDERS[i][1], 11, Color.WHITE, 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(label)
		_orders_row.add_child(col)
		_order_buttons.append(b)

	# Skills + ultimate, bottom-right.
	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -14.0
	right.offset_bottom = -12.0
	right.add_theme_constant_override("separation", 10)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	_skill_row = HBoxContainer.new()
	_skill_row.add_theme_constant_override("separation", 8)
	_skill_row.alignment = BoxContainer.ALIGNMENT_END
	_skill_row.size_flags_vertical = Control.SIZE_SHRINK_END
	right.add_child(_skill_row)
	var ult_col := VBoxContainer.new()
	ult_col.add_theme_constant_override("separation", 0)
	right.add_child(ult_col)
	_ult_button = _round_button(86.0, GOLD, OUTLINE)
	_ult_button.pressed.connect(func() -> void: ult_requested.emit())
	ult_col.add_child(_ult_button)
	_ult_ring = TextureProgressBar.new()
	_ult_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ult_ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	_ult_ring.texture_progress = _disc()
	_ult_ring.tint_progress = Color(0.05, 0.05, 0.1, 0.55)
	_ult_ring.nine_patch_stretch = true
	_ult_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_button.add_child(_ult_ring)
	_glyph(_ult_button, "墨", 38)
	_ult_label = _outlined("", 13, Color.WHITE, 4)
	_ult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ult_col.add_child(_ult_label)
	var ult_name: Label = _outlined("墨刃·终 [Space]", 11, Color.WHITE, 4)
	ult_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ult_col.add_child(ult_name)

# ---------- widgets ----------

# A round unit button with the portrait inside and the energy cost underneath. Returns the column.
func _unit_button(key: String, d: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var b: Button = _round_button(64.0, CREAM, OUTLINE)
	b.pressed.connect(func() -> void: spawn_requested.emit(key))
	b.tooltip_text = "%s %s" % [d["name_cn"], d["name_en"]]
	col.add_child(b)
	var portrait := TextureRect.new()
	portrait.texture = _portrait(key)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 9.0
	portrait.offset_right = -9.0
	portrait.offset_top = 7.0
	portrait.offset_bottom = -7.0
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(portrait)
	var cost := HBoxContainer.new()
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	cost.add_theme_constant_override("separation", 3)
	cost.add_child(_coin(14.0))
	cost.add_child(_outlined("%d" % d["cost"], 15, GOLD, 4))
	col.add_child(cost)
	return col

# A round hero-skill button: big Chinese glyph, key letter, radial cooldown shade and countdown.
func _skill_button(id: String) -> Button:
	var s: Dictionary = UnitData.HERO_SKILLS[id]
	var b: Button = _round_button(60.0, SKY, OUTLINE)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: skill_requested.emit(id))
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
	_glyph(b, SKILL_GLYPH.get(id, "?"), 28)
	var key: Label = _outlined(s["key"], 13, Color.WHITE, 4)
	key.position = Vector2(4.0, -2.0)
	b.add_child(key)
	var cd: Label = _outlined("", 24, Color.WHITE, 6)
	cd.name = "Cd"
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(cd)
	return b

# Circular button: flat fill, thick black outline, gold when toggled on.
func _round_button(diameter: float, fill: Color, pressed_fill: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(diameter, diameter)
	var r: int = int(diameter * 0.5)
	b.add_theme_stylebox_override("normal", _flat(fill, OUTLINE, 4, r, 0))
	b.add_theme_stylebox_override("hover", _flat(fill.lightened(0.25), OUTLINE, 4, r, 0))
	b.add_theme_stylebox_override("pressed", _flat(GOLD if pressed_fill == GOLD else fill.darkened(0.15), OUTLINE, 4, r, 0))
	b.add_theme_stylebox_override("hover_pressed", _flat(GOLD.lightened(0.2), OUTLINE, 4, r, 0))
	b.add_theme_stylebox_override("disabled", _flat(fill.darkened(0.25), Color(OUTLINE, 0.85), 4, r, 0))
	return b

func _glyph(b: Button, text: String, size: int) -> void:
	var l: Label = _outlined(text, size, Color.WHITE, 6)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)

func _result_button(text: String, fill: Color, sig: Signal) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.custom_minimum_size = Vector2(280, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", OUTLINE)
	b.add_theme_color_override("font_hover_color", OUTLINE)
	b.add_theme_stylebox_override("normal", _flat(fill, OUTLINE, 5, 27, 0))
	b.add_theme_stylebox_override("hover", _flat(fill.lightened(0.25), OUTLINE, 5, 27, 0))
	b.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.15), OUTLINE, 5, 27, 0))
	b.pressed.connect(func() -> void: sig.emit())
	return b

# First walk frame of the unit's sprite sheet, cropped tight.
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

func _coin(size: float) -> Control:
	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(size, size)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.add_theme_stylebox_override("panel", _flat(GOLD, OUTLINE, 3, int(size * 0.5), 0))
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return coin

func _bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	var r: int = int(height * 0.5)
	bar.add_theme_stylebox_override("fill", _flat(color, Color(0, 0, 0, 0), 0, r, 0))
	bar.add_theme_stylebox_override("background", _flat(Color("3a4056"), OUTLINE, 3, r, 0))
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

# White disc used for the radial cooldown / ink fills.
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
