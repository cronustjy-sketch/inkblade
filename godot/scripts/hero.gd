extends Node3D

# Animated hero model. hero_anim.glb is the rigged version of hero.glb (idle, run, slash1-3, spin, roll, hit, jump, power).
const MODEL: PackedScene = preload("res://models/hero_anim.glb")
const LOOPING: Array[String] = ["idle", "run"]
const HERO_SCALE: float = 1.15

var _anim: AnimationPlayer
var _current: String = ""

func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	model.scale = Vector3.ONE * HERO_SCALE
	# Mixamo models face +Z; the battle runs along +X.
	model.rotation_degrees.y = 90.0
	add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		push_warning("hero: no AnimationPlayer found in model")
		return
	for anim_name: StringName in _anim.get_animation_list():
		if String(anim_name) in LOOPING:
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	play("idle")

func play(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_current = anim_name
	_anim.play(anim_name, 0.15)
	if not (anim_name in LOOPING):
		await _anim.animation_finished
		if _current == anim_name:
			play("idle")
