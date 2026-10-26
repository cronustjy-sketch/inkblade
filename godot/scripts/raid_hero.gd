extends CharacterBody3D

# The raid hero: models/hero_anim.glb (idle, run, slash1-3, spin, roll, hit, jump, power) in toon style.
# WASD moves relative to the camera, left click = 3-hit combo, Space = dodge roll, Q/E/R/F = campaign skills.

signal damaged(amount: float)
signal died

const Toon := preload("res://scripts/toon.gd")
const Arena := preload("res://scripts/raid_arena.gd")
const Fx := preload("res://scripts/raid_fx.gd")
const UnitData := preload("res://data/units.gd")
const MODEL: PackedScene = preload("res://models/hero_anim.glb")
const MODEL_SCALE: float = 1.25
const MAX_HP: float = 300.0
const MOVE_SPEED: float = 7.0
const ACCEL: float = 40.0
const TURN_SPEED: float = 14.0
const GRAVITY: float = 28.0
const LOOPING: Array[String] = ["idle", "run"]
const COMBO_RESET: float = 0.9
const AUTO_AIM_RANGE: float = 9.0
# Three-hit combo: animation, damage, reach (m), arc (degrees), duration (s), moment of impact (fraction).
const COMBO: Array[Dictionary] = [
	{"anim": "slash1", "damage": 22.0, "reach": 3.6, "arc": 110.0, "duration": 0.42, "impact": 0.45},
	{"anim": "slash2", "damage": 26.0, "reach": 3.6, "arc": 110.0, "duration": 0.42, "impact": 0.45},
	{"anim": "slash3", "damage": 44.0, "reach": 4.4, "arc": 140.0, "duration": 0.62, "impact": 0.5},
]
const ROLL_TIME: float = 0.5
const ROLL_INVINCIBLE: float = 0.45
const ROLL_SPEED: float = 11.5
const ROLL_COOLDOWN: float = 0.8

var move_input: Vector2 = Vector2.ZERO # x = right, y = forward (-1..1), set by raid.gd each frame
var cam_yaw: float = 0.0
var facing: Vector3 = Vector3(0, 0, -1)
var hp: float = MAX_HP
var max_hp: float = MAX_HP
var dead: bool = false
var invincible_t: float = 0.0
var skill_cd: Dictionary = {}
var haste_t: float = 0.0
var controls_enabled: bool = true

var _model: Node3D
var _anim: AnimationPlayer
var _materials: Array[ShaderMaterial] = []
var _current: String = ""
var _combo: int = 0
var _combo_idle: float = 99.0
var _atk_t: float = 0.0
var _atk_dur: float = 0.0
var _atk_step: Dictionary = {}
var _hit_pending: bool = false
var _queued: bool = false
var _roll_t: float = 0.0
var _roll_dir: Vector3 = Vector3.ZERO
var _roll_cd: float = 0.0
var _dash_t: float = 0.0
var _dash_hit: Array[Node] = []
var _lock_t: float = 0.0 # skill cast animation lock
var _flash_t: float = 0.0
var _shadow: MeshInstance3D

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
	_materials = Toon.apply_model(_model, MODEL_SCALE, 0.03, Color.WHITE, 1.25, 0.5, 1.5)
	_shadow = Fx.blob_shadow(self, 1.1)
	_attach_sword()
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for anim_name: StringName in _anim.get_animation_list():
			if String(anim_name) in LOOPING:
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	play("idle")

func _physics_process(delta: float) -> void:
	if _shadow != null:
		Fx.place_shadow(_shadow, self)
	_tick_timers(delta)
	var forward := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var wish: Vector3 = right * move_input.x + forward * move_input.y
	if wish.length() > 1.0:
		wish = wish.normalized()
	if dead or not controls_enabled:
		wish = Vector3.ZERO

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _roll_t > 0.0:
		horizontal = _roll_dir * ROLL_SPEED
	elif _dash_t > 0.0:
		horizontal = _roll_dir * (_dash_distance() / 0.25)
	else:
		var speed_scale: float = 0.35 if (_atk_t > 0.0 or _lock_t > 0.0) else 1.0
		horizontal = horizontal.move_toward(wish * MOVE_SPEED * speed_scale, ACCEL * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	global_position = Arena.clamp_inside(global_position)

	if _dash_t > 0.0:
		_dash_strike()
	if _hit_pending:
		_check_impact()
	var busy: bool = _atk_t > 0.0 or _roll_t > 0.0 or _dash_t > 0.0 or _lock_t > 0.0
	if not busy and wish.length() > 0.1 and not dead:
		facing = wish.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-TURN_SPEED * delta))
	if not busy and not dead:
		play("run" if wish.length() > 0.1 else "idle")

