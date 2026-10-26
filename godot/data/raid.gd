extends RefCounted

# Data for the 3D Boss Raid. Two boss lists, both from the web game:
#   BOSSES   the Fractured Realm ladder (赤狱 / 墨岳 / 无相 / 天裂龙 / 断界之主): the Eraser's five fragment guardians,
#            which use the user's own models (data from FRB in public/index.html)
#   campaign the 3D campaign bosses (GB3, generated into data/gb3_data.gd), built from primitive parts
# Move ids are implemented in scripts/raid_boss.gd (_mv_<id>). Distances are meters, times seconds.

const Gb3 := preload("res://data/gb3_data.gd")
const SAVE_DEFAULT: String = "user://raid.cfg"
static var save_path: String = SAVE_DEFAULT

const ANIMS: Dictionary = {"idle": "idle", "walk": "walk", "run": "run", "slash": "slash", "swipe": "swipe", "slam": "slam", "roar": "roar", "hit": "hit"}

# One entry per ladder fight, in order. "lore" is the story line shown before the fight, "say" what the boss says.
const BOSSES: Array[Dictionary] = [
	{
		"id": "warden", "cn": "赤狱 · 赤裂守卫", "en": "The Crimson Warden", "tip": "第一块碎片的守护者 · The guardian of the first shard",
		"lore": "它曾是「原初封印」的第一道锁。裂缝打开的那天，它的铠甲开始渗出红光——它说，这是锁在流血。",
		"lore_en": "It was the first lock of the Original Seal. The day the rift opened, its armour began to bleed red light.",
		"say": "……锁，不需要理由。", "say_en": "...A lock needs no reason.",
		"model": "res://models/warden_anim.glb", "scale": 3.0, "yaw": 180.0, "brightness": 1.2, "anims": ANIMS,
		"body": "blade", "colors": [Color("0a0a0a"), Color("ff2a1a"), Color("ff6a4a")], "parts": ["horns", "plates", "mask"],
		"moves": ["cross", "dash", "blink", "spin"], "moves2": ["fan", "cross"],
		"hp": 2400.0, "speed": 4.6, "dm": 1.0, "cd": 0.95, "chain": 0.35,
		"hit_radius": 2.3, "hit_height": 4.4, "flying": false,
	},
	{
		"id": "colossus", "cn": "墨岳 · 墨之巨像", "en": "The Ink Colossus", "tip": "世界之下的囚徒 · The prisoner beneath the world",
		"lore": "它被关在世界的下面一千年。它的身体是墨和石头做的，只有胸口的核心还在发光。",
		"lore_en": "It was locked beneath the world for a thousand years. Its body is ink and stone; only the core in its chest still glows.",
		"say": "……我等了一千年。", "say_en": "...I waited a thousand years.",
		"model": "res://models/colossus_anim.glb", "scale": 3.4, "yaw": 180.0, "brightness": 1.2, "anims": ANIMS,
		"body": "giant", "colors": [Color("111118"), Color("3a8aff"), Color("8ad0ff")], "parts": ["plates", "crown", "horns"],
		"moves": ["slam", "wave", "pillars", "meteor", "hand"], "moves2": ["pull"],
		"hp": 3200.0, "speed": 3.2, "dm": 1.0, "cd": 1.4, "chain": 0.0,
		"hit_radius": 2.9, "hit_height": 5.4, "flying": false,
	},
	{
		"id": "faceless", "cn": "无相 · 无面剑士", "en": "The Faceless Duelist", "tip": "会学习的剑士 · The swordsman who learns",
		"lore": "没有人见过它的脸。它和每一个对手打过，记住了每一种招式。",
		"lore_en": "No one has seen its face. It has fought every opponent and remembers every move.",
		"say": "……你的下一招，我已经见过了。", "say_en": "...I have already seen your next move.",
		"model": "res://models/faceless_anim.glb", "scale": 3.0, "yaw": 180.0, "brightness": 1.2, "anims": ANIMS,
		"body": "blade", "colors": [Color("050507"), Color("8a5aff"), Color("ffffff")], "parts": ["mask", "scarf2", "hat"],
		"moves": ["blink", "cross", "dash", "fan", "spin"], "moves2": ["orbit"],
		"hp": 3800.0, "speed": 5.2, "dm": 1.0, "cd": 0.85, "chain": 0.4,
		"hit_radius": 1.8, "hit_height": 4.6, "flying": false,
	},
	{
		"id": "dragon", "cn": "天裂龙 · 世界之隙", "en": "The Rift Dragon", "tip": "世界之间的毁灭者 · The destroyer between worlds",
		"lore": "它住在两个世界之间的裂缝里。它每呼吸一次，就有一个世界裂开一道口子。",
		"lore_en": "It lives in the crack between two worlds. Every breath it takes splits another world open.",
		"say": "……这个世界，也会裂开。", "say_en": "...This world will split too.",
		"model": "res://models/dragon.glb", "scale": 4.6, "yaw": 90.0, "brightness": 1.2, "anims": {},
		"body": "flyer", "colors": [Color("050510"), Color("3ad0ff"), Color("ffffff")], "parts": ["horns", "wings"],
		"moves": ["beam", "dash", "meteor", "orbit"], "moves2": ["rain", "pull"],
		"hp": 4600.0, "speed": 4.2, "dm": 1.0, "cd": 1.1, "chain": 0.0,
		"hit_radius": 5.2, "hit_height": 3.4, "flying": true, "hover": 6.0, "keep": 11.0, "orbit": 11.0,
	},
	{
		"id": "ender", "cn": "断界之主", "en": "The Realm-Ender", "tip": "打碎世界的人 · The one who broke the world",
		"lore": "没有脸，只有金色的裂痕和一支巨大的笔。它不是在毁灭世界——它在找一个人。",
		"lore_en": "No face, only golden cracks and a huge brush. It is not destroying the world: it is looking for someone.",
		"say": "……你就是那个被画出来的孩子。", "say_en": "...You are the child who was drawn.",
		"model": "res://models/ender.glb", "scale": 2.4, "yaw": 90.0, "brightness": 1.2, "anims": {},
		"body": "blade", "colors": [Color("0a0a0a"), Color("ffd36b"), Color("ffffff")], "parts": ["brush", "plates", "halo", "mask"],
		"moves": ["stroke", "paint", "cross", "slam", "blink", "beam"], "moves2": ["meteor", "pillars", "orbit", "rain"],
		"hp": 5600.0, "speed": 4.4, "dm": 1.0, "cd": 0.9, "chain": 0.4,
		"hit_radius": 1.6, "hit_height": 4.4, "flying": false,
	},
]

