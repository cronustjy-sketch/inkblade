extends CanvasLayer

signal spawn_requested(key: String)
signal skill_requested(id: String)
signal order_requested(order: int)
signal ult_requested
signal retry_requested
signal next_level_requested
signal map_requested

const UnitData := preload("res://data/units.gd")
const GOLD := Color("e8b44a")
const RED := Color("de4b3f")
const PANEL := Color("13161b")
const ORDERS: Array[Array] = [["进攻", "Attack"], ["防守", "Defend"], ["撤退", "Retreat"]]

var _energy_bar: ProgressBar
var _energy_label: Label
var _pop_label: Label
var _buttons: Dictionary = {}
var _skill_buttons: Dictionary = {}
var _order_buttons: Array[Button] = []
var _ink_bar: ProgressBar
var _ult_button: Button
var _control_label: Label
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_label: Label

func setup(level: int, max_energy: float, max_pop: int, skills: Array[String] = []) -> void:
	$LevelLabel.text = "第 %d 关 Level %d" % [level, level]
	_energy_bar.max_value = max_energy
	_pop_label.set_meta("max_pop", max_pop)
	_energy_label.set_meta("max_energy", max_energy)
	for key: String in UnitData.UNITS:
		var d: Dictionary = UnitData.UNITS[key]
		if d["unlock"] > level:
			continue
		var b: Button = _button("%s\n%s\n⚡%d" % [d["name_cn"], d["name_en"], d["cost"]], Vector2(88, 64), 12)
		b.pressed.connect(func() -> void: spawn_requested.emit(key))
		$Panel/Margin/VBox/Buttons.add_child(b)
		_buttons[key] = b
	for id: String in skills:
		var s: Dictionary = UnitData.HERO_SKILLS[id]
		var b: Button = _button("", Vector2(84, 58), 12)
		b.pressed.connect(func() -> void: skill_requested.emit(id))
		$Skills/Row.add_child(b)
		_skill_buttons[id] = b
		b.text = "%s %s\n%s" % [s["key"], s["name_cn"], s["name_en"]]
	$Skills.visible = not skills.is_empty()

func update_state(energy: float, pop: int) -> void:
	var max_energy: float = _energy_label.get_meta("max_energy")
	var max_pop: int = _pop_label.get_meta("max_pop")
	_energy_bar.value = energy
	_energy_label.text = "能量 Energy  %d / %d" % [int(energy), int(max_energy)]
	_pop_label.text = "人口 Pop  %d / %d" % [pop, max_pop]
	for key: String in _buttons:
		var d: Dictionary = UnitData.UNITS[key]
		_buttons[key].disabled = energy < d["cost"] or pop + int(d["pop"]) > max_pop

# hero is the hero node: needs can_cast(id) and cooldown_fraction(id).
func update_skills(hero: Node3D) -> void:
	for id: String in _skill_buttons:
		var s: Dictionary = UnitData.HERO_SKILLS[id]
		var b: Button = _skill_buttons[id]
		var left: float = hero.skill_cd.get(id, 0.0)
		b.disabled = not hero.can_cast(id)
		var tail: String = "%.1fs" % left if left > 0.0 else s["name_en"]
		b.text = "%s %s\n%s" % [s["key"], s["name_cn"], tail]

func update_ink(value: float, max_value: float) -> void:
	_ult_button.visible = true
	_ink_bar.visible = true
	_ink_bar.max_value = max_value
	_ink_bar.value = value
	var is_full: bool = value >= max_value
	_ult_button.disabled = not is_full
	_ult_button.text = "墨刃·终 Ink Blade Final [空格 Space]%s" % ("  就绪 READY" if is_full else "")

func set_order(order: int) -> void:
	for i in _order_buttons.size():
		_order_buttons[i].button_pressed = i == order

func set_control_text(text: String) -> void:
	_control_label.text = text

func show_boss(name_cn: String, name_en: String, max_hp: float) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp
	_boss_label.text = "%s  %s" % [name_cn, name_en]
	_boss_box.visible = true

func update_boss(hp: float) -> void:
	_boss_bar.value = hp

