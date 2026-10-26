extends Node

# Debug helper ("eyes"): saves a screenshot of the battle to screenshots/ with units on screen.
#   * F12 in an editor run: save a screenshot right now.
#   * INK_AUTOSHOT=1 in the environment: set up a small fight around the hero, wait SHOT_DELAY seconds,
#     save screenshots/battle_L<level>.png and quit. INK_LEVEL=<n> picks the level (read by battle.gd).
# Only active in debug builds.

const UnitData := preload("res://data/units.gd")
const Levels := preload("res://data/levels.gd")
var SHOT_DELAY: float = float(OS.get_environment("INK_DELAY")) if OS.get_environment("INK_DELAY") != "" else 5.0
const SHOT_DIR: String = "res://screenshots/"
const Fx := preload("res://scripts/fx.gd")

var battle: Node3D
var _auto: bool = false
var _elapsed: float = 0.0
var _done: bool = false
var _demo: bool = false
var _damaged: bool = false
var _crumbled: bool = false

func setup(p_battle: Node3D) -> void:
	battle = p_battle
	_auto = OS.get_environment("INK_AUTOSHOT") != ""
	if _auto and OS.get_environment("INK_HERO_X") != "":
		battle.hero.position.x = float(OS.get_environment("INK_HERO_X"))
		battle.cam_x = battle.hero.position.x
	if _auto and OS.get_environment("INK_DAMAGE") == "":
		_stage_fight.call_deferred()

func _process(delta: float) -> void:
	if not _auto or _done:
		return
	_elapsed += delta
	if OS.get_environment("INK_FXDEMO") != "" and not _demo and _elapsed > SHOT_DELAY - 0.14:
		_demo = true
		_fx_demo()
	if not _damaged and OS.get_environment("INK_DAMAGE") != "" and _elapsed > 1.0:
		_damaged = true
		var c: Node3D = battle.enemy_castle
		c.take_damage(c.max_hp * float(OS.get_environment("INK_DAMAGE")))
	if not _crumbled and OS.get_environment("INK_CRUMBLE") != "" and _elapsed > 4.0:
		_crumbled = true
		battle.enemy_castle.take_damage(1.0e9)
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
	battle.hero._cd_left = 1.0e9 if OS.get_environment("INK_DAMAGE") != "" else 0.0 # keep the hero from finishing the statue
	if OS.get_environment("INK_HERO_X") != "":
		battle.hero.position.x = float(OS.get_environment("INK_HERO_X"))
		battle.cam_x = battle.hero.position.x
	var hx: float = battle.hero.position.x
	var mine: Array[String] = []
	for key: String in UnitData.UNITS:
		if UnitData.UNITS[key]["unlock"] <= battle.level:
			mine.append(key)
	var foes: Array[String] = Levels.enemy_pool(battle.level)
	var n: int = mini(mini(mine.size(), 6) + 2, 8)
	for i in n:
		var u: Node3D = battle.spawn_unit(0, mine[i % mine.size()])
		u.position = Vector3(hx + 1.5 + i * 0.9, 0.0, u.lane_z)
		var e: Node3D = battle.spawn_unit(1, foes[i % foes.size()], Levels.enemy_stat_mult(battle.level))
		e.position = Vector3(hx + 7.0 + i * 0.9, 0.0, e.lane_z)

# INK_FXDEMO=1: fires one of each ink effect in front of the hero shortly before the screenshot (visual check).
func _fx_demo() -> void:
	const InkFx := preload("res://scripts/inkfx.gd")
	var hx: float = battle.hero.position.x
	InkFx.slash(battle, Vector3(hx + 3.0, 1.8, 0.5), 1.0, 3.6, -20.0, Color("f2b632"))
	InkFx.slash(battle, Vector3(hx + 7.5, 1.8, 0.5), -1.0, 3.6, -20.0, Color("e0463b"))
	InkFx.hit_splash(battle, Vector3(hx + 5.0, 1.6, 0.5), 1.2)
	InkFx.death_burst(battle, Vector3(hx + 10.0, 0.0, 0.6), 1.3)
	Fx.slash_wave(battle, Vector3(hx + 1.0, 0.0, 1.6), 1.0, 6.0)