# ---------- campaign bosses (GB3) ----------

const MODEL_BLADES: Array[String] = ["res://models/warden_anim.glb", "res://models/faceless_anim.glb"]
const MODEL_GIANT: String = "res://models/colossus_anim.glb"
const Body := preload("res://scripts/raid_body.gd")

static func campaign_count() -> int:
	return Gb3.BOSSES.size()

# The Godot health pool for a web boss HP (web values assume a much stronger hero).
static func scaled_hp(web_hp: float) -> float:
	if web_hp <= 3000.0:
		return web_hp * 0.9
	return minf(2700.0 + (web_hp - 3000.0) * 0.15, 4800.0)

# A boss config (same keys as BOSSES entries) for campaign boss `i` (0-based).
static func campaign_boss(i: int) -> Dictionary:
	var g: Dictionary = Gb3.BOSSES[clampi(i, 0, Gb3.BOSSES.size() - 1)]
	var body: String = g["body"]
	var cfg: Dictionary = {
		"id": "gb3_%d" % i, "cn": g["name_cn"], "en": g["name_en"], "tip": g["tip_cn"],
		"body": body, "colors": g["colors"], "parts": g["parts"], "moves": (g["moves"] as Array).duplicate(), "moves2": (g["moves2"] as Array).duplicate(),
		"hp": scaled_hp(float(g["hp"])), "speed": minf(float(g["speed"]) * 0.8, 5.2), "dm": 1.0, "cd": 1.9, "chain": 0.0,
		"scale": 1.0, "yaw": 0.0, "brightness": 1.2, "anims": {}, "flying": false,
	}
	if body == "giant" and not (cfg["moves"] as Array).has("hand") and not (cfg["moves2"] as Array).has("hand"):
		(cfg["moves2"] as Array).append("hand")
	var gc: Array = g["colors"]
	var tint: Color = Color.WHITE.lerp(gc[1], 0.4)
	match body:
		"giant":
			cfg.merge({"model": MODEL_GIANT, "scale": 3.4, "yaw": 180.0, "anims": ANIMS, "tint": tint, "hit_radius": 2.9, "hit_height": 5.4}, true)
		"blade":
			cfg.merge({"model": MODEL_BLADES[i % 2], "scale": 3.0, "yaw": 180.0, "anims": ANIMS, "tint": tint, "hit_radius": 1.9, "hit_height": 4.5}, true)
		_:
			var s: float = Body.scale_for(body)
			cfg.merge({"hit_radius": 0.5 + s * 0.6, "hit_height": s * 2.4}, true)
	return cfg

# Config for a fight in either list: kind "ladder" or "campaign".
static func config_for(kind: String, index: int) -> Dictionary:
	if kind == "campaign":
		return campaign_boss(index)
	return BOSSES[clampi(index, 0, BOSSES.size() - 1)]

static func count_for(kind: String) -> int:
	return campaign_count() if kind == "campaign" else BOSSES.size()

static func best_time(id: String) -> float:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return 0.0
	return float(cfg.get_value("best", id, 0.0))

# Stores the time if it is the first clear or faster than the old record. Returns true for a new record.
static func record(id: String, seconds: float) -> bool:
	var old: float = best_time(id)
	if old > 0.0 and seconds >= old:
		return false
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("best", id, seconds)
	cfg.save(save_path)
	return true

static func cleared(id: String) -> bool:
	return best_time(id) > 0.0

static func reset_records() -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	if cfg.has_section("best"):
		cfg.erase_section("best")
	cfg.save(save_path)

# The sword the hero carries (models/sw_*.glb), chosen in the raid menu.
static func get_sword() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return "ink"
	return String(cfg.get_value("hero", "sword", "ink"))

static func set_sword(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("hero", "sword", id)
	cfg.save(save_path)
