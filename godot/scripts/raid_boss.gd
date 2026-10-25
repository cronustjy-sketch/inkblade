extends CharacterBody3D

# A raid boss. Chases the hero, picks attacks from its list (each one shows a red ground telegraph first) and
# gets faster with a new attack when it drops to 50% HP. Models are toon-shaded (scripts/toon.gd).
# Each attack is a coroutine named _atk_<id>; bosses are configured in data/raid.gd.

signal hp_changed(hp: float, max_hp: float, phase2: bool)
signal phase_changed
signal defeated

const Toon := preload("res://scripts/toon.gd")
const Arena := preload("res://scripts/raid_arena.gd")
const Fx := preload("res://scripts/raid_fx.gd")
const Telegraph := preload("res://scripts/telegraph.gd")
const PHASE_TWO_AT: float = 0.5

var cfg: Dictionary = {}
var hero: Node3D
var hp: float = 1000.0
var max_hp: float = 1000.0
var alive: bool = true
var active: bool = false
var phase: int = 1
var hit_radius: float = 1.9
var hit_height: float = 3.0
var speed_mult: float = 1.0

var _model: Node3D
var _anim: AnimationPlayer
var _materials: Array[ShaderMaterial] = []
var _attacking: bool = false
var _cooldown: float = 1.8
var _last_attack: String = ""
var _pending_phase2: bool = false
var _invulnerable: bool = false
var _flash_t: float = 0.0
var _current: String = ""
var _clock: float = 0.0
var _hover: float = 0.0
var _scale_factor: float = 1.0

func setup(p_cfg: Dictionary, p_hero: Node3D) -> void:
	cfg = p_cfg
	hero = p_hero
	max_hp = cfg["hp"]
	hp = max_hp
	hit_radius = cfg["hit_radius"]
	hit_height = cfg["hit_height"]
	_scale_factor = float(cfg["scale"]) / 3.0
	_hover = cfg.get("hover", 0.0)

func _ready() -> void:
	add_to_group("raid_boss")
	collision_layer = 0 if cfg["flying"] else 4
	collision_mask = 1
	if cfg["flying"]:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = hit_radius * 0.7
	capsule.height = maxf(hit_height, capsule.radius * 2.0 + 0.2)
	col.shape = capsule
	col.position.y = capsule.height * 0.5
	add_child(col)

	var scene: PackedScene = load(cfg["model"])
	_model = scene.instantiate()
	_model.scale = Vector3.ONE * float(cfg["scale"])
	_model.rotation_degrees.y = cfg["yaw"]
	add_child(_model)
	_materials = Toon.apply_model(_model, float(cfg["scale"]), 0.03, Color.WHITE, cfg.get("brightness", 1.0))
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for anim_name: StringName in _anim.get_animation_list():
			if String(anim_name) in ["idle", "walk", "run"]:
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_set_anim("idle")
	hp_changed.emit(hp, max_hp, false)

# ---------- hits ----------

func take_hit(amount: float, _from: Vector3) -> void:
	if not alive or _invulnerable:
		return
	hp = maxf(0.0, hp - amount)
	_flash_t = 0.09
	Toon.set_flash(_materials, 0.65)
	hp_changed.emit(hp, max_hp, phase == 2)
	if hp <= 0.0:
		_die()
	elif phase == 1 and hp <= max_hp * PHASE_TWO_AT:
		_pending_phase2 = true

func _die() -> void:
	alive = false
	active = false
	collision_layer = 0
	_attacking = false
	if _anim != null and _anim.has_animation(_anim_name("hit")):
		_set_anim("hit")
	Fx.ring(get_parent(), global_position, 9.0, Color(1, 0.9, 0.6, 0.8), 0.7)
	_shake(1.0)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_model, "rotation:x", deg_to_rad(-80.0), 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_model, "position:y", -0.6, 0.9)
	tw.chain().tween_property(_model, "scale", Vector3.ONE * 0.01, 0.5)
	tw.chain().tween_callback(func() -> void: _model.visible = false)
	defeated.emit()

# ---------- main loop ----------

