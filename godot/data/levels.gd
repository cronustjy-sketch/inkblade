extends RefCounted

const UnitData := preload("res://data/units.gd")

const MAX_LEVEL: int = 20

# 0 = not chosen yet; battle.gd falls back to its start_level.
static var current_level: int = 0

# Level at which each unit joins the enemy pool (differs from the player unlock for witch).
const ENEMY_UNLOCK: Dictionary = {
	"soldier": 1, "archer": 2, "spear": 3, "shield": 4, "witch": 6, "assassin": 7,
	"priest": 8, "giant": 9, "cavalry": 10, "catapult": 13,
}

static func enemy_pool(level: int) -> Array[String]:
	var pool: Array[String] = []
	for key: String in ENEMY_UNLOCK:
		if ENEMY_UNLOCK[key] <= level:
			pool.append(key)
	return pool

static func enemy_castle_hp(level: int) -> float:
	return 420.0 + 70.0 * level

static func enemy_stat_mult(level: int) -> float:
	return 1.0 + 0.11 * (mini(level, 20) - 1)

static func enemy_spawn_interval(level: int) -> float:
	return maxf(0.9, 3.2 - 0.2 * level)

static func enemy_cap(level: int) -> int:
	return mini(36, 10 + 2 * level)
