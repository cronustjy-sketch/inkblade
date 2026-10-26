extends RefCounted

# Small persistent settings / story-progress store (user://ink_save.cfg). Level progress lives in data/levels.gd and
# raid best times in data/raid.gd; this file keeps everything else the player has seen or chosen.

const PATH_DEFAULT: String = "user://ink_save.cfg"
static var path: String = PATH_DEFAULT
static var _cfg: ConfigFile
static var _loaded: bool = false

static func _ensure() -> void:
	if _loaded:
		return
	_cfg = ConfigFile.new()
	_cfg.load(path)
	_loaded = true

static func reload() -> void:
	_loaded = false
	_ensure()

static func get_value(section: String, key: String, default: Variant = null) -> Variant:
	_ensure()
	return _cfg.get_value(section, key, default)

static func set_value(section: String, key: String, value: Variant) -> void:
	_ensure()
	_cfg.set_value(section, key, value)
	_cfg.save(path)

# ---------- stories ----------

static func intro_seen() -> bool:
	return bool(get_value("story", "intro", false))

static func mark_intro_seen() -> void:
	set_value("story", "intro", true)

static func chapter_story_seen(chapter: int) -> bool:
	return bool(get_value("story", "chapter_%d" % chapter, false))

static func mark_chapter_story_seen(chapter: int) -> void:
	set_value("story", "chapter_%d" % chapter, true)

static func origin_seen() -> bool:
	return bool(get_value("story", "origin", false))

static func mark_origin_seen() -> void:
	set_value("story", "origin", true)

# ---------- settings ----------

static func ink_effects() -> bool:
	return bool(get_value("settings", "ink_effects", true))

static func camera_shake() -> bool:
	return bool(get_value("settings", "camera_shake", true))

static func reset_all() -> void:
	_ensure()
	_cfg = ConfigFile.new()
	_cfg.save(path)
