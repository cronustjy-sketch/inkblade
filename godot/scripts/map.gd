extends Control

# Level-select map. One band per chapter (chapter name + intro on top, ten level stops under it), cartoon style.
# Progress is stored by data/levels.gd; chapter stories play before a chapter's first level (once).

const Levels := preload("res://data/levels.gd")
const BossData := preload("res://data/bosses.gd")
const Kit := preload("res://scripts/ui_kit.gd")
const Save := preload("res://scripts/save.gd")
const StoryData := preload("res://data/story_data.gd")
const ChapterStory := preload("res://scripts/chapter_story.gd")
const BATTLE_SCENE: String = "res://scenes/battle.tscn"
const MENU_SCENE: String = "res://scenes/menu.tscn"
const NODE_SIZE: float = 62.0
const PER_ROW: int = 10
const LOCKED := Color("b9b2a0")

var node_buttons: Dictionary = {}
var _bands: Array[Dictionary] = [] # {top, line: Line2D, header: Control, chapter}
var _info: Label
var _unlock_button: Button
var _overlay: Control

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = Kit.sky_texture(Color("3d9be9"), Color("c4ecff"))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var ground := ColorRect.new()
	ground.color = Color("6cc070")
	ground.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ground.offset_top = -90.0
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var title: VBoxContainer = Kit.bilingual("墨刃纪元", "Ink Blade Era", 44, 16, Color.WHITE, Kit.GOLD, 8, true, HORIZONTAL_ALIGNMENT_LEFT)
	title.position = Vector2(200, 12)
	add_child(title)
	var back: Button = Kit.pill("返回", "Back", Kit.CREAM, Vector2(150, 54), _back, 20)
	back.position = Vector2(22, 22)
	add_child(back)

	for chapter_n in range(1, Levels.chapter_number(Levels.MAX_LEVEL) + 1):
		_make_band(chapter_n)
	for level in range(1, Levels.MAX_LEVEL + 1):
		_make_node(level)

	_info = Kit.label("", 17, Color.WHITE, 5)
	add_child(_info)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_make_footer()
	resized.connect(_layout)
	_refresh()
	_layout()

func _chapter(n: int) -> Dictionary:
	for c: Dictionary in StoryData.CHAPTERS:
		if int(c["n"]) == n:
			return c
	return {}

# Header text for a chapter: bilingual name and intro (or rule text) under it.
func _make_band(chapter_n: int) -> void:
	var c: Dictionary = _chapter(chapter_n)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cn_name: String = String(c.get("t", "第 %d 章" % chapter_n))
	var en_name: String = String(c.get("e", "Chapter %d" % chapter_n))
	header.add_child(Kit.bilingual(cn_name, en_name, 26, 14, Color.WHITE, Color("e8f2ff"), 6, true, HORIZONTAL_ALIGNMENT_LEFT))
	var rule_cn: String = String(c.get("intro", ""))
	var rule_en: String = String(c.get("intro_en", ""))
	var d_cn: String = String(c.get("d", ""))
	var d_en: String = String(c.get("d_en", ""))
	var l1: Label = Kit.label(rule_cn if rule_cn != "" else d_cn, 14, Color.WHITE, 4)
	l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l1.custom_minimum_size = Vector2(900, 0)
	header.add_child(l1)
	var l2: Label = Kit.label(rule_en if rule_en != "" else d_en, 12, Color("d9e6ff"), 3)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size = Vector2(900, 0)
	header.add_child(l2)
	add_child(header)
	var line := Line2D.new()
	line.width = 12.0
	line.default_color = Kit.OUTLINE
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	_bands.append({"chapter": chapter_n, "header": header, "line": line})

