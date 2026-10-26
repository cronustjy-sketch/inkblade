extends Control

# Level-select map: 20 ink-drawn stops along a winding path. Progress is stored by data/levels.gd.

const Levels := preload("res://data/levels.gd")
const InkFont := preload("res://scripts/inkfont.gd")
const BossData := preload("res://data/bosses.gd")
const BATTLE_SCENE: String = "res://scenes/battle.tscn"
const PARCHMENT := Color("efe6cf")
const INK := Color("0d0d0f")
const GOLD := Color("e8b44a")
const RED := Color("de4b3f")
const LOCKED := Color("b9b2a0")
const LAVA := Color("ff7a2a")
const COLUMNS: int = 5
const NODE_SIZE: float = 64.0

var node_buttons: Dictionary = {}
var _path: Line2D
var _labels: Dictionary = {}
var _info: Label
var _unlock_button: Button

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = PARCHMENT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_path = Line2D.new()
	_path.width = 6.0
	_path.default_color = INK
	_path.joint_mode = Line2D.LINE_JOINT_ROUND
	_path.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_path.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_path)

	var title := Label.new()
	title.text = "墨刃纪元  Ink Blade Era"
	InkFont.apply(title)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", INK)
	title.position = Vector2(30, 14)
	add_child(title)
	var credit := Label.new()
	credit.text = "作者 Junyuan  ·  by Junyuan"
	credit.add_theme_color_override("font_color", Color("5a554a"))
	credit.position = Vector2(34, 66)
	add_child(credit)

	for level in range(1, Levels.MAX_LEVEL + 1):
		_make_node(level)

	_info = Label.new()
	_info.add_theme_color_override("font_color", INK)
	add_child(_info)
	_make_footer_buttons()

	resized.connect(_layout)
	_refresh()
	_layout()

func _make_node(level: int) -> void:
	var b := Button.new()
	b.text = str(level)
	b.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	b.size = Vector2(NODE_SIZE, NODE_SIZE)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func() -> void: _start(level))
	b.mouse_entered.connect(func() -> void: _show_info(level))
	add_child(b)
	node_buttons[level] = b

	var tag := Label.new()
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", INK)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(120, 0)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if BossData.has_boss(level):
		var boss: Dictionary = BossData.for_level(level)
		tag.text = "%s\n%s" % [boss["name_cn"], boss["name_en"]]
	elif Levels.is_lava(level):
		tag.text = "熔岩 Lava"
	add_child(tag)
	_labels[level] = tag

func _make_footer_buttons() -> void:
	var reset := Button.new()
	reset.text = "重置进度 Reset progress"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void:
		Levels.reset_progress()
		_refresh())
	reset.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	reset.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	reset.grow_vertical = Control.GROW_DIRECTION_BEGIN
	reset.offset_right = -14.0
	reset.offset_bottom = -12.0
	add_child(reset)
	if OS.is_debug_build():
		_unlock_button = Button.new()
		_unlock_button.text = "解锁全部 Unlock all (debug)"
		_unlock_button.toggle_mode = true
		_unlock_button.button_pressed = Levels.unlock_all
		_unlock_button.focus_mode = Control.FOCUS_NONE
		_unlock_button.toggled.connect(func(on: bool) -> void:
			Levels.unlock_all = on
			_refresh())
		_unlock_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		_unlock_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_unlock_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_unlock_button.offset_right = -230.0
		_unlock_button.offset_bottom = -12.0
		add_child(_unlock_button)

func _layout() -> void:
	var pts := PackedVector2Array()
	for level in range(1, Levels.MAX_LEVEL + 1):
		var i: int = level - 1
		var row: int = floori(i / float(COLUMNS))
		var col: int = i % COLUMNS
		if row % 2 == 1:
			col = COLUMNS - 1 - col
		var p := Vector2(size.x * (0.14 + 0.18 * col), size.y * (0.30 + 0.17 * row))
		pts.append(p)
		node_buttons[level].position = p - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
		var above: bool = BossData.has_boss(level) and level < Levels.MAX_LEVEL
		_labels[level].position = p + Vector2(-60, -NODE_SIZE * 0.5 - 38.0 if above else NODE_SIZE * 0.5 + 2.0)
	_path.points = pts
	_info.position = Vector2(34, size.y - 40)

func _refresh() -> void:
	var unlocked: int = Levels.highest_unlocked()
	var cleared: int = Levels.highest_cleared()
	for level: int in node_buttons:
		var b: Button = node_buttons[level]
		var boss: bool = BossData.has_boss(level)
		var is_open: bool = level <= unlocked
		var done: bool = level <= cleared
		b.disabled = not is_open
		b.text = "✓" if done else str(level)
		var fill: Color = GOLD if done else (Color("fff4d6") if level == unlocked else (PARCHMENT if is_open else LOCKED))
		b.add_theme_stylebox_override("normal", _circle(fill, RED if boss else INK, 6 if level == unlocked else 4))
		b.add_theme_stylebox_override("hover", _circle(fill.lightened(0.25), RED if boss else INK, 6))
		b.add_theme_stylebox_override("pressed", _circle(fill.darkened(0.15), RED if boss else INK, 6))
		b.add_theme_stylebox_override("disabled", _circle(LOCKED, Color("6d6859"), 3))
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_disabled_color", Color("6d6859"))
	_info.text = "选择关卡  Select a level   (已通关 Cleared %d / %d)" % [cleared, Levels.MAX_LEVEL]

func _show_info(level: int) -> void:
	var text: String = "第 %d 关 Level %d" % [level, level]
	if BossData.has_boss(level):
		var boss: Dictionary = BossData.for_level(level)
		text += "  ·  Boss: %s %s" % [boss["name_cn"], boss["name_en"]]
	if Levels.is_lava(level):
		text += "  ·  熔岩地形 Lava terrain"
	_info.text = text

func _circle(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(int(NODE_SIZE * 0.5))
	return s

func _start(level: int) -> void:
	if level > Levels.highest_unlocked():
		return
	Levels.current_level = level
	get_tree().change_scene_to_file(BATTLE_SCENE)

# Dev helper: INK_SHOT=<png path> saves a screenshot of the map and quits.
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		var shot: String = OS.get_environment("INK_SHOT")
		if shot != "":
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png(shot)
			get_tree().quit()
