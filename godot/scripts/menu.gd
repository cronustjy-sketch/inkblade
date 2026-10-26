extends Control

# Main menu, following the web game's structure in the cartoon art style:
#   title + player card, big tiles "开始游戏 Play" and "模式 Modes", a quick row (装备 Gear, 商店 Shop, 军械库 Armory,
#   设置 Settings, 故事 Story, 起源 Origin, 制作团队 Credits).
# Screens that are not built yet (Gear / Shop / Armory) say so honestly; see FEATURES.md.

const Kit := preload("res://scripts/ui_kit.gd")
const GearView := preload("res://scripts/gear_view.gd")
const Levels := preload("res://data/levels.gd")
const Save := preload("res://scripts/save.gd")
const StoryData := preload("res://data/story_data.gd")
const StoryView := preload("res://scripts/story_view.gd")
const ChapterStory := preload("res://scripts/chapter_story.gd")
const OriginView := preload("res://scripts/origin_view.gd")
const BATTLE_SCENE: String = "res://scenes/battle.tscn"
const MAP_SCENE: String = "res://scenes/map.tscn"
const RAID_SCENE: String = "res://scenes/raid.tscn"
const GOLD := Kit.GOLD
const SKY := Kit.SKY

var _content: Control
var _overlay: Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := TextureRect.new()
	bg.texture = Kit.sky_texture(Color("3d9be9"), Color("c4ecff"))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var scenery := Control.new()
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scenery.draw.connect(_draw_scenery.bind(scenery))
	scenery.resized.connect(scenery.queue_redraw)
	add_child(scenery)
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_show_main()
	# First launch: the opening story.
	if not Save.intro_seen() and OS.get_environment("INK_NOINTRO") == "":
		_play_intro.call_deferred()

# ---------- screens ----------

func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()

func _center_box(separation: int = 14) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(box)
	return box

func _show_main() -> void:
	_clear()
	var box: VBoxContainer = _center_box(10)
	var title: Label = Kit.label("墨刃纪元", 92, Color.WHITE, 12, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub: Label = Kit.label("INK BLADE ERA", 24, GOLD, 7)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var cleared: int = Levels.highest_cleared()
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", Kit.flat(Kit.NAVY, Kit.OUTLINE, 4, 22, 10))
	box.add_child(card)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 14)
	card.add_child(card_row)
	card_row.add_child(Kit.bilingual("墨刃使", "Blade-bearer", 22, 12, Color.WHITE, Color("aab6d0"), 4, true, HORIZONTAL_ALIGNMENT_LEFT))
	card_row.add_child(Kit.label("已通关 Cleared  %d / %d" % [cleared, Levels.MAX_LEVEL], 17, GOLD, 4))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	box.add_child(gap)
	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 22)
	box.add_child(tiles)
	tiles.add_child(_big_tile("开始游戏", "Play", "2D 战役 · 3D 首领突袭", "2D campaign · 3D Boss Raid", GOLD, _show_play))
	tiles.add_child(_big_tile("模式", "Modes", "对决 · 守城 · 单挑 · 活动", "Duels · Defence · Solo · Events", SKY, _show_modes))

	var quick := HBoxContainer.new()
	quick.alignment = BoxContainer.ALIGNMENT_CENTER
	quick.add_theme_constant_override("separation", 14)
	box.add_child(quick)
	var items: Array = [
		["装", "装备", "Gear", Color("e0463b"), _open_gear],
		["店", "商店", "Shop", Color("6cc070"), _open_shop],
		["械", "军械库", "Armory", Color("8c93a3"), _open_armory],
		["设", "设置", "Settings", Color("5b9be6"), _show_settings],
		["故", "故事", "Story", Color("b46cff"), _show_stories],
		["起", "起源", "Origin", Color("ff8a5a"), _play_origin],
		["制", "制作团队", "Credits", Color("d8b060"), _show_credits],
	]
	for it: Array in items:
		quick.add_child(Kit.round_tile(it[0], it[1], it[2], it[3], 72.0, it[4]))

	var credit: Label = Kit.label("游戏制作：Junyuan · © 2026    Made by Junyuan", 15, Color.WHITE, 5)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(credit)