func _physics_process(delta: float) -> void:
	_clock += delta
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			Toon.set_flash(_materials, 0.0)
	if not alive:
		return
	if cfg["flying"]:
		var bob: float = sin(_clock * 2.0) * 0.35
		global_position.y = lerpf(global_position.y, _hover + bob, 1.0 - exp(-4.0 * delta))
	else:
		velocity.y = 0.0 if is_on_floor() else velocity.y - 25.0 * delta
	_static_idle()
	if not active or hero == null or not is_instance_valid(hero) or _hero_dead():
		velocity.x = 0.0
		velocity.z = 0.0
		if not _attacking:
			_set_anim("idle")
		move_and_slide()
		return
	var rel: Vector3 = _flat_to_hero()
	var dist: float = rel.length()
	if _attacking:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	# Chase until within reach, always turning to face the hero.
	if rel.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-rel.x, -rel.z), 1.0 - exp(-5.0 * delta))
	var stop_at: float = hit_radius + 2.0
	if dist > stop_at:
		var dir: Vector3 = rel.normalized()
		var spd: float = float(cfg["speed"]) * speed_mult
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		_set_anim("run" if speed_mult > 1.15 else "walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_anim("idle")
	move_and_slide()
	global_position = Arena.clamp_inside(global_position, Arena.LIMIT - 1.5)
	_cooldown -= delta
	if _cooldown <= 0.0:
		_begin_attack()

func _begin_attack() -> void:
	if _pending_phase2:
		_pending_phase2 = false
		_attacking = true
		await _phase_two()
		_attacking = false
		_cooldown = 0.8
		return
	var pool: Array = (cfg["attacks"] as Array).duplicate()
	if phase == 2:
		pool.append_array(cfg["phase2_attacks"])
		# The new attack is favoured so phase 2 feels different.
		for extra in cfg["phase2_attacks"]:
			pool.append(extra)
	if pool.size() > 1:
		pool.erase(_last_attack)
	var id: String = pool[randi() % pool.size()]
	_last_attack = id
	_attacking = true
	match id:
		"slash":
			await _atk_slash()
		"slam":
			await _atk_slam()
		"charge":
			await _atk_charge()
		"whirl":
			await _atk_whirl()
		"stomp_rings":
			await _atk_stomp_rings()
		"shockwave":
			await _atk_shockwave()
		"quake":
			await _atk_quake()
		"blink":
			await _atk_blink()
		"cross":
			await _atk_cross()
		"frenzy":
			await _atk_frenzy()
		"meteors":
			await _atk_meteors()
		"beam":
			await _atk_beam()
		"void_pulse":
			await _atk_void_pulse()
		"barrage":
			await _atk_barrage()
		_:
			push_warning("raid boss: missing attack " + id)
			await _wait(0.5)
	_attacking = false
	_cooldown = randf_range(0.9, 1.7) / speed_mult

func _phase_two() -> void:
	phase = 2
	_invulnerable = true
	speed_mult = 1.28
	_play_fit("roar", 1.5)
	Fx.ring(get_parent(), global_position, 12.0, Color(1.0, 0.4, 0.2, 0.7), 0.9)
	_shake(0.9)
	Fx.popup(get_parent(), global_position + Vector3(0, hit_height + 1.5, 0), "!", Color("ff5a4a"), 128)
	hp_changed.emit(hp, max_hp, true)
	phase_changed.emit()
	await _wait(1.5, false)
	_invulnerable = false

# ---------- helpers for attacks ----------

func _hero_dead() -> bool:
	return "dead" in hero and hero.dead

func _flat_to_hero() -> Vector3:
	return Vector3(hero.global_position.x - global_position.x, 0.0, hero.global_position.z - global_position.z)

func forward() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))

func _face_hero_now() -> void:
	var rel: Vector3 = _flat_to_hero()
	if rel.length() > 0.01:
		rotation.y = atan2(-rel.x, -rel.z)

# Telegraph warning time: shorter in phase 2.
func _delay(base: float) -> float:
	return base * (0.8 if phase == 2 else 1.0)

# Waits `seconds` (scaled by speed unless told otherwise); returns early-ish if the fight is over.
func _wait(seconds: float, scaled: bool = true) -> void:
	var t: float = seconds / speed_mult if scaled else seconds
	await get_tree().create_timer(maxf(t, 0.01)).timeout

func _ok() -> bool:
	return alive and hero != null and is_instance_valid(hero) and not _hero_dead()

func _world() -> Node3D:
	return get_parent() as Node3D

func _shake(amount: float) -> void:
	var rig: Node = get_tree().get_first_node_in_group("raid_camera")
	if rig != null:
		rig.shake = maxf(rig.shake, amount)

func _impact(center: Vector3, radius: float) -> void:
	Fx.ring(_world(), center, radius, Color(1.0, 0.75, 0.4, 0.7), 0.4)
	_shake(0.45)

# ---------- animation ----------

func _anim_name(logical: String) -> String:
	return cfg["anims"].get(logical, "")

func _set_anim(logical: String, speed: float = 1.0) -> void:
	if _anim == null:
		return
	var clip: String = _anim_name(logical)
	if clip == "" or not _anim.has_animation(clip):
		return
	if _current == clip and is_equal_approx(speed, _anim.speed_scale):
		return
	_current = clip
	_anim.speed_scale = speed
	_anim.play(clip, 0.15)

