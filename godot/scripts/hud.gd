extends CanvasLayer

signal spawn_requested(key: String)
signal retry_requested
signal next_level_requested

const UnitData := preload("res://data/units.gd")
const GOLD := Color("e8b44a")
const PANEL := Color("13161b")

var _energy_bar: ProgressBar
var _energy_label: Label
var _pop_label: Label
var _buttons: Dictionary = {}

func setup(level: int, max_energy: float, max_pop: int) -> void:
	$LevelLabel.text = "第 %d 关 Level %d" % [level, level]
	_energy_bar.max_value = max_energy
	_pop_label.set_meta("max_pop", max_pop)
	_energy_label.set_meta("max_energy", max_energy)
	for key: String in UnitData.UNITS:
		var d: Dictionary = UnitData.UNITS[key]
		if d["unlock"] > level:
			continue
		var b := Button.new()
		b.text = "%s\n%s\n⚡%d" % [d["name_cn"], d["name_en"], d["cost"]]
		b.custom_minimum_size = Vector2(110, 64)
		b.pressed.connect(func() -> void: spawn_requested.emit(key))
		$Panel/Margin/VBox/Buttons.add_child(b)
		_buttons[key] = b

func update_state(energy: float, pop: int) -> void:
	var max_energy: float = _energy_label.get_meta("max_energy")
	var max_pop: int = _pop_label.get_meta("max_pop")
	_energy_bar.value = energy
	_energy_label.text = "能量 Energy  %d / %d" % [int(energy), int(max_energy)]
	_pop_label.text = "人口 Pop  %d / %d" % [pop, max_pop]
	for key: String in _buttons:
		var d: Dictionary = UnitData.UNITS[key]
		_buttons[key].disabled = energy < d["cost"] or pop + int(d["pop"]) > max_pop

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
	title.add_theme_color_override("font_color", GOLD if won else Color("de4b3f"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "第 %d 关 Level %d" % [level, level]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	if won and has_next:
		box.add_child(_result_button("下一关 Next Level", next_level_requested))
	box.add_child(_result_button("重试 Retry", retry_requested))

func _result_button(text: String, sig: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 52)
	b.pressed.connect(func() -> void: sig.emit())
	return b

func _init() -> void:
	# Must keep working while the tree is paused on the result screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.position = Vector2(14, 10)
	level_label.add_theme_color_override("font_color", Color("13161b"))
	add_child(level_label)

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
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)
