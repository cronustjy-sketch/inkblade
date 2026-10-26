extends RefCounted

# Permanent progression ported from the web game: coins, the four growth paths (力量 / 防御 / 速度 / 统帅), the five
# heroes and the eight gear items. Everything is stored through scripts/save.gd (section "econ"). `mods()` turns it
# into the multipliers the 2D battle uses, with the same formulas as the web game's mods().

const Save := preload("res://scripts/save.gd")

const GROWTH: Dictionary = {
	"str": {"cn": "力量", "en": "Strength", "d_cn": "所有士兵攻击 +15%，怒斩伤害提升。", "d_en": "All soldiers +15% attack, stronger Slash."},
	"def": {"cn": "防御", "en": "Defense", "d_cn": "所有士兵生命 +15%，基地生命 +60。", "d_en": "All soldiers +15% HP, base +60 HP."},
	"spd": {"cn": "速度", "en": "Speed", "d_cn": "移动与攻击速度 +10%，技能冷却缩短。", "d_en": "+10% move speed, shorter skill cooldowns."},
	"cmd": {"cn": "统帅", "en": "Command", "d_cn": "军队上限 +2（最多 +4），能量恢复 +1.5/秒。", "d_en": "Army cap +1 (max +4), energy regen +1.5/s."},
}
const GROWTH_ORDER: Array[String] = ["str", "def", "spd", "cmd"]

# Hero stats are the web values scaled to the Godot hero (blade = the existing UnitData.HERO). Ranges are pixels.
const HEROES: Dictionary = {
	"blade": {"cn": "金焰剑客", "en": "Flame Swordsman", "d_cn": "均衡型 · 每第3击暴击 ×2.2", "d_en": "Balanced · every 3rd hit crits x2.2", "price": 0,
		"hp": 400.0, "atk": 22.0, "speed": 120.0, "cooldown": 0.6, "range": 60.0, "tint": Color.WHITE, "scale": 1.0,
		"ex_cn": "旋风斩", "ex_en": "Whirlwind", "ex_cd": 14.0},
	"knight": {"cn": "重甲骑士", "en": "Iron Knight", "d_cn": "受到伤害 -50% · 血最厚", "d_en": "Takes 50% less damage · most HP", "price": 400,
		"hp": 760.0, "atk": 18.0, "speed": 89.0, "cooldown": 0.7, "range": 60.0, "armor": 0.5, "tint": Color("9fb4d8"), "scale": 1.1,
		"ex_cn": "钢铁壁垒", "ex_en": "Iron Wall", "ex_cd": 20.0},
	"assassin": {"cn": "疾影刺客", "en": "Shadow Assassin", "d_cn": "速度最快 · 40% 暴击 ×2.5", "d_en": "Fastest · 40% crit x2.5", "price": 500,
		"hp": 283.0, "atk": 26.0, "speed": 187.0, "cooldown": 0.41, "range": 52.0, "crit": 0.4, "tint": Color("c8a0ff"), "scale": 0.95,
		"ex_cn": "影袭", "ex_en": "Shadow Strike", "ex_cd": 15.0},
	"mage": {"cn": "烈焰法师", "en": "Flame Mage", "d_cn": "远程魔法弹 · 范围伤害", "d_en": "Ranged magic orb · splash damage", "price": 600,
		"hp": 283.0, "atk": 30.0, "speed": 102.0, "cooldown": 0.85, "range": 170.0, "splash": 55.0, "tint": Color("ff9a6a"), "scale": 1.0,
		"ex_cn": "陨星术", "ex_en": "Meteor", "ex_cd": 18.0},
	"titan": {"cn": "巨力蛮王", "en": "Titan King", "d_cn": "体型巨大 · 一棒打飞一群", "d_en": "Huge · one swing launches a crowd", "price": 900,
		"hp": 1080.0, "atk": 44.0, "speed": 71.0, "cooldown": 1.15, "range": 90.0, "aoe": 70.0, "tint": Color("d8a070"), "scale": 1.45,
		"ex_cn": "震地", "ex_en": "Quake", "ex_cd": 18.0},
}
const HERO_ORDER: Array[String] = ["blade", "knight", "assassin", "mage", "titan"]