# Plays a clip stretched to last `duration` seconds (static models get a lean-and-lunge instead).
func _play_fit(logical: String, duration: float) -> void:
	if _anim == null:
		_static_attack(duration)
		return
	var clip: String = _anim_name(logical)
	if clip == "" or not _anim.has_animation(clip):
		return
	var length: float = _anim.get_animation(clip).length
	_current = ""
	_current = clip
	_anim.speed_scale = maxf(0.3, length / maxf(duration, 0.1))
	_anim.play(clip, 0.12)

func _static_idle() -> void:
	if _anim != null or _model == null or not alive:
		return
	_model.position.y = sin(_clock * 2.2) * 0.12

func _static_attack(duration: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_model, "rotation:x", deg_to_rad(-16.0), duration * 0.6)
	tw.tween_property(_model, "rotation:x", deg_to_rad(22.0), duration * 0.15)
	tw.tween_property(_model, "rotation:x", 0.0, duration * 0.35)

# ---------- attacks ----------

func _atk_slash() -> void:
	_face_hero_now()
	var d: float = _delay(0.95)
	Telegraph.cone(_world(), global_position, forward(), 100.0, 6.2 * _scale_factor, d, 28.0, hero)
	_play_fit("slash", d + 0.35)
	await _wait(d + 0.4)

func _atk_slam() -> void:
	_face_hero_now()
	var d: float = _delay(1.1)
	var center: Vector3 = global_position + forward() * (hit_radius * 0.8)
	var t: Node3D = Telegraph.circle(_world(), center, 4.4 * _scale_factor, d, 32.0, hero)
	t.on_strike = _impact.bind(center, 4.4 * _scale_factor)
	_play_fit("slam", d + 0.5)
	await _wait(d + 0.55)

