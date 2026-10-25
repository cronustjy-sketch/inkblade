extends CharacterBody3D

# The raid hero: models/hero_anim.glb (idle, run, slash1-3, spin, roll, hit, jump, power) in toon style.
# WASD (or the on-screen joystick) moves relative to the camera.

const Toon := preload("res://scripts/toon.gd")
const Arena := preload("res://scripts/raid_arena.gd")
const MODEL: PackedScene = preload("res://models/hero_anim.glb")
const MODEL_SCALE: float = 1.25
const MOVE_SPEED: float = 7.0
const ACCEL: float = 40.0
const TURN_SPEED: float = 14.0
const GRAVITY: float = 28.0
const LOOPING: Array[String] = ["idle", "run"]

var move_input: Vector2 = Vector2.ZERO # x = right, y = forward (-1..1), set by raid.gd each frame
var cam_yaw: float = 0.0
var facing: Vector3 = Vector3(0, 0, -1)

var _model: Node3D
var _anim: AnimationPlayer
var _materials: Array[ShaderMaterial] = []
var _current: String = ""

func _ready() -> void:
	collision_layer = 2 # world = 1, hero = 2, bosses = 4
	collision_mask = 1 | 4
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	col.shape = capsule
	col.position.y = 0.95
	add_child(col)

	_model = MODEL.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.rotation_degrees.y = 180.0 # Mixamo models face +Z; the hero's forward is -Z
	add_child(_model)
	_materials = Toon.apply_model(_model, MODEL_SCALE, 0.03, Color.WHITE, 2.6)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for anim_name: StringName in _anim.get_animation_list():
			if String(anim_name) in LOOPING:
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	play("idle")

func _physics_process(delta: float) -> void:
	var forward := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var wish: Vector3 = right * move_input.x + forward * move_input.y
	if wish.length() > 1.0:
		wish = wish.normalized()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(wish * MOVE_SPEED, ACCEL * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	global_position = Arena.clamp_inside(global_position)
	if wish.length() > 0.1:
		facing = wish.normalized()
		var target_yaw: float = atan2(-facing.x, -facing.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-TURN_SPEED * delta))
	play("run" if wish.length() > 0.1 else "idle")

func play(anim_name: String, speed: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _current == anim_name and speed == _anim.speed_scale:
		return
	_current = anim_name
	_anim.speed_scale = speed
	_anim.play(anim_name, 0.12)