func _big_tile(cn: String, en: String, sub_cn: String, sub_en: String, fill: Color, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(380, 124)
	b.add_theme_stylebox_override("normal", Kit.flat(fill, Kit.OUTLINE, 6, 34))
	b.add_theme_stylebox_override("hover", Kit.flat(fill.lightened(0.22), Kit.OUTLINE, 6, 34))
	b.add_theme_stylebox_override("pressed", Kit.flat(fill.darkened(0.15), Kit.OUTLINE, 6, 34))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t: Label = Kit.label("%s  %s" % [cn, en], 34, Color.WHITE, 8, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var a: Label = Kit.label(sub_cn, 16, Kit.OUTLINE)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(a)
	var e: Label = Kit.label(sub_en, 12, Color(Kit.OUTLINE, 0.8))
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(e)
	b.pressed.connect(action)
	return b

func _header(cn: String, en: String) -> VBoxContainer:
	var box: VBoxContainer = _center_box(14)
	var title: VBoxContainer = Kit.bilingual(cn, en, 56, 22, Color.WHITE, GOLD, 9, true)
	box.add_child(title)
	return box

func _back_button() -> void:
	var back: Button = Kit.pill("返回", "Back", Kit.CREAM, Vector2(150, 54), _show_main, 20)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 22.0
	back.offset_top = 20.0
	back.offset_right = 172.0
	back.offset_bottom = 74.0
	_content.add_child(back)

func _show_play() -> void:
	_clear()
	_back_button()
	var box: VBoxContainer = _header("开始游戏", "Play")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	box.add_child(row)
	var next_level: int = mini(Levels.highest_unlocked(), Levels.MAX_LEVEL)
	row.add_child(_mode_card("2D", "墨刃纪元", "Ink Blade Era", "带领火柴人军团推进战线，打穿每一章的首领。", "Lead the stickman legion and beat every chapter's boss.", "继续 · 第 %d 关" % next_level, "Continue · Level %d" % next_level, GOLD, func() -> void: _start_level(next_level), "世界地图", "World map", _open_map))
	row.add_child(_mode_card("3D", "首领突袭", "Boss Raid", "亲手挥刀，在 3D 竞技场里一个接一个挑战首领。", "Swing the blade yourself and fight bosses one by one in a 3D arena.", "开始突袭", "Start the raid", SKY, _open_raid, "", "", Callable()))

func _mode_card(badge: String, cn: String, en: String, d_cn: String, d_en: String, main_cn: String, main_en: String, fill: Color, main_action: Callable, alt_cn: String, alt_en: String, alt_action: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.flat(Kit.CREAM, Kit.OUTLINE, 6, 30, 22))
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(380, 0)
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var badge_label: Label = Kit.label(badge, 30, Color.WHITE, 7, true)
	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", Kit.flat(fill, Kit.OUTLINE, 4, 16, 8))
	badge_panel.add_child(badge_label)
	head.add_child(badge_panel)
	head.add_child(Kit.bilingual(cn, en, 30, 14, Kit.OUTLINE, Kit.NAVY, 0, true, HORIZONTAL_ALIGNMENT_LEFT))
	var a: Label = Kit.label(d_cn, 16, Kit.NAVY)
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(a)
	var e: Label = Kit.label(d_en, 13, Color("4a5678"))
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(e)
	v.add_child(Kit.pill(main_cn, main_en, fill, Vector2(0, 62), main_action, 22))
	if alt_action.is_valid():
		v.add_child(Kit.pill(alt_cn, alt_en, Kit.CREAM.darkened(0.08), Vector2(0, 50), alt_action, 18))
	return panel

func _show_modes() -> void:
	_clear()
	_back_button()
	var box: VBoxContainer = _header("模式", "Modes")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	var cards: Array = [
		["战役", "Campaign", "2D 战线推进", "2D lane battles", GOLD, true, func() -> void: _open_map()],
		["首领突袭", "Boss Raid", "3D 首领连战", "3D boss ladder", SKY, true, _open_raid],
		["无尽守城", "Endless Defence", "能守几波？", "How many waves?", Color("5b9be6"), false, Callable()],
		["孤身一人", "On Your Own", "单挑巨型首领", "Duel a giant boss", Color("b46cff"), false, Callable()],
		["岩浆竞技场", "Lava Arena", "把对手踢进岩浆", "Kick your rival into lava", Color("e0703a"), false, Callable()],
		["在线对决", "Online Duels", "好友 · 排位赛（需要服务器）", "Friends and ranked (needs a server)", Color("8c93a3"), false, Callable()],
	]
	for c: Array in cards:
		var fill: Color = c[4] if c[5] else c[4].darkened(0.35)
		var b: Button = _big_tile(c[0], c[1], c[2], c[3], fill, c[6] if c[5] else func() -> void: _soon(c[0], c[1], "这个模式还没有移植过来。", "This mode is not ported yet."))
		b.custom_minimum_size = Vector2(300, 108)
		grid.add_child(b)

func _show_settings() -> void:
	_clear()
	_back_button()
	var box: VBoxContainer = _header("设置", "Settings")
	box.add_child(_toggle("墨效", "Ink effects", "ink_effects", Save.ink_effects()))
	box.add_child(_toggle("镜头震动", "Camera shake", "camera_shake", Save.camera_shake()))
	var reset: Button = Kit.pill("重置进度", "Reset progress", Color("e0463b"), Vector2(420, 58), _confirm_reset, 20)
	box.add_child(reset)
	var note: Label = Kit.label("语言：中文 + English 同时显示    Language: Chinese with English underneath", 14, Color.WHITE, 4)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)

func _toggle(cn: String, en: String, key: String, value: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(420, 62)
	b.toggle_mode = true
	b.button_pressed = value
	var state := Label.new()
	var refresh := func() -> void:
		state.text = "开 ON" if b.button_pressed else "关 OFF"
	b.add_theme_stylebox_override("normal", Kit.flat(Kit.CREAM.darkened(0.12), Kit.OUTLINE, 5, 31))
	b.add_theme_stylebox_override("pressed", Kit.flat(Kit.GREEN, Kit.OUTLINE, 5, 31))
	b.add_theme_stylebox_override("hover", Kit.flat(Kit.CREAM, Kit.OUTLINE, 5, 31))
	b.add_theme_stylebox_override("hover_pressed", Kit.flat(Kit.GREEN.lightened(0.2), Kit.OUTLINE, 5, 31))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24.0
	row.offset_right = -24.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var name_box: VBoxContainer = Kit.bilingual(cn, en, 22, 12, Kit.OUTLINE, Color("3a4056"), 0, false, HORIZONTAL_ALIGNMENT_LEFT)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(name_box)
	state.add_theme_font_size_override("font_size", 20)
	state.add_theme_color_override("font_color", Kit.OUTLINE)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(state)
	refresh.call()
	b.toggled.connect(func(on: bool) -> void:
		Save.set_value("settings", key, on)
		refresh.call())
	return b

func _confirm_reset() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.flat(Kit.CREAM, Kit.OUTLINE, 6, 28, 26))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(Kit.bilingual("重置进度？", "Reset progress?", 32, 16, Kit.RED, Kit.NAVY, 6, true))
	var a: Label = Kit.label("关卡进度、首领记录和故事进度都会被清空。\nAll level progress, boss records and story progress will be erased.", 16, Kit.NAVY)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(a)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	row.add_child(Kit.pill("取消", "Cancel", Kit.CREAM.darkened(0.1), Vector2(170, 54), func() -> void: dim.queue_free(), 18))
	row.add_child(Kit.pill("重置", "Reset", Kit.RED, Vector2(170, 54), func() -> void:
		Levels.reset_progress()
		Save.reset_all()
		var RaidData := load("res://data/raid.gd")
		RaidData.reset_records()
		dim.queue_free()
		_show_main(), 18))

# The story list: replay the opening, or any chapter story you have unlocked; shows which ones were seen.
func _show_stories() -> void:
	_clear()
	_back_button()
	var box: VBoxContainer = _header("故事", "Story")
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	box.add_child(list)
	list.add_child(_story_row("序章 · 墨之卷", "Prologue · The Scroll of Ink", Save.intro_seen(), true, _play_intro))
	for ch: Dictionary in StoryData.CHAPTERS:
		var n: int = int(ch["n"])
		if n > Levels.chapter_number(Levels.MAX_LEVEL):
			break
		var unlocked: bool = Levels.highest_unlocked() >= int(ch["a"])
		var cn_name: String = String(ch["t"])
		var en_name: String = String(ch["e"])
		list.add_child(_story_row(cn_name, en_name, Save.chapter_story_seen(n), unlocked, func() -> void: _play_chapter_story(n)))
	list.add_child(_story_row("起源", "Origin (video)", Save.origin_seen(), true, _play_origin))

func _story_row(cn: String, en: String, seen: bool, open: bool, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(620, 62)
	b.disabled = not open
	var fill: Color = Kit.CREAM if open else Kit.CREAM.darkened(0.3)
	b.add_theme_stylebox_override("normal", Kit.flat(fill, Kit.OUTLINE, 5, 31))
	b.add_theme_stylebox_override("hover", Kit.flat(fill.lightened(0.2), Kit.OUTLINE, 5, 31))
	b.add_theme_stylebox_override("pressed", Kit.flat(fill.darkened(0.12), Kit.OUTLINE, 5, 31))
	b.add_theme_stylebox_override("disabled", Kit.flat(fill, Color(Kit.OUTLINE, 0.5), 5, 31))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26.0
	row.offset_right = -26.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var name_box: VBoxContainer = Kit.bilingual(cn, en, 21, 12, Kit.OUTLINE, Color("3a4056"), 0, false, HORIZONTAL_ALIGNMENT_LEFT)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(name_box)
	var tag: Label = Kit.label("已看 Seen" if seen else ("未看 New" if open else "未解锁 Locked"), 15, Kit.GREEN.darkened(0.3) if seen else Kit.RED.darkened(0.1))
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)
	b.pressed.connect(action)
	return b

func _show_credits() -> void:
	_clear()
	_back_button()
	var box: VBoxContainer = _header("制作团队", "Credits")
	var l: Label = Kit.label("游戏制作 · Game by\nJunyuan\n\n© 2026", 30, Color.WHITE, 8, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)

func _soon(cn_title: String, en_title: String, cn: String, en: String) -> void:
	Kit.message_box(_overlay, cn_title, en_title, cn + "\n即将推出。", en + "\nComing soon.")

# ---------- actions ----------

func _play_intro() -> void:
	var view: Control = StoryView.new()
	_overlay.add_child(view)
	view.finished.connect(func() -> void: Save.mark_intro_seen())

func _play_origin() -> void:
	var view: Control = OriginView.new()
	_overlay.add_child(view)
	view.finished.connect(func() -> void: Save.mark_origin_seen())

func _play_chapter_story(n: int) -> void:
	var view: Control = ChapterStory.new()
	view.setup(n)
	_overlay.add_child(view)
	view.finished.connect(func() -> void: Save.mark_chapter_story_seen(n))

func _open_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)

