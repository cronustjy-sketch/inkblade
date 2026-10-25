extends Node3D

# Visual for model-based enemies (bosses). Same interface as stickman.gd:
# set_moving(), play_attack(), set_facing() and `height`.
# The Mixamo boss models share the animation set idle / walk / run / slash / swipe / slam / roar / hit.

const ATTACKS: Array[String] = ["slash", "swipe", "slam"]
const LOOPING: Array[String] = ["idle", "walk", "run"]

var height: float = 3.0

var _holder: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _moving: bool = false
var _busy: float = 0.0
var _current: String = ""
var _clock: float = 0.0
var _static_model: bool = false

func setup(cfg: Dictionary) -> void:
	var scene: PackedScene = load(cfg["model"])
	_model = scene.instantiate()
	var s: float = cfg["scale"]
	_model.scale = Vector3.ONE * s
	# Mixamo models face +Z; the battle runs along +X.
	_model.rotation_degrees.y = 90.0
	_static_model = cfg.get("static", false)
	height = (2.41 if _static_model else 1.8) * s
	_holder = Node3D.new()
	add_child(_holder)
	_holder.add_child(_model)
	set_facing(false)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for anim_name: StringName in _anim.get_animation_list():
			if String(anim_name) in LOOPING:
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_play("idle")

func set_facing(right: bool) -> void:
	_holder.rotation_degrees.y = 0.0 if right else 180.0

func set_moving(value: bool) -> void:
	_moving = value

func play_attack(_cooldown: float) -> void:
	_busy = 0.7
	if _anim != null:
		_play(ATTACKS.pick_random(), 0.7)
	else:
		_clock = 0.0

func _process(delta: float) -> void:
	_clock += delta
	_busy = maxf(0.0, _busy - delta)
	if _anim != null:
		if _busy <= 0.0:
			_play("walk" if _moving else "idle")
	else:
		# Static model (no skeleton): bob while walking, lunge when attacking.
		_model.position.y = absf(sin(_clock * 5.0)) * 0.15 if _moving else sin(_clock * 2.0) * 0.04
		_model.rotation_degrees.z = sin(_busy / 0.7 * PI) * -18.0 if _busy > 0.0 else 0.0

func _play(anim_name: String, busy_time: float = 0.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if busy_time > 0.0:
		var anim_len: float = _anim.get_animation(anim_name).length
		_anim.speed_scale = maxf(1.0, anim_len / busy_time)
		_current = ""
		_anim.play(anim_name, 0.1)
		return
	if _current == anim_name:
		return
	_current = anim_name
	_anim.speed_scale = 1.0
	_anim.play(anim_name, 0.2)
