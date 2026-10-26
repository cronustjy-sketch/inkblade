extends Control

# Boss Raid menu: pick a fight from the Fractured Realm ladder (the Eraser's five fragment guardians) or from the
# campaign boss list, read the boss's story line and moves, and choose the sword the hero carries.

signal chosen(kind: String, index: int)
signal sword_changed(id: String)
signal back_pressed

const Kit := preload("res://scripts/ui_kit.gd")
const RaidData := preload("res://data/raid.gd")
const Gb3 := preload("res://data/gb3_data.gd")
const BODY_NAMES: Dictionary = {
	"blade": ["剑", "剑客", "Swordsman"], "spirit": ["灵", "幽灵", "Wraith"], "giant": ["巨", "巨像", "Golem"],
	"brute": ["蛮", "蛮兽", "Brute"], "flyer": ["翼", "飞兽", "Flyer"],
}
const SWORD_NAMES: Dictionary = {
	"ink": ["墨刃", "Ink Blade"], "iron": ["铁剑", "Iron"], "blank": ["无字", "Blank"],
	"blood": ["血饮", "Bloodthirst"], "colossus": ["巨像", "Colossus"], "free": ["自由", "Free"],
}
const SWORD_ORDER: Array[String] = ["ink", "iron", "blank", "blood", "colossus", "free"]
const EXTRA_MOVES: Dictionary = {"hand": "灵魂之手", "paint": "画界"}
const COLUMNS: int = 3