const GEAR: Dictionary = {
	"armor": {"cn": "精钢铠甲", "en": "Steel Armor", "d_cn": "全军（含英雄）生命 +8%/级", "d_en": "Army and hero HP +8% per level", "base": 120},
	"blade": {"cn": "锋利兵刃", "en": "Sharp Blades", "d_cn": "全军（含英雄）攻击 +8%/级", "d_en": "Army and hero attack +8% per level", "base": 120},
	"boots": {"cn": "疾行战靴", "en": "Swift Boots", "d_cn": "全军移动速度 +6%/级", "d_en": "Army move speed +6% per level", "base": 100},
	"banner": {"cn": "统帅军旗", "en": "Command Banner", "d_cn": "能量恢复 +1/级 · 开局能量 +10/级", "d_en": "Energy regen +1 and starting energy +10 per level", "base": 100},
	"wall": {"cn": "坚固城墙", "en": "Sturdy Wall", "d_cn": "我方基地生命 +15%/级", "d_en": "Your base HP +15% per level", "base": 90},
	"helm": {"cn": "精钢头盔", "en": "Steel Helm", "d_cn": "我方士兵受到伤害 -4%/级", "d_en": "Soldiers take 4% less damage per level", "base": 110},
	"amulet": {"cn": "墨玉护符", "en": "Ink Amulet", "d_cn": "终极技充能 +12%/级", "d_en": "Ultimate charge +12% per level", "base": 110},
	"drum": {"cn": "战鼓", "en": "War Drum", "d_cn": "所有技能冷却 -6%/级", "d_en": "All skill cooldowns -6% per level", "base": 130},
}
const GEAR_ORDER: Array[String] = ["armor", "blade", "boots", "banner", "wall", "helm", "amulet", "drum"]
const GEAR_MAX: int = 5

# ---------- coins ----------

static func coins() -> int:
	return int(Save.get_value("econ", "coins", 0))

static func add_coins(amount: int) -> void:
	Save.set_value("econ", "coins", maxi(0, coins() + amount))

# The web game's win reward: first clear 40 (15 after), +10 per star, +5 per level, +60 for a boss level.
static func win_reward(level: int, first: bool, stars: int, boss: bool) -> int:
	return (40 if first else 15) + stars * 10 + level * 5 + (60 if boss else 0)

# ---------- growth ----------

static func growth(key: String) -> int:
	return int(Save.get_value("econ", "growth_" + key, 0))

static func add_growth(key: String) -> void:
	Save.set_value("econ", "growth_" + key, growth(key) + 1)

# ---------- gear ----------

static func gear(id: String) -> int:
	return int(Save.get_value("econ", "gear_" + id, 0))

static func gear_cost(id: String) -> int:
	return int(GEAR[id]["base"]) * (gear(id) + 1)

# Buys the next level of a gear item. Returns false if maxed or too poor.
static func buy_gear(id: String) -> bool:
	var level: int = gear(id)
	if level >= GEAR_MAX or coins() < gear_cost(id):
		return false
	add_coins(-gear_cost(id))
	Save.set_value("econ", "gear_" + id, level + 1)
	return true

# ---------- heroes ----------

static func owns_hero(id: String) -> bool:
	return id == "blade" or bool(Save.get_value("econ", "hero_" + id, false))

static func selected_hero() -> String:
	var id: String = String(Save.get_value("econ", "hero", "blade"))
	if OS.is_debug_build() and OS.get_environment("INK_HERO") != "" and HEROES.has(OS.get_environment("INK_HERO")):
		return OS.get_environment("INK_HERO") # dev: screenshots of each hero
	return id if HEROES.has(id) and owns_hero(id) else "blade"

static func select_hero(id: String) -> void:
	if HEROES.has(id) and owns_hero(id):
		Save.set_value("econ", "hero", id)

static func buy_hero(id: String) -> bool:
	if owns_hero(id) or coins() < int(HEROES[id]["price"]):
		return false
	add_coins(-int(HEROES[id]["price"]))
	Save.set_value("econ", "hero_" + id, true)
	return true

# ---------- the multipliers the battle uses ----------

static func mods() -> Dictionary:
	var s: int = growth("str")
	var d: int = growth("def")
	var v: int = growth("spd")
	var c: int = growth("cmd")
	var blade: float = 1.0 + 0.08 * gear("blade")
	var drum: float = 1.0 - 0.06 * gear("drum")
	return {
		"atk": (1.0 + 0.15 * s) * blade,
		"hp": (1.0 + 0.15 * d) * (1.0 + 0.08 * gear("armor")),
		"spd": (1.0 + 0.1 * v) * (1.0 + 0.06 * gear("boots")),
		"cap": 50 + mini(4, c),
		"regen": 10.0 + 1.5 * c + gear("banner"),
		"start_energy": 10.0 * gear("banner"),
		"base_hp": (500.0 + 60.0 * d) * (1.0 + 0.15 * gear("wall")),
		"helm": 0.04 * gear("helm"),
		"ink": 1.0 + 0.12 * gear("amulet"),
		"drum": drum,
		"skill_atk": (1.0 + 0.15 * s) * blade,
		"cd_slash": maxf(5.0 / 11.0, (11.0 - v * 0.8) / 11.0) * drum,
		"cd_other": drum / (1.0 + 0.1 * v),
	}

# Test helper: forces the selected hero without owning checks.
static func set_value_for_test(id: String) -> void:
	Save.set_value("econ", "hero_" + id, true)
	Save.set_value("econ", "hero", id)
