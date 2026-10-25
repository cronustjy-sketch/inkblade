extends Node3D

const PLAYER_CASTLE_X: float = 0.0
const ENEMY_CASTLE_X: float = 40.0
const CAM_SPEED: float = 14.0
const UNIT_SCENE: PackedScene = preload("res://scenes/unit.tscn")

@onready var camera: Camera3D = $Camera3D
@onready var player_castle: Node3D = $PlayerCastle
@onready var enemy_castle: Node3D = $EnemyCastle

var level: int = 1
var cam_x: float = 6.0

func _ready() -> void:
	player_castle.position.x = PLAYER_CASTLE_X
	enemy_castle.position.x = ENEMY_CASTLE_X
	player_castle.max_hp = 500.0
	enemy_castle.max_hp = 420.0 + 70.0 * level
	# Step 2 test: one unit per team.
	spawn_unit(0, "soldier")
	spawn_unit(1, "soldier")

func _process(delta: float) -> void:
	# Placeholder camera control until the hero exists (build step 5).
	var dir: float = Input.get_axis("ui_left", "ui_right")
	cam_x = clampf(cam_x + dir * CAM_SPEED * delta, PLAYER_CASTLE_X, ENEMY_CASTLE_X)
	camera.position = Vector3(cam_x, 9.0, 16.0)
	camera.look_at(Vector3(cam_x, 1.5, 0.0), Vector3.UP)

func spawn_unit(team: int, key: String) -> void:
	var u: Node3D = UNIT_SCENE.instantiate()
	var own: Node3D = player_castle if team == 0 else enemy_castle
	var foe: Node3D = enemy_castle if team == 0 else player_castle
	u.setup(team, key, foe)
	add_child(u)
	var side: float = 1.0 if team == 0 else -1.0
	u.position = Vector3(own.position.x + side * 3.5, 0.0, randf_range(-1.0, 1.0))

# Step 2 test keys: 1 = player swordsman, 2 = enemy swordsman.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			spawn_unit(0, "soldier")
		elif event.keycode == KEY_2:
			spawn_unit(1, "soldier")