var unlock_all: bool = false # debug: show every ladder fight as open
var _kind: String = "ladder"
var _selected: int = 0
var _grid: GridContainer
var _scroll: ScrollContainer
var _tab_buttons: Dictionary = {}
var _detail: VBoxContainer
var _sword_buttons: Dictionary = {}
var _cards: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.texture = Kit.sky_texture(Color("1f2a4d"), Color("5a3a6a"))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title: VBoxContainer = Kit.bilingual("3D 首领突袭", "3D Boss Raid", 40, 16, Color.WHITE, Kit.GOLD, 8, true, HORIZONTAL_ALIGNMENT_LEFT)
	title.position = Vector2(30, 10)
	add_child(title)
	var story: Label = Kit.label("「抹除者」的爪牙守在世界的裂缝里。打败它们，夺回被抹掉的东西。", 15, Color("ffe9a8"), 4)
	story.position = Vector2(300, 18)
	add_child(story)
	var story_en: Label = Kit.label("The Eraser's servants guard the rifts of the world. Beat them and take back what was erased.", 12, Color("d9e6ff"), 3)
	story_en.position = Vector2(300, 44)
	add_child(story_en)
	var back: Button = Kit.pill("返回", "Back", Kit.CREAM, Vector2(140, 52), func() -> void: back_pressed.emit(), 20)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -160.0
	back.offset_right = -20.0
	back.offset_top = 14.0
	back.offset_bottom = 66.0
	add_child(back)

	var tabs := HBoxContainer.new()
	tabs.position = Vector2(30, 84)
	tabs.add_theme_constant_override("separation", 12)
	add_child(tabs)
	_tab_buttons["ladder"] = Kit.pill("断裂之境", "Fractured Realm · 5", Kit.GOLD, Vector2(250, 52), func() -> void: _show_kind("ladder"), 20)
	_tab_buttons["campaign"] = Kit.pill("墨刃战役首领", "Campaign Bosses · %d" % RaidData.campaign_count(), Kit.SKY, Vector2(300, 52), func() -> void: _show_kind("campaign"), 20)
	tabs.add_child(_tab_buttons["ladder"])
	tabs.add_child(_tab_buttons["campaign"])

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(30, 146)
	_scroll.size = Vector2(720, 380)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)

	var panel := PanelContainer.new()
	panel.position = Vector2(770, 146)
	panel.size = Vector2(356, 380)
	panel.add_theme_stylebox_override("panel", Kit.flat(Kit.CREAM, Kit.OUTLINE, 5, 22, 16))
	add_child(panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	panel.add_child(_detail)

	var swords := HBoxContainer.new()
	swords.position = Vector2(30, 548)
	swords.add_theme_constant_override("separation", 8)
	add_child(swords)
	var label: VBoxContainer = Kit.bilingual("英雄的剑", "Hero sword", 18, 12, Color.WHITE, Color("d9e6ff"), 4, false, HORIZONTAL_ALIGNMENT_LEFT)
	label.custom_minimum_size = Vector2(120, 0)
	swords.add_child(label)
	for id: String in SWORD_ORDER:
		var names: Array = SWORD_NAMES[id]
		var b: Button = Kit.pill(names[0], names[1], Kit.CREAM, Vector2(120, 50), _pick_sword.bind(id), 17)
		swords.add_child(b)
		_sword_buttons[id] = b
	_refresh_swords()
	_show_kind("ladder")

func _show_kind(kind: String) -> void:
	_kind = kind
	_selected = 0
	for k: String in _tab_buttons:
		(_tab_buttons[k] as Button).modulate = Color.WHITE if k == kind else Color(0.7, 0.7, 0.75)
	for c: Node in _grid.get_children():
		c.queue_free()
	_cards.clear()
	var count: int = RaidData.count_for(kind)
	for i in count:
		var card: Button = _make_card(i)
		_grid.add_child(card)
		_cards.append(card)
	_select(_first_open())

func _first_open() -> int:
	for i in RaidData.count_for(_kind):
		if _is_open(i) and not RaidData.cleared(RaidData.config_for(_kind, i)["id"]):
			return i
	return 0

func _is_open(index: int) -> bool:
	if _kind != "ladder" or unlock_all or index == 0:
		return true
	return RaidData.cleared(RaidData.config_for("ladder", index - 1)["id"])

func _make_card(index: int) -> Button:
	var cfg: Dictionary = RaidData.config_for(_kind, index)
	var open: bool = _is_open(index)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(228, 74)
	var fill: Color = Kit.CREAM if open else Color("b9b2a0")
	var done: bool = RaidData.cleared(cfg["id"])
	if done:
		fill = Color("ffe9a8")
	b.add_theme_stylebox_override("normal", Kit.flat(fill, Kit.OUTLINE, 4, 18))
	b.add_theme_stylebox_override("hover", Kit.flat(fill.lightened(0.25), Kit.OUTLINE, 4, 18))
	b.add_theme_stylebox_override("pressed", Kit.flat(fill.darkened(0.15), Kit.OUTLINE, 4, 18))
	b.pressed.connect(_select.bind(index))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_top = 6.0
	row.offset_bottom = -6.0
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var body: Array = BODY_NAMES.get(cfg["body"], ["?", "?", "?"])
	var colors: Array = cfg["colors"]
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(46, 46)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", Kit.flat((colors[1] as Color).lerp(colors[0], 0.25) if open else Color("8c93a3"), Kit.OUTLINE, 3, 23))
	var glyph: Label = Kit.label(body[0] if open else "锁", 24, Color.WHITE, 5, true)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(glyph)
	row.add_child(badge)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_cn: Label = Kit.label(cfg["cn"], 17, Kit.OUTLINE)
	name_cn.clip_text = true
	text.add_child(name_cn)
	var name_en: Label = Kit.label(cfg["en"], 12, Color(Kit.OUTLINE, 0.75))
	name_en.clip_text = true
	text.add_child(name_en)
	var best: float = RaidData.best_time(cfg["id"])
	var status: String = "最佳 Best %d:%05.2f" % [floori(best / 60.0), fmod(best, 60.0)] if best > 0.0 else ("未通关 Not cleared" if open else "未解锁 Locked")
	text.add_child(Kit.label(status, 11, Color("4a5678")))
	return b

func _select(index: int) -> void:
	_selected = index
	for i in _cards.size():
		_cards[i].modulate = Color(1.0, 1.0, 1.0) if i == index else Color(0.82, 0.82, 0.86)
	_fill_detail()

func _move_names(ids: Array) -> String:
	var parts: PackedStringArray = []
	for id: String in ids:
		if Gb3.MOVE_NAMES.has(id):
			parts.append(String((Gb3.MOVE_NAMES[id] as Dictionary)["cn"]))
		else:
			parts.append(String(EXTRA_MOVES.get(id, id)))
	return " · ".join(parts)

func _fill_detail() -> void:
	for c: Node in _detail.get_children():
		c.queue_free()
	var cfg: Dictionary = RaidData.config_for(_kind, _selected)
	_detail.add_child(Kit.bilingual(cfg["cn"], cfg["en"], 24, 14, Kit.GOLD.darkened(0.2), Kit.NAVY, 0, true, HORIZONTAL_ALIGNMENT_LEFT))
	var open: bool = _is_open(_selected)
	var lore: String = cfg.get("lore", cfg.get("tip", ""))
	var lore_en: String = cfg.get("lore_en", "")
	_detail.add_child(_wrapped(lore, 14, Kit.NAVY))
	if lore_en != "":
		_detail.add_child(_wrapped(lore_en, 12, Color("4a5678")))
	if cfg.has("say"):
		_detail.add_child(_wrapped("“%s”" % cfg["say"], 15, Kit.RED.darkened(0.1)))
		_detail.add_child(_wrapped(cfg["say_en"], 12, Color("4a5678")))
	_detail.add_child(_wrapped("招式 Moves：" + _move_names(cfg["moves"]), 13, Kit.NAVY))
	if (cfg["moves2"] as Array).size() > 0:
		_detail.add_child(_wrapped("第二阶段 Phase 2：" + _move_names(cfg["moves2"]), 13, Kit.RED.darkened(0.2)))
	_detail.add_child(_wrapped("生命 HP %d" % int(cfg["hp"]), 12, Color("4a5678")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(spacer)
	var go: Button = Kit.pill("开战", "Fight!", Kit.GOLD if open else Color("b9b2a0"), Vector2(240, 54), func() -> void: chosen.emit(_kind, _selected), 22)
	go.disabled = not open
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail.add_child(go)

func _wrapped(text: String, size: int, color: Color) -> Label:
	var l: Label = Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	return l

func _pick_sword(id: String) -> void:
	RaidData.set_sword(id)
	sword_changed.emit(id)
	_refresh_swords()

func _refresh_swords() -> void:
	var current: String = RaidData.get_sword()
	for id: String in _sword_buttons:
		var b: Button = _sword_buttons[id]
		b.modulate = Color.WHITE if id == current else Color(0.62, 0.62, 0.68)
		var fill: Color = Kit.GOLD if id == current else Kit.CREAM
		b.add_theme_stylebox_override("normal", Kit.flat(fill, Kit.OUTLINE, 5, 25))