func _tick_timers(delta: float) -> void:
	invincible_t = maxf(0.0, invincible_t - delta)
	haste_t = maxf(0.0, haste_t - delta)
	_roll_cd = maxf(0.0, _roll_cd - delta)
	_lock_t = maxf(0.0, _lock_t - delta)
	_combo_idle += delta
	for id: String in skill_cd:
		skill_cd[id] = maxf(0.0, skill_cd[id] - delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			Toon.set_flash(_materials, 0.0)
	if _roll_t > 0.0:
		_roll_t -= delta
	if _dash_t > 0.0:
		_dash_t -= delta
	if _atk_t > 0.0:
		_atk_t -= delta
		if _atk_t <= 0.0:
			_atk_t = 0.0
			if _queued:
				_queued = false
				_start_attack()
	elif _queued:
		_queued = false

# ---------- public controls ----------

func attack() -> void:
	if dead or not controls_enabled or _roll_t > 0.0 or _dash_t > 0.0 or _lock_t > 0.0:
		return
	if _atk_t > 0.0:
		_queued = true
		return
	_start_attack()

func dodge() -> void:
	if dead or not controls_enabled or _roll_cd > 0.0 or _roll_t > 0.0:
		return
	var forward := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var wish: Vector3 = right * move_input.x + forward * move_input.y
	_roll_dir = wish.normalized() if wish.length() > 0.1 else facing
	facing = _roll_dir
	rotation.y = atan2(-facing.x, -facing.z)
	_atk_t = 0.0
	_queued = false
	_hit_pending = false
	_roll_t = ROLL_TIME
	_roll_cd = ROLL_COOLDOWN
	invincible_t = maxf(invincible_t, ROLL_INVINCIBLE)
	play_fit("roll", ROLL_TIME)

func can_cast(id: String) -> bool:
	var s: Dictionary = UnitData.HERO_SKILLS[id]
	return not dead and controls_enabled and skill_cd.get(id, 0.0) <= 0.0 and _roll_t <= 0.0 and s["unlock"] > 0

func cast(id: String) -> bool:
	if not can_cast(id):
		return false
	var s: Dictionary = UnitData.HERO_SKILLS[id]
	_atk_t = 0.0
	_queued = false
	_hit_pending = false
	_face_aim()
	match id:
		"slash":
			_lock_t = 0.5
			play_fit("power", 0.5)
			var reach: float = s["range"] / UnitData.PX_PER_M
			Fx.slash_arc(get_parent(), global_position, facing, 150.0, reach, Color(0.7, 0.9, 1.0, 0.45))
			Fx.slash_trail(get_parent(), global_position, facing, reach * 0.8, 170.0, 8.0, Color(0.6, 0.9, 1.0, 0.95))
			_big_shake(0.45)
			_hit_bosses(global_position, facing, reach, 150.0, s["damage"])
		"dash":
			_roll_dir = facing
			_dash_t = 0.25
			_dash_hit.clear()
			invincible_t = maxf(invincible_t, s["invincible"])
			play_fit("roll", 0.3)
		"rally":
			_lock_t = 0.5
			play_fit("power", 0.5)
			hp = minf(max_hp, hp + max_hp * s["heal"])
			haste_t = s["duration"]
			Fx.ring(get_parent(), global_position, 5.0, Color("f2b632"), 0.6)
			Fx.popup(get_parent(), global_position + Vector3(0, 2.6, 0), "+%d" % int(max_hp * s["heal"]), Color("7dff9a"))
			damaged.emit(-max_hp * s["heal"])
		"rain":
			_lock_t = 0.6
			play_fit("power", 0.6)
			_rain(s)
		"special":
			# 墨旋 Ink Vortex: a spinning slash that hits everything around the hero.
			_lock_t = 0.7
			play_fit("spin", 0.7)
			var reach: float = s["range"] / UnitData.PX_PER_M
			Fx.ring(get_parent(), global_position, reach, Color(0.1, 0.1, 0.15, 0.7), 0.5)
			Fx.slash_trail(get_parent(), global_position, facing, reach * 0.9, 340.0, 0.0, Color(0.85, 0.95, 1.0, 0.95))
			_big_shake(0.5)
			_hit_bosses(global_position, facing, reach, 360.0, s["damage"])
		_:
			return false
	skill_cd[id] = s["cooldown"]
	return true

func take_damage(amount: float) -> void:
	if dead or invincible_t > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_flash_t = 0.12
	Toon.set_flash(_materials, 0.7, Color(1.0, 0.25, 0.2))
	Fx.popup(get_parent(), global_position + Vector3(0, 2.6, 0), "-%d" % int(amount), Color("ff5a4a"))
	damaged.emit(amount)
	if hp <= 0.0:
		dead = true
		play("hit")
		died.emit()

func heal_full() -> void:
	hp = max_hp
	damaged.emit(-1.0)

# ---------- combat internals ----------

func _start_attack() -> void:
	_combo = (_combo % COMBO.size()) + 1 if _combo_idle < COMBO_RESET and _combo > 0 else 1
	_atk_step = COMBO[_combo - 1]
	var speed: float = 1.45 if haste_t > 0.0 else 1.0
	_atk_dur = _atk_step["duration"] / speed
	_atk_t = _atk_dur
	_combo_idle = 0.0
	_hit_pending = true
	_face_aim()
	play_fit(_atk_step["anim"], _atk_dur)

func _check_impact() -> void:
	if _atk_t <= 0.0:
		_hit_pending = false
		return
	var elapsed: float = _atk_dur - _atk_t
	if elapsed < _atk_step["impact"] * _atk_dur:
		return
	_hit_pending = false
	var reach: float = _atk_step["reach"]
	var arc: float = _atk_step["arc"]
	Fx.slash_arc(get_parent(), global_position, facing, arc, reach, Color(1, 1, 1, 0.3))
	Fx.slash_trail(get_parent(), global_position, facing, reach * 0.85, arc * 1.1, [-28.0, 28.0, 82.0][_combo - 1])
	if _hit_bosses(global_position, facing, reach, arc, _atk_step["damage"]) > 0 and _combo == COMBO.size():
		var rig: Node = get_tree().get_first_node_in_group("raid_camera")
		if rig != null:
			rig.shake = 0.6

# Damages every boss inside a cone in front of `origin`. Returns how many were hit.
func _hit_bosses(origin: Vector3, dir: Vector3, reach: float, arc: float, damage: float) -> int:
	var count: int = 0
	for b: Node3D in get_tree().get_nodes_in_group("raid_boss"):
		if not b.alive:
			continue
		var rel := Vector3(b.global_position.x - origin.x, 0.0, b.global_position.z - origin.z)
		var gap: float = rel.length() - b.hit_radius
		if gap > reach:
			continue
		if gap > 0.4 and arc < 359.0 and rel.normalized().dot(dir) < cos(deg_to_rad(arc * 0.5)):
			continue
		b.take_hit(damage, global_position)
		var spot: Vector3 = b.global_position + Vector3(randf_range(-0.6, 0.6), b.hit_height, randf_range(-0.6, 0.6))
		Fx.hit_burst(get_parent(), spot, Color("fff2a8"), 1.0 + damage / 60.0)
		if damage >= 40.0:
			_big_shake(0.35)
		Fx.popup(get_parent(), spot + Vector3(0, 0.6, 0), "%d" % int(damage), Color("fff2a8"))
		count += 1
	return count

func _dash_distance() -> float:
	return UnitData.HERO_SKILLS["dash"]["distance"] / UnitData.PX_PER_M

func _dash_strike() -> void:
	var dmg: float = UnitData.HERO_SKILLS["dash"]["damage"]
	for b: Node3D in get_tree().get_nodes_in_group("raid_boss"):
		if not b.alive or b in _dash_hit:
			continue
		var gap: float = Vector2(b.global_position.x - global_position.x, b.global_position.z - global_position.z).length() - b.hit_radius
		if gap <= 1.2:
			_dash_hit.append(b)
			b.take_hit(dmg, global_position)
			var spot: Vector3 = b.global_position + Vector3(0, b.hit_height, 0)
			Fx.hit_burst(get_parent(), spot)
			Fx.popup(get_parent(), spot + Vector3(0, 0.6, 0), "%d" % int(dmg), Color("fff2a8"))

func _rain(s: Dictionary) -> void:
	var center: Vector3 = global_position + facing * 7.0
	var target: Node3D = _nearest_boss()
	if target != null and Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length() < 14.0:
		center = target.global_position
	var radius: float = s["range"] / UnitData.PX_PER_M * 0.5
	center.y = 0.0
	var ticks: int = s["ticks"]
	Fx.sword_rain(get_parent(), center, radius, s["duration"])
	Fx.ring(get_parent(), center, radius, Color(0.8, 0.9, 1.0, 0.5), 0.5)
	var tw: Tween = create_tween()
	for i in ticks:
		tw.tween_callback(_rain_tick.bind(center, radius, s["damage"]))
		tw.tween_interval(s["duration"] / ticks)

func _rain_tick(center: Vector3, radius: float, damage: float) -> void:
	for b: Node3D in get_tree().get_nodes_in_group("raid_boss"):
		if not b.alive:
			continue
		var d: float = Vector2(b.global_position.x - center.x, b.global_position.z - center.z).length() - b.hit_radius
		if d <= radius:
			b.take_hit(damage, center)
			Fx.popup(get_parent(), b.global_position + Vector3(randf_range(-1, 1), b.hit_height, randf_range(-1, 1)), "%d" % int(damage), Color("dff1ff"), 48)

func _nearest_boss() -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for b: Node3D in get_tree().get_nodes_in_group("raid_boss"):
		if not b.alive:
			continue
		var d: float = Vector2(b.global_position.x - global_position.x, b.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = b
	return best

# Attacks and skills face the nearest boss when it is close, otherwise where the camera looks.
func _face_aim() -> void:
	var aim := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	var target: Node3D = _nearest_boss()
	if target != null:
		var rel := Vector3(target.global_position.x - global_position.x, 0.0, target.global_position.z - global_position.z)
		if rel.length() < AUTO_AIM_RANGE and rel.length() > 0.1:
			aim = rel.normalized()
	facing = aim
	rotation.y = atan2(-facing.x, -facing.z)

# ---------- animation ----------

func play(anim_name: String, speed: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _current == anim_name and is_equal_approx(speed, _anim.speed_scale):
		return
	_current = anim_name
	_anim.speed_scale = speed
	_anim.play(anim_name, 0.08)

# Plays a clip squeezed or stretched to last `duration` seconds.
func play_fit(anim_name: String, duration: float) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	var length: float = _anim.get_animation(anim_name).length
	_current = ""
	play(anim_name, maxf(0.2, length / maxf(duration, 0.05)))

# Back on his feet for a new attempt: full HP, no cooldowns, a moment of invincibility.
func revive() -> void:
	dead = false
	hp = max_hp
	skill_cd.clear()
	haste_t = 0.0
	invincible_t = 1.0
	_atk_t = 0.0
	_lock_t = 0.0
	_roll_t = 0.0
	_dash_t = 0.0
	_queued = false
	_hit_pending = false
	_combo = 0
	velocity = Vector3.ZERO
	Toon.set_flash(_materials, 0.0)
	_current = ""
	play("idle")
	damaged.emit(-1.0)

func _big_shake(amount: float) -> void:
	var rig: Node = get_tree().get_first_node_in_group("raid_camera")
	if rig != null:
		rig.shake = maxf(rig.shake, amount)

# ---------- sword ----------

const SWORDS: Dictionary = {
	"ink": "res://models/sw_ink.glb", "iron": "res://models/sw_iron.glb", "blank": "res://models/sw_blank.glb",
	"blood": "res://models/sw_blood.glb", "colossus": "res://models/sw_colossus.glb", "free": "res://models/sw_free.glb",
}
const SWORD_SCALE: float = 0.62
const HAND_BONE: String = "mixamorigRightHand"
static var sword_id: String = "ink" # chosen in the raid menu (data/raid.gd keeps it saved)

var _sword_attach: BoneAttachment3D

# Puts the chosen sword (models/sw_*.glb, along +Y with the grip near its base) in the hero's right hand.
func _attach_sword() -> void:
	var skeleton: Skeleton3D = null
	for sk: Node in _model.find_children("*", "Skeleton3D", true, false):
		skeleton = sk as Skeleton3D
	if skeleton == null or skeleton.find_bone(HAND_BONE) < 0:
		return
	if _sword_attach != null:
		_sword_attach.queue_free()
	_sword_attach = BoneAttachment3D.new()
	_sword_attach.bone_name = HAND_BONE
	skeleton.add_child(_sword_attach)
	var path: String = SWORDS.get(sword_id, SWORDS["ink"])
	var sword: Node3D = (load(path) as PackedScene).instantiate()
	sword.scale = Vector3.ONE
	sword.position = Vector3.ZERO
	sword.rotation_degrees = Vector3(-125.0, 0, 0) # held ready: tip forward and up
	_sword_attach.add_child(sword)
	Toon.apply_model(sword, SWORD_SCALE * MODEL_SCALE, 0.02, Color.WHITE, 1.15, 0.7, 1.2)
	_fit_sword(sword)

func _fit_sword(sword: Node3D) -> void:
	# The bone pose can carry its own scale, so measure after the skeleton has posed once and compensate.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(sword):
		return
	var first: Node = sword.find_children("*", "MeshInstance3D", true, false)[0]
	var world_scale: float = maxf((first as Node3D).global_transform.basis.get_scale().x, 0.00001)
	sword.scale *= SWORD_SCALE * MODEL_SCALE / world_scale

# Swaps the sword in hand (used by the raid menu).
func set_sword(id: String) -> void:
	sword_id = id
	_attach_sword()
