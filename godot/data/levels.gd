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

# ---------- terrain and progress ----------

# Levels 11-20 have lava terrain.
static func is_lava(level: int) -> bool:
	return level >= 11

const SAVE_DEFAULT: String = "user://progress.cfg"
static var save_path: String = SAVE_DEFAULT
static var _highest_cleared: int = -1
# Debug builds can unlock every level from the map screen.
static var unlock_all: bool = false

static func highest_cleared() -> int:
	if _highest_cleared < 0:
		var cfg := ConfigFile.new()
		_highest_cleared = int(cfg.get_value("progress", "highest_cleared", 0)) if cfg.load(save_path) == OK else 0
	return _highest_cleared

static func highest_unlocked() -> int:
	if unlock_all:
		return MAX_LEVEL
	return mini(MAX_LEVEL, highest_cleared() + 1)

static func mark_cleared(level: int) -> void:
	if level <= highest_cleared():
		return
	_highest_cleared = level
	_save()

static func reset_progress() -> void:
	_highest_cleared = 0
	_save()

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "highest_cleared", _highest_cleared)
	cfg.save(save_path)

# Story chapters are 10 levels each, like the web game: chapter 1 = levels 1-10 (grassland), chapter 2 = 11-20 (land of flames).
static func chapter_number(level: int) -> int:
	return maxi(1, ceili(level / 10.0))

# Landscape palette for backdrop.gd: 1 grassland, 3 lava (2 = desert, kept for later chapters).
static func chapter(level: int) -> int:
	return 1 if level <= 10 else 3

static func is_first_of_chapter(level: int) -> bool:
	return (level - 1) % 10 == 0
