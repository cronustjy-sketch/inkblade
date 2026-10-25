extends Node3D

const Levels := preload("res://data/levels.gd")
const UnitData := preload("res://data/units.gd")
const PLAYER_CASTLE_X: float = 0.0
const ENEMY_CASTLE_X: float = 40.0
const CAM_SPEED: float = 14.0
const CAM_HEIGHT: float = 10.0
const CAM_DISTANCE: float = 28.0
const MAX_ENERGY: float = 200.0
const ENERGY_REGEN: float = 10.0
const MAX_POP: int = 50
const UNIT_SCENE: PackedScene = preload("res://scenes/unit.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/hud.tscn")
const SPAWNER_SCRIPT: GDScript = preload("res://scripts/spawner.gd")
const HERO_SCENE: PackedScene = preload("res://scenes/hero.tscn")
const DECOR_SCRIPT: GDScript = preload("res://scripts/decor.gd")

@export var start_level: int = 1

@onready var camera: Camera3D = $Camera3D
@onready var player_castle: Node3D = $PlayerCastle
@onready var enemy_castle: Node3D = $EnemyCastle

var level: int = 1
var cam_x: float = 6.0
var energy: float = 0.0
var hud: CanvasLayer
var hero: Node3D
var _over: bool = false

func _ready() -> void:
	# Retry / Next level reload this scene, so the level lives in a static var.
	if Levels.current_level == 0:
		Levels.current_level = start_level
	level = Levels.current_level

	player_castle.position.x = PLAYER_CASTLE_X
	enemy_castle.position.x = ENEMY_CASTLE_X
	# Castles set hp from max_hp in their own _ready, which already ran.
	player_castle.max_hp = 500.0
	player_castle.hp = 500.0
	enemy_castle.max_hp = Levels.enemy_castle_hp(level)
	enemy_castle.hp = enemy_castle.max_hp
	player_castle.destroyed.connect(_on_castle_destroyed)
	enemy_castle.destroyed.connect(_on_castle_destroyed)

	var decor: Node3D = Node3D.new()
	decor.set_script(DECOR_SCRIPT)
	add_child(decor)
	decor.build($Ground, ENEMY_CASTLE_X)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(level, MAX_ENERGY, MAX_POP)
	hud.spawn_requested.connect(_on_spawn_requested)
	hud.retry_requested.connect(_on_retry)
	hud.next_level_requested.connect(_on_next_level)

	hero = HERO_SCENE.instantiate()
	hero.position = Vector3(6.0, 0.0, 0.0)
	add_child(hero)

	var spawner: Node = SPAWNER_SCRIPT.new()
	add_child(spawner)
	spawner.setup(self, level)

func _process(delta: float) -> void:
	energy = minf(MAX_ENERGY, energy + ENERGY_REGEN * delta)
	hud.update_state(energy, player_pop())

	# Placeholder camera control until the hero exists (build step 5).
	var dir: float = Input.get_axis("ui_left", "ui_right")
	cam_x = clampf(cam_x + dir * CAM_SPEED * delta, PLAYER_CASTLE_X, ENEMY_CASTLE_X)
	camera.position = Vector3(cam_x, CAM_HEIGHT, CAM_DISTANCE)
	camera.look_at(Vector3(cam_x, 1.5, 0.0), Vector3.UP)

func player_pop() -> int:
	var total: int = 0
	for u: Node3D in get_tree().get_nodes_in_group("team_0"):
		if not u.is_queued_for_deletion():
			total += u.pop
	return total

func spawn_unit(team: int, key: String, stat_mult: float = 1.0) -> void:
	var u: Node3D = UNIT_SCENE.instantiate()
	var own: Node3D = player_castle if team == 0 else enemy_castle
	var foe: Node3D = enemy_castle if team == 0 else player_castle
	u.setup(team, key, foe, stat_mult)
	add_child(u)
	var side: float = 1.0 if team == 0 else -1.0
	var z_spread: float = 0.4 if UnitData.UNITS[key]["pop"] >= 3 else 1.0
	u.position = Vector3(own.position.x + side * 4.2, 0.0, randf_range(-z_spread, z_spread))

func _on_spawn_requested(key: String) -> void:
	var d: Dictionary = UnitData.UNITS[key]
	if energy < d["cost"] or player_pop() + int(d["pop"]) > MAX_POP:
		return
	energy -= d["cost"]
	spawn_unit(0, key)

func _on_castle_destroyed(team: int) -> void:
	if _over:
		return
	_over = true
	var won: bool = team == 1
	get_tree().paused = true
	hud.show_result(won, level, level < Levels.MAX_LEVEL)

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_next_level() -> void:
	Levels.current_level = level + 1
	get_tree().paused = false
	get_tree().reload_current_scene()

# Debug only: F1 wins the level, F2 loses it.
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1:
		enemy_castle.take_damage(enemy_castle.hp)
	elif event.keycode == KEY_F2:
		player_castle.take_damage(player_castle.hp)
	elif event.keycode == KEY_F3:
		hero.play("run")
	elif event.keycode == KEY_F4:
		hero.play("slash1")
