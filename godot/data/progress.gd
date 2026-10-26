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

# ---------- armory 军械库: per-unit HP / attack upgrades ----------

const ARM_MAX: int = 5
const UnitData := preload("res://data/units.gd")

static func arm_lv(unit: String, stat: String) -> int:
	return int(Save.get_value("econ", "arm_%s_%s" % [unit, stat], 0))

# The web's armCost: (60 + 3 x unit cost) x (level + 1), attack 10% dearer.
static func arm_cost(unit: String, stat: String) -> int:
	return roundi((60.0 + float(UnitData.UNITS[unit]["cost"]) * 3.0) * (arm_lv(unit, stat) + 1) * (1.1 if stat == "atk" else 1.0))

static func buy_arm(unit: String, stat: String) -> bool:
	var lv: int = arm_lv(unit, stat)
	if lv >= ARM_MAX or coins() < arm_cost(unit, stat):
		return false
	add_coins(-arm_cost(unit, stat))
	Save.set_value("econ", "arm_%s_%s" % [unit, stat], lv + 1)
	return true

static func arm_mul(unit: String) -> Dictionary:
	return {"hp": 1.0 + 0.12 * arm_lv(unit, "hp"), "atk": 1.0 + 0.1 * arm_lv(unit, "atk")}

# ---------- shop 商店 ----------

const SKINS: Dictionary = {
	"hero_gold": {"cn": "金焰英雄", "en": "Flame Hero", "price": 0, "slot": "hero", "tint": Color.WHITE},
	"hero_v": {"cn": "暗影紫刃", "en": "Shadow Violet", "price": 150, "slot": "hero", "tint": Color("b58cff")},
	"hero_j": {"cn": "翡翠剑客", "en": "Jade Swordsman", "price": 200, "slot": "hero", "tint": Color("7fe0a0")},
	"hero_s": {"cn": "白银骑士", "en": "Silver Knight", "price": 300, "slot": "hero", "tint": Color("dfe6f0")},
	"army_b": {"cn": "苍蓝军团", "en": "Azure Legion", "price": 0, "slot": "army", "tint": Color.WHITE},
	"army_p": {"cn": "紫晶军团", "en": "Amethyst Legion", "price": 250, "slot": "army", "tint": Color("c49cff")},
	"army_g": {"cn": "翠林军团", "en": "Emerald Legion", "price": 250, "slot": "army", "tint": Color("8fe39a")},
}
const SKIN_ORDER: Array[String] = ["hero_gold", "hero_v", "hero_j", "hero_s", "army_b", "army_p", "army_g"]

const POTIONS: Dictionary = {
	"p_energy": {"cn": "能量药水", "en": "Energy Potion", "d_cn": "下一场开局能量 +80", "d_en": "Next battle: start with +80 energy", "price": 40, "color": Color("e8b44a")},
	"p_hp": {"cn": "城墙药水", "en": "Wall Potion", "d_cn": "下一场我方基地生命 +50%", "d_en": "Next battle: base HP +50%", "price": 50, "color": Color("6cc070")},
	"p_atk": {"cn": "狂暴药水", "en": "Rage Potion", "d_cn": "下一场全军攻击 +25%", "d_en": "Next battle: army attack +25%", "price": 60, "color": Color("de4b3f")},
	"p_speed": {"cn": "疾风药水", "en": "Gale Potion", "d_cn": "下一场全军移动 +30%", "d_en": "Next battle: army move speed +30%", "price": 40, "color": Color("5b9be6")},
}
const POTION_ORDER: Array[String] = ["p_energy", "p_hp", "p_atk", "p_speed"]