func _atk_charge() -> void:
	_face_hero_now()
	var d: float = _delay(1.0)
	var dir: Vector3 = forward()
	var length: float = clampf(_flat_to_hero().length() + 4.0, 9.0, 24.0)
	var from: Vector3 = global_position
	var t: Node3D = Telegraph.line(_world(), from, dir, length, 2.8, d, 34.0, hero)
	_set_anim("run", 0.6)
	await _wait(d)
	if not alive:
		return
	t.on_strike = _shake.bind(0.4)
	var end: Vector3 = Arena.clamp_inside(from + dir * length, Arena.LIMIT - 1.5)
	_set_anim("run", 1.6)
	var tw: Tween = create_tween()
	tw.tween_property(self, "global_position", end, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	await _wait(0.5)

func _atk_whirl() -> void:
	var d: float = _delay(1.0)
	var radius: float = 6.8 * _scale_factor
	var t: Node3D = Telegraph.circle(_world(), global_position, radius, d, 30.0, hero)
	t.on_strike = _impact.bind(global_position, radius)
	_play_fit("swipe", d + 0.4)
	await _wait(maxf(d - 0.25, 0.1))
	if alive:
		var spin: Tween = create_tween()
		spin.tween_property(_model, "rotation:y", _model.rotation.y + TAU, 0.5)
	await _wait(0.9)

# Three stomps, each landing where the hero stood when it started.
func _atk_stomp_rings() -> void:
	for i in 3:
		if not _ok():
			break
		_face_hero_now()
		var center := Vector3(hero.global_position.x, 0.0, hero.global_position.z)
		var radius: float = 2.9 * _scale_factor
		var t: Node3D = Telegraph.circle(_world(), center, radius, _delay(0.9), 22.0, hero)
		t.on_strike = _impact.bind(center, radius)
		_play_fit("slam", 0.75)
		await _wait(0.68)
	await _wait(0.9)

# A shockwave that rolls out across the arena; roll through it (invincible) or keep clear of the ring.
func _atk_shockwave() -> void:
	var d: float = _delay(1.3)
	var t: Node3D = Telegraph.ring(_world(), global_position, 15.0, d, 30.0, hero)
	t.wave_time = 0.9
	t.on_strike = _shake.bind(0.7)
	_play_fit("slam", d + 0.6)
	await _wait(d + 1.3)

# Phase 2: two shockwaves back to back.
func _atk_quake() -> void:
	for i in 2:
		if not _ok():
			break
		var t: Node3D = Telegraph.ring(_world(), global_position, 17.0, _delay(1.1), 30.0, hero)
		t.wave_time = 0.8
		t.on_strike = _shake.bind(0.8)
		_play_fit("slam", _delay(1.1) + 0.5)
		await _wait(_delay(1.1) + 0.9)
	await _wait(0.6)

# Vanishes, then reappears on the red circle drawn under the hero and strikes.
func _atk_blink(warn: float = 0.95) -> void:
	var center := Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	var radius: float = 3.3 * _scale_factor
	var d: float = _delay(warn)
	var t: Node3D = Telegraph.circle(_world(), center, radius, d, 30.0, hero)
	_play_fit("swipe", 0.35)
	await _wait(0.3)
	if not alive:
		return
	_model.visible = false
	Fx.ring(_world(), global_position, 3.0, Color(0.7, 0.4, 1.0, 0.7), 0.3)
	t.on_strike = _blink_land.bind(center, radius)
	await _wait(maxf(d - 0.3, 0.05) + 0.7)
	_model.visible = alive

func _blink_land(center: Vector3, radius: float) -> void:
	global_position = Arena.clamp_inside(Vector3(center.x, global_position.y, center.z), Arena.LIMIT - 1.5)
	_model.visible = true
	rotation.y = atan2(-(hero.global_position.x - center.x), -(hero.global_position.z - center.z))
	_play_fit("slam", 0.6)
	_impact(center, radius)

# Two long lines crossing under the hero.
func _atk_cross() -> void:
	_face_hero_now()
	var center := Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	var d: float = _delay(1.15)
	var base: Vector3 = forward()
	var first: Vector3 = base.rotated(Vector3.UP, deg_to_rad(45.0))
	var second: Vector3 = base.rotated(Vector3.UP, deg_to_rad(-45.0))
	for dir: Vector3 in [first, second]:
		var t: Node3D = Telegraph.line(_world(), center - dir * 9.0, dir, 18.0, 2.4, d, 28.0, hero)
		t.on_strike = _shake.bind(0.4)
	_play_fit("swipe", d + 0.4)
	await _wait(d + 0.7)

# Phase 2: three quick blinks in a row.
func _atk_frenzy() -> void:
	for i in 3:
		if not _ok():
			break
		await _atk_blink(0.75)
	await _wait(0.4)

# A falling rock that lands exactly when the circle on the ground fills up.
func _meteor(center: Vector3, radius: float, warn: float, damage: float) -> void:
	var t: Node3D = Telegraph.circle(_world(), center, radius, warn, damage, hero)
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.35
	sphere.height = radius * 0.7
	sphere.radial_segments = 12
	sphere.rings = 6
	rock.mesh = sphere
	rock.material_override = Toon.flat(Color("5a3a8a"), 0.08)
	_world().add_child(rock)
	rock.global_position = Vector3(center.x, 18.0, center.z)
	var tw: Tween = rock.create_tween()
	tw.tween_property(rock, "global_position:y", radius * 0.3, warn).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(rock.queue_free)
	t.on_strike = _impact.bind(center, radius)

func _atk_meteors(count: int = 7) -> void:
	_face_hero_now()
	_play_fit("roar", 1.0)
	await _wait(0.4)
	var radius: float = 2.4
	for i in count:
		if not _ok():
			break
		var spot := Vector3(hero.global_position.x, 0.0, hero.global_position.z)
		if i > 0:
			spot += Vector3(randf_range(-9.0, 9.0), 0.0, randf_range(-9.0, 9.0))
		spot = Arena.clamp_inside(spot, Arena.LIMIT - 2.0)
		_meteor(spot, radius, _delay(1.25), 24.0)
		await _wait(0.24)
	await _wait(_delay(1.25) + 0.3)

func _atk_beam(angle_offset: float = 0.0, with_wait: bool = true) -> void:
	_face_hero_now()
	var d: float = _delay(1.3)
	var dir: Vector3 = forward().rotated(Vector3.UP, deg_to_rad(angle_offset))
	var from: Vector3 = global_position + dir * 1.5
	var t: Node3D = Telegraph.line(_world(), from, dir, 28.0, 2.8, d, 36.0, hero)
	t.on_strike = _shake.bind(0.6)
	_play_fit("slash", d + 0.4)
	if with_wait:
		await _wait(d + 0.8)

# Two expanding rings around the hero's position: out of the inner ring, then out of the outer one.
func _atk_void_pulse() -> void:
	_face_hero_now()
	var center := Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	_play_fit("roar", 1.4)
	var first: Node3D = Telegraph.ring(_world(), center, 6.0, _delay(1.1), 28.0, hero)
	first.wave_time = 0.7
	await _wait(0.7)
	var second: Node3D = Telegraph.ring(_world(), center, 10.5, _delay(1.1), 28.0, hero)
	second.wave_time = 0.9
	await _wait(_delay(1.1) + 1.0)

# Phase 2: two angled beams, then a short meteor shower.
func _atk_barrage() -> void:
	_face_hero_now()
	var d: float = _delay(1.3)
	var dir: Vector3 = forward()
	for angle: float in [-24.0, 24.0]:
		var side: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(angle))
		var t: Node3D = Telegraph.line(_world(), global_position + side * 1.5, side, 28.0, 2.8, d, 36.0, hero)
		t.on_strike = _shake.bind(0.6)
	_play_fit("slash", d + 0.4)
	await _wait(d + 0.9)
	await _atk_meteors(4)
