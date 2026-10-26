extends Control

# 装备 Gear screen (menu overlay): pick or buy a hero, upgrade gear with coins and read the growth levels.
# All data and costs live in data/progress.gd.

signal closed

const Kit := preload("res://scripts/ui_kit.gd")
const Progress := preload("res://data/progress.gd")

var _tab: String = "heroes"
var _body: Control
var _coins: Label
var _tab_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.15, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var title: VBoxContainer = Kit.bilingual("装备", "Gear", 40, 16, Color.WHITE, Kit.GOLD, 8, true, HORIZONTAL_ALIGNMENT_LEFT)
	title.position = Vector2(30, 10)
	add_child(title)
	_coins = Kit.label("", 24, Kit.GOLD, 5)
	_coins.position = Vector2(300, 26)
	add_child(_coins)
	var back: Button = Kit.pill("返回", "Back", Kit.CREAM, Vector2(140, 52), func() -> void: closed.emit(), 20)
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
	for t: Array in [["heroes", "英雄", "Heroes"], ["gear", "装备", "Gear"], ["growth", "成长", "Growth"]]:
		var b: Button = Kit.pill(t[1], t[2], Kit.SKY, Vector2(170, 52), _show.bind(t[0]), 20)
		tabs.add_child(b)
		_tab_buttons[t[0]] = b
	_body = Control.new()
	_body.position = Vector2(30, 148)
	_body.size = Vector2(1090, 480)
	add_child(_body)
	_show("heroes")

func _show(tab: String) -> void:
	_tab = tab
	_coins.text = "金币 Coins  %d" % Progress.coins()
	for k: String in _tab_buttons:
		(_tab_buttons[k] as Button).modulate = Color.WHITE if k == tab else Color(0.7, 0.7, 0.75)
	for c: Node in _body.get_children():
		c.queue_free()
	match tab:
		"heroes":
			_build_heroes()
		"gear":
			_build_gear()
		_:
			_build_growth()

func _card(w: float, h: float, fill: Color) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, h)
	p.add_theme_stylebox_override("panel", Kit.flat(fill, Kit.OUTLINE, 4, 18, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	_flow.add_child(p)
	return v

var _flow: HFlowContainer

func _new_flow() -> void:
	_flow = HFlowContainer.new()
	_flow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flow.add_theme_constant_override("h_separation", 12)
	_flow.add_theme_constant_override("v_separation", 12)
	_body.add_child(_flow)

func _wrap(text: String, size: int, color: Color, width: float) -> Label:
	var l: Label = Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l

func _build_heroes() -> void:
	_new_flow()
	var current: String = Progress.selected_hero()
	for id: String in Progress.HERO_ORDER:
		var h: Dictionary = Progress.HEROES[id]
		var owned: bool = Progress.owns_hero(id)
		var v: VBoxContainer = _card(340, 216, Color("ffe9a8") if id == current else Kit.CREAM)
		v.add_child(Kit.bilingual(h["cn"], h["en"], 22, 13, Kit.OUTLINE, Color("4a5678"), 0, true, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(_wrap(h["d_cn"], 14, Kit.NAVY, 310))
		v.add_child(_wrap("HP %d · ATK %d · 速度 Speed %d · 射程 Range %d" % [h["hp"], h["atk"], h["speed"], h["range"]], 12, Color("4a5678"), 310))
		v.add_child(_wrap("G 专属技 %s %s (%ds)" % [h["ex_cn"], h["ex_en"], int(h["ex_cd"])], 13, Kit.RED.darkened(0.2), 310))
		var action: Button
		if id == current:
			action = Kit.pill("使用中", "In use", Color("b9b2a0"), Vector2(200, 44), func() -> void: pass, 18)
			action.disabled = true
		elif owned:
			action = Kit.pill("使用", "Use", Kit.GOLD, Vector2(200, 44), func() -> void:
				Progress.select_hero(id)
				_show("heroes"), 18)
		else:
			action = Kit.pill("购买 %d 金币" % h["price"], "Buy", Kit.GREEN, Vector2(200, 44), func() -> void:
				Progress.buy_hero(id)
				_show("heroes"), 18)
			action.disabled = Progress.coins() < int(h["price"])
		v.add_child(action)

func _build_gear() -> void:
	_new_flow()
	for id: String in Progress.GEAR_ORDER:
		var g: Dictionary = Progress.GEAR[id]
		var level: int = Progress.gear(id)
		var v: VBoxContainer = _card(260, 150, Kit.CREAM)
		v.add_child(Kit.bilingual(g["cn"], g["en"], 20, 12, Kit.OUTLINE, Color("4a5678"), 0, false, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(_wrap(g["d_cn"], 12, Kit.NAVY, 236))
		v.add_child(Kit.label("Lv %d / %d" % [level, Progress.GEAR_MAX], 15, Kit.OUTLINE))
		var maxed: bool = level >= Progress.GEAR_MAX
		var cost: int = Progress.gear_cost(id)
		var buy: Button = Kit.pill("已满级" if maxed else "升级 %d 金币" % cost, "Max" if maxed else "Upgrade", Kit.GOLD, Vector2(220, 40), func() -> void:
			Progress.buy_gear(id)
			_show("gear"), 16)
		buy.disabled = maxed or Progress.coins() < cost
		v.add_child(buy)

func _build_growth() -> void:
	_new_flow()
	for key: String in Progress.GROWTH_ORDER:
		var g: Dictionary = Progress.GROWTH[key]
		var v: VBoxContainer = _card(520, 120, Kit.CREAM)
		v.add_child(Kit.bilingual("%s %s   Lv %d" % [g["cn"], g["en"], Progress.growth(key)], g["d_en"], 22, 13, Kit.OUTLINE, Color("4a5678"), 0, false, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(_wrap(g["d_cn"], 14, Kit.NAVY, 490))
	var note: Label = _wrap("每首次通关一关，就可以选一条成长路线（胜利画面）。 Clear a level for the first time to pick a path on the victory screen.", 15, Color.WHITE, 1000)
	_flow.add_child(note)
