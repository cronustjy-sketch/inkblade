extends Node3D

const PLAYER_CASTLE_X: float = 0.0
const ENEMY_CASTLE_X: float = 40.0
const CAM_SPEED: float = 14.0

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

func _process(delta: float) -> void:
	# Placeholder camera control until the hero exists (build step 5).
	var dir: float = Input.get_axis("ui_left", "ui_right")
	cam_x = clampf(cam_x + dir * CAM_SPEED * delta, PLAYER_CASTLE_X, ENEMY_CASTLE_X)
	camera.position = Vector3(cam_x, 9.0, 16.0)
	camera.look_at(Vector3(cam_x, 1.5, 0.0), Vector3.UP)
