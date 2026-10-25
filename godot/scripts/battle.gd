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
const DECOR_SCRIPT: GDScript = preload("res://scripts/decor.gd")

@export var level: int = 1

@onready var camera: Camera3D = $Camera3D
@onready var player_castle: Node3D = $PlayerCastle
@onready var enemy_castle: Node3D = $EnemyCastle

var cam_x: float = 6.0
var energy: float = 0.0
var hud: CanvasLayer

func _ready() -> void:
	player_castle.position.x = PLAYER_CASTLE_X
	enemy_castle.position.x = ENEMY_CASTLE_X
	player_castle.max_hp = 500.0
	enemy_castle.max_hp = Levels.enemy_castle_hp(level)

	var decor: Node3D = Node3D.new()
	decor.set_script(DECOR_SCRIPT)
	add_child(decor)
	decor.build($Ground, ENEMY_CASTLE_X)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(level, MAX_ENERGY, MAX_POP)
	hud.spawn_requested.connect(_on_spawn_requested)

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
	u.position = Vector3(own.position.x + side * 4.2, 0.0, randf_range(-1.0, 1.0))

func _on_spawn_requested(key: String) -> void:
	var d: Dictionary = UnitData.UNITS[key]
	if energy < d["cost"] or player_pop() + int(d["pop"]) > MAX_POP:
		return
	energy -= d["cost"]
	spawn_unit(0, key)