const SPELLS: Dictionary = {
	"bolt": {"cn": "天雷", "en": "Thunder", "d_cn": "劈中最前面的 4 个敌人", "d_en": "Strikes the 4 front enemies", "price": 40, "color": Color("ffe95a")},
	"volley": {"cn": "千箭齐发", "en": "Arrow Volley", "d_cn": "3 秒箭雨覆盖敌人前线", "d_en": "3 s of arrows on the enemy front", "price": 35, "color": Color("9ad0ff")},
	"rage": {"cn": "狂暴", "en": "Rage", "d_cn": "全军攻击 +50%，持续 8 秒", "d_en": "Army +50% attack for 8 s", "price": 50, "color": Color("ff7a3a")},
	"aegis": {"cn": "圣盾", "en": "Aegis", "d_cn": "全军受到的伤害 -60%，持续 6 秒", "d_en": "Army takes 60% less for 6 s", "price": 50, "color": Color("bfe0ff")},
	"frost": {"cn": "冰封", "en": "Frost", "d_cn": "冻住所有地面敌人 3 秒", "d_en": "Freezes ground enemies for 3 s", "price": 60, "color": Color("9fe8ff")},
	"surge": {"cn": "能量泉", "en": "Energy Spring", "d_cn": "立刻 +100 能量", "d_en": "+100 energy at once", "price": 30, "color": Color("ffd36b")},
	"plague": {"cn": "瘟疫", "en": "Plague", "d_cn": "敌人前线毒雾，5 秒持续伤害", "d_en": "Poison cloud on the enemy front for 5 s", "price": 45, "color": Color("9be37a")},
	"reinf": {"cn": "援军", "en": "Reinforcements", "d_cn": "免费召唤 5 个剑兵 + 1 个巨人", "d_en": "Free 5 swordsmen + 1 giant", "price": 80, "color": Color("f2b632")},
	"meteor": {"cn": "陨石风暴", "en": "Meteor Storm", "d_cn": "12 颗陨石砸向敌人", "d_en": "12 meteors on the enemy", "price": 120, "color": Color("ff5a3a")},
}
const SPELL_ORDER: Array[String] = ["bolt", "volley", "rage", "aegis", "frost", "surge", "plague", "reinf", "meteor"]

static func owns_skin(id: String) -> bool:
	return int(SKINS[id]["price"]) == 0 or bool(Save.get_value("econ", "skin_" + id, false))

static func equipped_skin(slot: String) -> String:
	var def: String = "hero_gold" if slot == "hero" else "army_b"
	var id: String = String(Save.get_value("econ", "skin_" + slot, def))
	return id if SKINS.has(id) and owns_skin(id) else def

static func skin_tint(slot: String) -> Color:
	return SKINS[equipped_skin(slot)]["tint"]

static func equip_skin(id: String) -> void:
	if owns_skin(id):
		Save.set_value("econ", "skin_" + String(SKINS[id]["slot"]), id)

static func buy_skin(id: String) -> bool:
	if owns_skin(id) or coins() < int(SKINS[id]["price"]):
		return false
	add_coins(-int(SKINS[id]["price"]))
	Save.set_value("econ", "skin_" + id, true)
	return true

static func potions(id: String) -> int:
	return int(Save.get_value("econ", "n_" + id, 0))

static func spells(id: String) -> int:
	return int(Save.get_value("econ", "n_" + id, 0))

# Buys one potion or spell (they stack).
static func buy_item(id: String) -> bool:
	var price: int = int(POTIONS[id]["price"]) if POTIONS.has(id) else int(SPELLS[id]["price"])
	if coins() < price:
		return false
	add_coins(-price)
	Save.set_value("econ", "n_" + id, int(Save.get_value("econ", "n_" + id, 0)) + 1)
	return true

# Uses one spell from the bag. Returns false if there is none.
static func use_spell(id: String) -> bool:
	var n: int = spells(id)
	if n <= 0:
		return false
	Save.set_value("econ", "n_" + id, n - 1)
	return true

# At the start of a battle every potion in the bag is drunk (one of each). Returns what was used.
static func drink_potions() -> Array[String]:
	var used: Array[String] = []
	for id: String in POTION_ORDER:
		var n: int = potions(id)
		if n > 0:
			Save.set_value("econ", "n_" + id, n - 1)
			used.append(id)
	return used