func hide_boss() -> void:
	_boss_box.visible = false

func show_result(won: bool, level: int, has_next: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "胜利 Victory" if won else "失败 Defeat"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", GOLD if won else RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "第 %d 关 Level %d" % [level, level]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	if won and not has_next:
		var done := Label.new()
		done.text = "恭喜通关！ All levels cleared!  —  Junyuan"
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.add_theme_color_override("font_color", GOLD)
		box.add_child(done)
	if won and has_next:
		box.add_child(_result_button("下一关 Next Level", next_level_requested))
	box.add_child(_result_button("重试 Retry", retry_requested))
	box.add_child(_result_button("地图 Map", map_requested))

func _result_button(text: String, sig: Signal) -> Button:
	var b: Button = _button(text, Vector2(220, 52), 16)
	b.pressed.connect(func() -> void: sig.emit())
	return b

func _button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	return b

func _init() -> void:
	# Must keep working while the tree is paused on the result screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.position = Vector2(14, 10)
	level_label.add_theme_color_override("font_color", Color("13161b"))
	add_child(level_label)

	_control_label = Label.new()
	_control_label.position = Vector2(14, 34)
	_control_label.add_theme_color_override("font_color", Color("13161b"))
	add_child(_control_label)

	_build_boss_bar()
	_build_side_bars()

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	_energy_label = Label.new()
	_energy_label.add_theme_color_override("font_color", GOLD)
	top.add_child(_energy_label)
	_energy_bar = ProgressBar.new()
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(260, 18)
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	_energy_bar.add_theme_stylebox_override("fill", fill)
	top.add_child(_energy_bar)
	_pop_label = Label.new()
	top.add_child(_pop_label)
	top.add_theme_constant_override("separation", 20)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 6)
	vbox.add_child(buttons)

# Orders (bottom-left), skills + ult meter (bottom-right), both floating above the bottom panel.
func _build_side_bars() -> void:
	var orders := HBoxContainer.new()
	orders.name = "Orders"
	orders.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	orders.grow_vertical = Control.GROW_DIRECTION_BEGIN
	orders.position = Vector2(10, -150)
	orders.add_theme_constant_override("separation", 6)
	add_child(orders)
	orders.visible = false
	for i in ORDERS.size():
		var b: Button = _button("%s\n%s" % [ORDERS[i][0], ORDERS[i][1]], Vector2(78, 50), 12)
		b.toggle_mode = true
		var order: int = i
		b.pressed.connect(func() -> void: order_requested.emit(order))
		orders.add_child(b)
		_order_buttons.append(b)

	var skills := VBoxContainer.new()
	skills.name = "Skills"
	skills.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skills.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skills.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skills.position = Vector2(-10, -150)
	skills.visible = false
	add_child(skills)
	_ult_button = _button("墨刃·终 Ink Blade Final", Vector2(300, 30), 12)
	_ult_button.visible = false
	_ult_button.pressed.connect(func() -> void: ult_requested.emit())
	skills.add_child(_ult_button)
	_ink_bar = ProgressBar.new()
	_ink_bar.show_percentage = false
	_ink_bar.custom_minimum_size = Vector2(300, 12)
	var ink_fill := StyleBoxFlat.new()
	ink_fill.bg_color = Color("0d0d0f")
	_ink_bar.add_theme_stylebox_override("fill", ink_fill)
	_ink_bar.visible = false
	skills.add_child(_ink_bar)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	skills.add_child(row)

func show_orders() -> void:
	$Orders.visible = true

func _build_boss_bar() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.position = Vector2(-200, 10)
	_boss_box.visible = false
	add_child(_boss_box)
	_boss_label = Label.new()
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_color_override("font_color", RED)
	_boss_box.add_child(_boss_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(400, 16)
	var fill := StyleBoxFlat.new()
	fill.bg_color = RED
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_box.add_child(_boss_bar)

# Full-screen black flash for the ultimate.
func flash() -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.03, 0.03, 0.05, 0.85)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.55)
	tw.tween_callback(rect.queue_free)
