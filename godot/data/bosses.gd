extends RefCounted

# Bosses every 5 levels. hp / atk are final values (not scaled by the enemy stat multiplier).
# range / speed are pixel values like data/units.gd. aoe / knockback work like the giant's.
const SPAWN_DELAY: float = 3.0

const BOSSES: Dictionary = {
	5: {"name_cn": "石拳首领", "name_en": "Stone Fist Chief", "hp": 950.0, "atk": 26.0, "range": 70.0, "speed": 24.0, "cooldown": 1.8, "aoe": 45.0, "knockback": 1.5, "model": "res://models/colossus_anim.glb", "scale": 2.6},
	10: {"name_cn": "草原霸主", "name_en": "Grassland Overlord", "hp": 1900.0, "atk": 34.0, "range": 70.0, "speed": 26.0, "cooldown": 1.7, "aoe": 50.0, "knockback": 1.8, "model": "res://models/warden_anim.glb", "scale": 2.7},
	15: {"name_cn": "熔岩巨魔", "name_en": "Lava Troll", "hp": 3600.0, "atk": 46.0, "range": 75.0, "speed": 26.0, "cooldown": 1.6, "aoe": 55.0, "knockback": 2.0, "model": "res://models/faceless_anim.glb", "scale": 2.9},
	20: {"name_cn": "墨刃魔王", "name_en": "Ink Blade Demon King", "hp": 6000.0, "atk": 58.0, "range": 80.0, "speed": 28.0, "cooldown": 1.5, "aoe": 65.0, "knockback": 2.5, "model": "res://models/ender.glb", "scale": 2.2, "static": true},
}

static func has_boss(level: int) -> bool:
	return BOSSES.has(level)

static func for_level(level: int) -> Dictionary:
	return BOSSES[level]