func _open_raid() -> void:
	get_tree().change_scene_to_file(RAID_SCENE)

# Starting a level straight from the menu shows the chapter story first when it is the chapter's first level.
func _start_level(level: int) -> void:
	Levels.current_level = level
	if Levels.is_first_of_chapter(level) and not Save.chapter_story_seen(Levels.chapter_number(level)):
		var n: int = Levels.chapter_number(level)
		var view: Control = ChapterStory.new()
		view.setup(n)
		_overlay.add_child(view)
		view.finished.connect(func() -> void:
			Save.mark_chapter_story_seen(n)
			get_tree().change_scene_to_file(BATTLE_SCENE))
		return
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _draw_scenery(canvas: Control) -> void:
	var canvas_size: Vector2 = canvas.size
	canvas.draw_circle(Vector2(canvas_size.x * 0.82, canvas_size.y * 0.2), canvas_size.y * 0.12, Color("fff2a8"))
	var layers: Array = [[Color("9bd6b0"), 0.62, 0.10, 3.0], [Color("6cbf74"), 0.72, 0.09, 4.5], [Color("49a25a"), 0.84, 0.07, 6.0]]
	for i in layers.size():
		var layer: Array = layers[i]
		var pts := PackedVector2Array()
		var steps: int = 60
		for s in steps + 1:
			var x: float = canvas_size.x * s / steps
			var y: float = canvas_size.y * (layer[1] - layer[2] * (0.5 + 0.5 * sin(x / canvas_size.x * layer[3] * TAU * 0.5 + i * 1.7)))
			pts.append(Vector2(x, y))
		var poly := PackedVector2Array(pts)
		poly.append(Vector2(canvas_size.x, canvas_size.y))
		poly.append(Vector2(0.0, canvas_size.y))
		canvas.draw_colored_polygon(poly, layer[0])
		canvas.draw_polyline(pts, Color("1b3a2a"), 4.0, true)

func _open_gear() -> void:
	var view: Control = GearView.new()
	_overlay.add_child(view)
	view.closed.connect(func() -> void: view.queue_free())

func _open_shop() -> void:
	_open_view("shop")

func _open_armory() -> void:
	_open_view("armory")

func _open_view(mode: String) -> void:
	var view: Control = GearView.new()
	view.mode = mode
	_overlay.add_child(view)
	view.closed.connect(func() -> void: view.queue_free())