func _make_node(level: int) -> void:
	var b := Button.new()
	b.text = str(level)
	b.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	b.size = Vector2(NODE_SIZE, NODE_SIZE)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Kit.OUTLINE)
	b.add_theme_color_override("font_hover_color", Kit.OUTLINE)
	b.add_theme_color_override("font_disabled_color", Color("6d6859"))
	b.pressed.connect(func() -> void: _start(level))
	b.mouse_entered.connect(func() -> void: _show_info(level))
	add_child(b)
	node_buttons[level] = b
	if BossData.has_boss(level):
		var boss: Dictionary = BossData.for_level(level)
		var tag: VBoxContainer = Kit.bilingual(boss["name_cn"], boss["name_en"], 14, 10, Color.WHITE, Color("ffd0c8"), 4, false)
		tag.set_meta("level", level)
		tag.custom_minimum_size = Vector2(120, 0)
		add_child(tag)
		b.set_meta("tag", tag)

func _make_footer() -> void:
	var reset: Button = Kit.pill("重置进度", "Reset progress", Kit.CREAM.darkened(0.05), Vector2(200, 46), func() -> void:
		Levels.reset_progress()
		_refresh(), 16)
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
	var bands: int = _bands.size()
	var usable_top: float = 92.0
	var usable_h: float = maxf(size.y - usable_top - 100.0, 300.0)
	var band_h: float = usable_h / bands
	for bi in bands:
		var band: Dictionary = _bands[bi]
		var top: float = usable_top + band_h * bi
		(band["header"] as Control).position = Vector2(40, top)
		var pts := PackedVector2Array()
		var chapter_n: int = band["chapter"]
		var first: int = (chapter_n - 1) * 10 + 1
		var row_y: float = top + band_h * 0.72
		for k in PER_ROW:
			var level: int = first + k
			if level > Levels.MAX_LEVEL:
				break
			var x: float = size.x * (0.07 + 0.86 * float(k) / (PER_ROW - 1))
			var y: float = row_y + sin(k * 1.1 + bi) * 14.0
			var p := Vector2(x, y)
			pts.append(p)
			var b: Button = node_buttons[level]
			b.position = p - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
			if b.has_meta("tag"):
				var tag: Control = b.get_meta("tag")
				tag.position = p + Vector2(-60, NODE_SIZE * 0.5 + 2.0)
		(band["line"] as Line2D).points = pts
	_info.position = Vector2(30, size.y - 52)

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
		var fill: Color = Kit.GOLD if done else (Color("fff4d6") if level == unlocked else (Kit.CREAM if is_open else LOCKED))
		var ring: Color = Kit.RED if boss else Kit.OUTLINE
		var r: int = int(NODE_SIZE * 0.5)
		b.add_theme_stylebox_override("normal", Kit.flat(fill, ring, 6 if level == unlocked else 5, r))
		b.add_theme_stylebox_override("hover", Kit.flat(fill.lightened(0.25), ring, 6, r))
		b.add_theme_stylebox_override("pressed", Kit.flat(fill.darkened(0.15), ring, 6, r))
		b.add_theme_stylebox_override("disabled", Kit.flat(LOCKED, Color("6d6859"), 4, r))
	_info.text = "已通关 Cleared %d / %d     点击关卡开始   Click a level to play" % [cleared, Levels.MAX_LEVEL]

func _show_info(level: int) -> void:
	var text: String = "第 %d 关  Level %d" % [level, level]
	if BossData.has_boss(level):
		var boss: Dictionary = BossData.for_level(level)
		text += "   首领 Boss: %s %s" % [boss["name_cn"], boss["name_en"]]
	if Levels.is_lava(level):
		text += "   熔岩地形 Lava terrain"
	_info.text = text

func _back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

# Starts a level. Before the first level of a chapter the chapter story plays (once).
func _start(level: int) -> void:
	if level > Levels.highest_unlocked():
		return
	Levels.current_level = level
	var n: int = Levels.chapter_number(level)
	if Levels.is_first_of_chapter(level) and not Save.chapter_story_seen(n):
		var view: Control = ChapterStory.new()
		view.setup(n)
		_overlay.add_child(view)
		view.finished.connect(func() -> void:
			Save.mark_chapter_story_seen(n)
			get_tree().change_scene_to_file(BATTLE_SCENE))
		return
	get_tree().change_scene_to_file(BATTLE_SCENE)
