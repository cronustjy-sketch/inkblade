extends CanvasLayer

signal spawn_requested(key: String)

const UnitData := preload("res://data/units.gd")
const GOLD := Color("e8b44a")
const PANEL := Color("13161b")

var _energy_bar: ProgressBar
var _energy_label: Label
var _pop_label: Label
var _buttons: Dictionary = {}

func setup(level: int, max_energy: float, max_pop: int) -> void:
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

func _init() -> void:
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
