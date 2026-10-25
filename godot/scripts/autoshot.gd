extends Node

# Debug helper ("eyes"): saves a screenshot of the battle to screenshots/ with units on screen.
#   * F12 in an editor run: save a screenshot right now.
#   * INK_AUTOSHOT=1 in the environment: set up a small fight around the hero, wait SHOT_DELAY seconds,
#     save screenshots/battle_L<level>.png and quit. INK_LEVEL=<n> picks the level (read by battle.gd).
# Only active in debug builds.

const UnitData := preload("res://data/units.gd")
const Levels := preload("res://data/levels.gd")
const SHOT_DELAY: float = 5.0
const SHOT_DIR: String = "res://screenshots/"

var battle: Node3D
var _auto: bool = false
var _elapsed: float = 0.0
var _done: bool = false

func setup(p_battle: Node3D) -> void:
	battle = p_battle
	_auto = OS.get_environment("INK_AUTOSHOT") != ""
	if _auto:
		_stage_fight.call_deferred()

func _process(delta: float) -> void:
	if not _auto or _done:
		return
	_elapsed += delta
	if _elapsed >= SHOT_DELAY:
		_done = true
		await RenderingServer.frame_post_draw
		print("autoshot saved: ", save("battle_L%d" % battle.level))
		get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		print("screenshot saved: ", save("shot_%d" % Time.get_unix_time_from_system()))

func save(file_name: String) -> String:
	var dir: String = ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir + file_name + ".png"
	get_viewport().get_texture().get_image().save_png(path)
	return path

# A readable demo fight in front of the hero: every unlocked player unit against the level's enemy pool.
func _stage_fight() -> void:
	battle.spawner.enabled = false
	battle.energy = 0.0
	var hx: float = battle.hero.position.x
	var mine: Array[String] = []
	for key: String in UnitData.UNITS:
		if UnitData.UNITS[key]["unlock"] <= battle.level:
			mine.append(key)
	var foes: Array[String] = Levels.enemy_pool(battle.level)
	var n: int = mini(mini(mine.size(), 6) + 2, 8)
	for i in n:
		var u: Node3D = battle.spawn_unit(0, mine[i % mine.size()])
		u.position = Vector3(hx + 1.5 + i * 0.9, 0.0, randf_range(-1.0, 1.0))
		var e: Node3D = battle.spawn_unit(1, foes[i % foes.size()], Levels.enemy_stat_mult(battle.level))
		e.position = Vector3(hx + 7.0 + i * 0.9, 0.0, randf_range(-1.0, 1.0))
