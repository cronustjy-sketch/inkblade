extends RefCounted

# Data for the 3D Boss Raid: the ladder of bosses and the saved best clear times.
# Attack ids are implemented in scripts/raid_boss.gd. Distances are meters, times seconds.

const SAVE_DEFAULT: String = "user://raid.cfg"
static var save_path: String = SAVE_DEFAULT

# One entry per fight, in ladder order. "anims" maps the logical animations to clips in the model (null = static model).
const BOSSES: Array[Dictionary] = [
	{
		"id": "warden", "cn": "赤红守卫", "en": "Crimson Warden",
		"model": "res://models/warden_anim.glb", "scale": 3.0, "yaw": 180.0, "brightness": 1.2,
		"hp": 1800.0, "speed": 4.4, "hit_radius": 2.3, "hit_height": 4.4, "flying": false,
		"attacks": ["slash", "slam", "charge"], "phase2_attacks": ["whirl"],
		"anims": {"idle": "idle", "walk": "walk", "run": "run", "slash": "slash", "swipe": "swipe", "slam": "slam", "roar": "roar", "hit": "hit"},
	},
	{
		"id": "colossus", "cn": "岩石巨像", "en": "Stone Colossus",
		"model": "res://models/colossus_anim.glb", "scale": 3.4, "yaw": 180.0, "brightness": 1.2,
		"hp": 2600.0, "speed": 3.4, "hit_radius": 2.9, "hit_height": 5.4, "flying": false,
		"attacks": ["slam", "stomp_rings", "shockwave"], "phase2_attacks": ["quake"],
		"anims": {"idle": "idle", "walk": "walk", "run": "run", "slash": "slash", "swipe": "swipe", "slam": "slam", "roar": "roar", "hit": "hit"},
	},
	{
		"id": "faceless", "cn": "无面者", "en": "The Faceless One",
		"model": "res://models/faceless_anim.glb", "scale": 3.0, "yaw": 180.0, "brightness": 1.2,
		"hp": 3400.0, "speed": 5.2, "hit_radius": 1.8, "hit_height": 4.6, "flying": false,
		"attacks": ["blink", "cross", "slash"], "phase2_attacks": ["frenzy"],
		"anims": {"idle": "idle", "walk": "walk", "run": "run", "slash": "slash", "swipe": "swipe", "slam": "slam", "roar": "roar", "hit": "hit"},
	},
	{
		"id": "ender", "cn": "终焉之主", "en": "Lord of the End",
		"model": "res://models/ender.glb", "scale": 2.4, "yaw": 180.0, "brightness": 1.2,
		"hp": 4400.0, "speed": 3.8, "hit_radius": 1.6, "hit_height": 4.4, "flying": false,
		"attacks": ["meteors", "beam", "void_pulse"], "phase2_attacks": ["barrage"],
		"anims": {},
	},
	{
		"id": "dragon", "cn": "苍龙", "en": "Azure Dragon",
		"model": "res://models/dragon.glb", "scale": 4.6, "yaw": 90.0, "brightness": 1.2,
		"hp": 5600.0, "speed": 4.2, "hit_radius": 5.2, "hit_height": 3.4, "flying": true, "hover": 6.0, "keep": 11.0, "orbit": 11.0,
		"attacks": ["fire_sweep", "fireballs", "dive"], "phase2_attacks": ["inferno"],
		"anims": {},
	},
]

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

static func reset_records() -> void:
	var cfg := ConfigFile.new()
	cfg.save(save_path)
