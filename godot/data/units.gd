extends RefCounted

# Original pixel values; divide by PX_PER_M for meters (range, speed).
const PX_PER_M: float = 30.0

const UNITS: Dictionary = {
	"soldier": {"name_cn": "剑兵", "name_en": "Swordsman", "hp": 60.0, "atk": 10.0, "range": 24.0, "speed": 44.0, "cooldown": 0.9, "cost": 20, "pop": 1, "unlock": 1, "sprite_h": 2.2},
	"archer": {"name_cn": "弓手", "name_en": "Archer", "hp": 36.0, "atk": 9.0, "range": 155.0, "speed": 36.0, "cooldown": 1.35, "cost": 30, "pop": 1, "unlock": 2, "projectile": "arrow", "sprite_h": 2.2},
	"spear": {"name_cn": "长枪兵", "name_en": "Spearman", "hp": 75.0, "atk": 12.0, "range": 42.0, "speed": 40.0, "cooldown": 1.1, "cost": 35, "pop": 1, "unlock": 3, "big_mult": 2.0, "sprite_h": 2.4},
	"shield": {"name_cn": "盾卫", "name_en": "Shield Knight", "hp": 240.0, "atk": 15.0, "range": 26.0, "speed": 32.0, "cooldown": 1.0, "cost": 45, "pop": 1, "unlock": 4, "armor": 0.35, "blocks_arrows": true, "sprite_h": 2.3},
	"witch": {"name_cn": "女巫", "name_en": "Witch", "hp": 42.0, "atk": 15.0, "range": 135.0, "speed": 32.0, "cooldown": 2.0, "cost": 60, "pop": 1, "unlock": 5, "projectile": "orb", "splash": 48.0, "sprite_h": 2.4},
	"assassin": {"name_cn": "刺客", "name_en": "Assassin", "hp": 48.0, "atk": 20.0, "range": 22.0, "speed": 85.0, "cooldown": 0.6, "cost": 50, "pop": 1, "unlock": 6, "crit_chance": 0.3, "crit_mult": 2.5, "sprite_h": 2.1},
	"priest": {"name_cn": "牧师", "name_en": "Priest", "hp": 55.0, "atk": 0.0, "range": 110.0, "speed": 36.0, "cooldown": 1.4, "cost": 55, "pop": 1, "unlock": 7, "heal": 16.0, "sprite_h": 2.3},
	"giant": {"name_cn": "巨人", "name_en": "Giant", "hp": 620.0, "atk": 38.0, "range": 52.0, "speed": 18.0, "cooldown": 2.2, "cost": 150, "pop": 3, "unlock": 8, "aoe": 62.0, "knockback": 2.0, "sprite_h": 3.8},
	"cavalry": {"name_cn": "骑兵", "name_en": "Cavalry", "hp": 170.0, "atk": 20.0, "range": 30.0, "speed": 95.0, "cooldown": 1.0, "cost": 90, "pop": 2, "unlock": 9, "charge_mult": 2.0, "knockback": 2.5, "sprite_h": 3.0},
	"catapult": {"name_cn": "投石车", "name_en": "Catapult", "hp": 220.0, "atk": 50.0, "range": 330.0, "speed": 16.0, "cooldown": 4.2, "cost": 140, "pop": 3, "unlock": 10, "projectile": "rock", "splash": 55.0, "castle_mult": 2.0, "sprite_h": 2.6},
	"dragon": {"name_cn": "苍龙", "name_en": "Dragon", "hp": 900.0, "atk": 16.0, "range": 40.0, "speed": 80.0, "cooldown": 1.0, "cost": 190, "pop": 4, "unlock": 201, "flying": true},
}

# "sprite_h" = height in meters of the drawn character in its sprite sheet (sprites/<key>_gold|red.png).
# The hero (not a spawnable unit). Pixel values like UNITS.
const HERO: Dictionary = {
	"name_cn": "墨刃", "name_en": "Ink Blade",
	"hp": 400.0, "atk": 22.0, "range": 60.0, "speed": 120.0, "cooldown": 0.6,
	"crit_every": 3, "crit_mult": 2.2, "respawn": 5.0,
}

# Hero skills. Ranges and radii are pixel values. "key" is the keyboard key shown on the HUD.
const HERO_SKILLS: Dictionary = {
	"slash": {"key": "Q", "name_cn": "怒斩", "name_en": "Slash", "cooldown": 11.0, "unlock": 1, "damage": 70.0, "range": 210.0},
	"dash": {"key": "E", "name_cn": "冲锋", "name_en": "Dash", "cooldown": 6.0, "unlock": 2, "damage": 40.0, "distance": 210.0, "invincible": 0.45},
	"rally": {"key": "R", "name_cn": "战吼", "name_en": "Rally", "cooldown": 18.0, "unlock": 4, "heal": 0.30, "haste": 1.45, "duration": 6.0},
	"rain": {"key": "F", "name_cn": "剑雨", "name_en": "Sword Rain", "cooldown": 22.0, "unlock": 6, "damage": 20.0, "range": 270.0, "duration": 2.2, "ticks": 8},
	"special": {"key": "G", "name_cn": "墨旋", "name_en": "Ink Vortex", "cooldown": 14.0, "unlock": 12, "damage": 50.0, "range": 150.0, "knockback": 3.0},
}

# Ultimate 墨刃·终: the ink meter fills from damage dealt; at ULT_MAX the hero can strike the whole screen.
const ULT_MAX: float = 100.0
const ULT_DAMAGE: float = 300.0
const ULT_CASTLE_DAMAGE: float = 120.0

# Orders for the player's army, and take-control tuning.
const ORDER_ATTACK: int = 0
const ORDER_DEFEND: int = 1
const ORDER_RETREAT: int = 2
const DEFEND_LINE_M: float = 7.0
const RETREAT_HEAL_PER_SEC: float = 0.08
const CONTROL_DAMAGE_MULT: float = 1.4

# Ink meter: how much each point of damage dealt adds (meter is 0..ULT_MAX).
const INK_PER_DAMAGE_HERO: float = 0.12
const INK_PER_DAMAGE_ARMY: float = 0.03
# The ultimate hits everything within this many meters of the camera centre.
const ULT_VIEW_HALF_WIDTH: float = 24.0
