extends CharacterBody3D

# A raid boss. Chases the hero, picks moves from its list (each one shows a red ground telegraph first) and gets
# faster with new moves when it drops to 50% HP. The moves are the web game's 3D boss moves (dash, slam, wave, meteor,
# fan, summon, beam, blink, spin, pillars, rain, cross, orbit, pull, stroke, hand, paint); each one is a coroutine named
# _mv_<id>. Bosses are configured in data/raid.gd. They use a .glb model when the config names one, otherwise a body
# built from primitives (scripts/raid_body.gd).

signal hp_changed(hp: float, max_hp: float, phase2: bool)
signal phase_changed
signal defeated
signal move_started(name_cn: String, tip: String)

const Toon := preload("res://scripts/toon.gd")
const Arena := preload("res://scripts/raid_arena.gd")
const Fx := preload("res://scripts/raid_fx.gd")
const Telegraph := preload("res://scripts/telegraph.gd")
const Body := preload("res://scripts/raid_body.gd")
const Orb := preload("res://scripts/raid_orb.gd")
const Minion := preload("res://scripts/raid_minion.gd")
const Gb3 := preload("res://data/gb3_data.gd")
const PHASE_TWO_AT: float = 0.5
# The web game's logical animation for each move.
const MOVE_ANIM: Dictionary = {"dash": "run", "slam": "slam", "wave": "slam", "pillars": "slam", "meteor": "roar", "summon": "roar",
	"beam": "roar", "rain": "roar", "pull": "roar", "hand": "roar", "fan": "swipe", "spin": "swipe", "orbit": "swipe",
	"blink": "slash", "cross": "slash", "stroke": "slash", "paint": "roar"}
const EXTRA_NAMES: Dictionary = {"hand": ["灵魂之手", "离开墨云"], "paint": ["画界", "找没被画的地方站"]}

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

var _model: Node3D # holder for the visual (a .glb scene or the procedural body)
var _rig: Dictionary = {} # procedural body rig (empty when a .glb is used)
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
var _lift: float = 0.0 # temporary jump height (slam)
var _atk_pose: float = 0.0
var _pose_tween: Tween
var _scale_factor: float = 1.0
var _shadow: MeshInstance3D
var _orbit_angle: float = 0.0
var _walk_amt: float = 0.0
var _moves: Array = []
var _accent: Color = Color("ff5a4a")

func setup(p_cfg: Dictionary, p_hero: Node3D) -> void:
	cfg = p_cfg
	hero = p_hero
	max_hp = cfg["hp"]
	hp = max_hp
	hit_radius = cfg["hit_radius"]
	hit_height = cfg["hit_height"]
	_scale_factor = clampf(float(cfg["scale"]) / 3.0, 0.8, 1.35)
	_hover = cfg.get("hover", 0.0)
	_moves = (cfg["moves"] as Array).duplicate()
	var colors: Array = cfg["colors"]
	_accent = colors[1]

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

	_model = Node3D.new()
	add_child(_model)
	var model_path: String = cfg.get("model", "")
	if model_path != "" and ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		var inst: Node3D = scene.instantiate()
		inst.scale = Vector3.ONE * float(cfg["scale"])
		inst.rotation_degrees.y = cfg["yaw"]
		_model.add_child(inst)
		_materials = Toon.apply_model(inst, float(cfg["scale"]), 0.035, cfg.get("tint", Color.WHITE), cfg.get("brightness", 1.2))
		_anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _anim != null:
			for anim_name: StringName in _anim.get_animation_list():
				if String(anim_name) in ["idle", "walk", "run"]:
					_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	else:
		_rig = Body.build(cfg)
		var root: Node3D = _rig["root"]
		root.rotation_degrees.y = 90.0 # the body is built facing +X; the boss faces -Z
		_model.add_child(root)
		for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mat: Material = (mi as MeshInstance3D).material_override
			if mat is ShaderMaterial and not _materials.has(mat):
				_materials.append(mat)
	_shadow = Fx.blob_shadow(get_parent() if get_parent() != null else self, hit_radius * 0.95)
	_set_anim("idle")
	tree_exiting.connect(func() -> void:
		if _shadow != null and is_instance_valid(_shadow):
			_shadow.queue_free())
	hp_changed.emit(hp, max_hp, false)

# ---------- hits ----------

func take_hit(amount: float, _from: Vector3) -> void:
	if not alive or _invulnerable:
		return
	hp = maxf(0.0, hp - amount)
	_flash_t = 0.12
	Toon.set_flash(_materials, 0.9, Color.WHITE)
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
	_model.visible = true
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
	if _shadow != null and is_instance_valid(_shadow):
		Fx.place_shadow(_shadow, self, maxf(global_position.y - 0.0, 0.0) + _lift)
		_shadow.visible = alive
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
	_pose(delta)
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
	if cfg.has("orbit"):
		# Flyer: circles the hero at a fixed radius instead of standing off.
		_orbit_angle += delta * 0.55 * speed_mult
		var ring := Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * float(cfg["orbit"])
		var goal := Vector3(hero.global_position.x + ring.x, 0.0, hero.global_position.z + ring.z)
		goal = Arena.clamp_inside(goal, Arena.LIMIT - 3.0)
		var to_goal: Vector3 = Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
		var spd: float = minf(to_goal.length() * 3.0, float(cfg["speed"]) * 2.4 * speed_mult)
		var move_dir: Vector3 = to_goal.normalized() if to_goal.length() > 0.05 else Vector3.ZERO
		velocity.x = move_dir.x * spd
		velocity.z = move_dir.z * spd
		move_and_slide()
		_cooldown -= delta
		if _cooldown <= 0.0:
			_begin_attack()
		return
	# Spirits and flyers keep their distance, everything else walks up to the hero.
	var stop_at: float = float(cfg.get("keep", hit_radius + 2.0))
	var body: String = cfg.get("body", "blade")
	if cfg.get("model", "") == "" and (body == "spirit" or body == "flyer"):
		stop_at = 8.0
	if dist > stop_at:
		var dir: Vector3 = rel.normalized()
		var spd: float = float(cfg["speed"]) * speed_mult
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		_walk_amt = lerpf(_walk_amt, 1.0, 0.2)
		_set_anim("run" if speed_mult > 1.15 else "walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_walk_amt = lerpf(_walk_amt, 0.0, 0.2)
		_set_anim("idle")
	move_and_slide()
	global_position = Arena.clamp_inside(global_position, Arena.LIMIT - 1.5)
	_cooldown -= delta
	if _cooldown <= 0.0:
		_begin_attack()

# Per-frame posing: the procedural body animates in code, static models bob.
func _pose(delta: float) -> void:
	if not _rig.is_empty():
		var walking: float = _walk_amt if not _attacking else 0.0
		Body.animate(_rig, _clock, walking, _atk_pose, 5.0 + float(cfg["speed"]))
		(_rig["root"] as Node3D).position.y += _lift
		return
	if _anim == null and alive:
		_model.position.y = sin(_clock * 2.2) * 0.12 + _lift
	elif alive:
		_model.position.y = _lift

func _begin_attack() -> void:
	if _pending_phase2:
		_pending_phase2 = false
		_attacking = true
		await _phase_two()
		_attacking = false
		_cooldown = 0.8
		return
	var pool: Array = _moves.duplicate()
	if pool.size() > 1:
		pool.erase(_last_attack)
	var id: String = pool[randi() % pool.size()]
	_last_attack = id
	_attacking = true
	var names: Array = _move_name(id)
	move_started.emit(names[0], names[1])
	var method: String = "_mv_" + id
	if has_method(method):
		await call(method)
	else:
		push_warning("raid boss: missing move " + id)
		await _t(0.5)
	_attacking = false
	_lift = 0.0
	var base: float = float(cfg.get("cd", 1.4)) * (0.72 if phase == 2 else 1.0) * randf_range(0.75, 1.25)
	if randf() < float(cfg.get("chain", 0.0)):
		base = 0.12
	_cooldown = base

func _move_name(id: String) -> Array:
	if Gb3.MOVE_NAMES.has(id):
		var n: Dictionary = Gb3.MOVE_NAMES[id]
		return [n["cn"], n["tip"]]
	return EXTRA_NAMES.get(id, [id, ""])

func _phase_two() -> void:
	phase = 2
	_invulnerable = true
	speed_mult = 1.2
	for extra: String in cfg["moves2"]:
		if not _moves.has(extra):
			_moves.append(extra)
	_play_fit("roar", 1.5)
	Fx.ring(get_parent(), global_position, 12.0, Color(1.0, 0.4, 0.2, 0.7), 0.9)
	_shake(0.9)
	Fx.popup(get_parent(), global_position + Vector3(0, hit_height + 1.5, 0), "!", Color("ff5a4a"), 128)
	hp_changed.emit(hp, max_hp, true)
	phase_changed.emit()
	await _t(1.5)
	_invulnerable = false

# ---------- helpers for attacks ----------

func _hero_dead() -> bool:
	return "dead" in hero and hero.dead

func _flat_to_hero() -> Vector3:
	return Vector3(hero.global_position.x - global_position.x, 0.0, hero.global_position.z - global_position.z)

func _hero_spot() -> Vector3:
	return Vector3(hero.global_position.x, 0.0, hero.global_position.z)

func forward() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))

func _face_hero_now() -> void:
	var rel: Vector3 = _flat_to_hero()
	if rel.length() > 0.01:
		rotation.y = atan2(-rel.x, -rel.z)

# Damage of a move: the move's base value scaled by the boss and (a little) by phase 2.
func _dmg(base: float) -> float:
	return base * float(cfg.get("dm", 1.0)) * (1.15 if phase == 2 else 1.0)

# Telegraph warning time: shorter in phase 2.
func _delay(base: float) -> float:
	return base * (0.85 if phase == 2 else 1.0)

# Waits `seconds` of game time (not scaled by speed, so the web's move timings carry over).
func _t(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.01)).timeout

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
	Fx.hit_burst(_world(), center + Vector3(0, 0.5, 0), _accent, 1.4)
	_shake(0.45)

func _circle(center: Vector3, radius: float, warn: float, base_damage: float) -> Node3D:
	var t: Node3D = Telegraph.circle(_world(), center, radius, warn, _dmg(base_damage), hero)
	t.on_strike = _impact.bind(center, radius)
	return t

func _beam_visual(from: Vector3, dir: Vector3, length: float, width: float, color: Color) -> void:
	var bm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width * 0.8, 0.5, length)
	bm.mesh = box
	var mat: StandardMaterial3D = Fx.flat_material(Color(color.r, color.g, color.b, 0.9), true)
	bm.material_override = mat
	_world().add_child(bm)
	bm.global_position = Vector3(from.x, 0.6, from.z) + dir * length * 0.5
	bm.rotation.y = atan2(-dir.x, -dir.z)
	var tw: Tween = bm.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(bm.queue_free)

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

# Plays a clip stretched to last `duration` seconds (procedural / static models get a wind-up and strike instead).
func _play_fit(logical: String, duration: float) -> void:
	if _anim == null:
		_static_attack(duration)
		return
	var clip: String = _anim_name(logical)
	if clip == "" or not _anim.has_animation(clip):
		return
	var length: float = _anim.get_animation(clip).length
	_current = clip
	_anim.speed_scale = maxf(0.3, length / maxf(duration, 0.1))
	_anim.play(clip, 0.12)

func _play_move(id: String, duration: float) -> void:
	_play_fit(MOVE_ANIM.get(id, "slash"), duration)

func _static_attack(duration: float) -> void:
	if not _rig.is_empty():
		if _pose_tween != null and _pose_tween.is_valid():
			_pose_tween.kill()
		_pose_tween = create_tween()
		_pose_tween.tween_property(self, "_atk_pose", 1.0, duration * 0.7)
		_pose_tween.tween_property(self, "_atk_pose", 0.0, 0.3)
		return
	var tw: Tween = create_tween()
	tw.tween_property(_model, "rotation:x", deg_to_rad(-16.0), duration * 0.6)
	tw.tween_property(_model, "rotation:x", deg_to_rad(22.0), duration * 0.15)
	tw.tween_property(_model, "rotation:x", 0.0, duration * 0.35)

# ---------- moves ----------

# A red line, then a rush along it.
func _mv_dash() -> void:
	_face_hero_now()
	var dir: Vector3 = forward()
	var from := Vector3(global_position.x, 0.0, global_position.z)
	var length: float = 18.0
	var warn: float = _delay(0.65)
	var t: Node3D = Telegraph.line(_world(), from, dir, length, 2.4, warn, _dmg(20.0), hero)
	t.on_strike = _shake.bind(0.4)
	_set_anim("run", 0.6)
	if not cfg["flying"] and _anim == null:
		_play_fit("slash", warn + 0.4)
	await _t(warn)
	if not alive:
		return
	var end: Vector3 = Arena.clamp_inside(from + dir * length, Arena.LIMIT - 1.5)
	_set_anim("run", 1.6)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "global_position:x", end.x, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position:z", end.z, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if cfg["flying"]:
		tw.tween_property(self, "_hover", 1.8, 0.25)
	await tw.finished
	if cfg["flying"]:
		create_tween().tween_property(self, "_hover", float(cfg.get("hover", 6.0)), 0.7)
	await _t(0.45)

# Jumps onto the spot where the hero stood.
func _mv_slam() -> void:
	_face_hero_now()
	var to: Vector3 = _hero_spot()
	var from := Vector3(global_position.x, 0.0, global_position.z)
	var warn: float = _delay(0.95)
	_circle(to, 3.6, warn, 24.0)
	_play_move("slam", warn + 0.5)
	var tw: Tween = create_tween()
	tw.tween_method(_jump_step.bind(from, to, 4.5), 0.0, 1.0, warn)
	await tw.finished
	_lift = 0.0
	await _t(0.6)

func _jump_step(q: float, from: Vector3, to: Vector3, hop: float) -> void:
	var p: Vector3 = Arena.clamp_inside(from.lerp(to, q), Arena.LIMIT - 1.5)
	global_position = Vector3(p.x, global_position.y, p.z)
	_lift = sin(q * PI) * hop

# A shockwave that rolls out across the arena; roll through it (invincible) or keep clear of the ring.
func _mv_wave() -> void:
	var warn: float = _delay(0.55)
	var t: Node3D = Telegraph.ring(_world(), global_position, 20.0, warn, _dmg(18.0), hero)
	t.wave_time = 1.3
	t.on_strike = _shake.bind(0.5)
	_play_move("wave", warn + 0.6)
	await _t(1.9)

# A falling rock that lands exactly when the circle on the ground fills up.
func _meteor(center: Vector3, radius: float, warn: float, damage: float) -> void:
	var t: Node3D = Telegraph.circle(_world(), center, radius, warn, _dmg(damage), hero)
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.35
	sphere.height = radius * 0.7
	sphere.radial_segments = 12
	sphere.rings = 6
	rock.mesh = sphere
	var mat: ShaderMaterial = Toon.flat(_accent, 0.08)
	mat.set_shader_parameter("emission", 0.6)
	rock.material_override = mat
	_world().add_child(rock)
	rock.global_position = Vector3(center.x, 20.0, center.z)
	var tw: Tween = rock.create_tween()
	tw.tween_property(rock, "global_position:y", radius * 0.3, warn).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(rock.queue_free)
	t.on_strike = _impact.bind(center, radius)

func _mv_meteor() -> void:
	_play_move("meteor", 1.0)
	var count: int = 7 if phase == 2 else 5
	for i in count:
		if not _ok():
			break
		var spot: Vector3 = _hero_spot()
		if i > 0:
			var a: float = randf() * TAU
			var r: float = 2.0 + randf() * 7.0
			spot += Vector3(cos(a) * r, 0.0, sin(a) * r)
		spot = Arena.clamp_inside(spot, Arena.LIMIT - 2.0)
		_meteor(spot, 2.4, 0.9, 16.0)
		await _t(0.16)
	await _t(1.0)

# A fan of ink orbs.
func _mv_fan() -> void:
	_face_hero_now()
	_play_move("fan", 1.0)
	await _t(0.4)
	var volleys: int = 2 if phase == 2 else 1
	for v in volleys:
		if not _ok():
			return
		var base: Vector3 = _flat_to_hero().normalized()
		var n: int = 9 if phase == 2 else 7
		var origin: Vector3 = global_position + Vector3(0, 1.6 + _hover * 0.4, 0) + base * 1.5
		for i in n:
			var dir: Vector3 = base.rotated(Vector3.UP, (i - (n - 1) * 0.5) * 0.17)
			var mover: Callable = func(age: float, _dt: float) -> Vector3: return origin + dir * 15.0 * age
			Orb.spawn(_world(), _accent, 0.3, hero, _dmg(11.0), 0.9, 2.2, mover, origin)
		await _t(0.35)
	await _t(0.3)

# Calls ink soldiers.
func _mv_summon() -> void:
	_play_move("summon", 1.2)
	Fx.ring(_world(), global_position, 6.0, Color(_accent, 0.7), 0.5)
	var colors: Array = cfg["colors"]
	if get_tree().get_nodes_in_group("raid_minion").size() < 8:
		for i in 3:
			var a: float = float(i) / 3.0 * TAU + randf()
			var spot: Vector3 = Arena.clamp_inside(global_position + Vector3(cos(a), 0, sin(a)) * 4.0, Arena.LIMIT - 1.5)
			var m: Node3D = Node3D.new()
			m.set_script(Minion)
			_world().add_child(m)
			m.global_position = Vector3(spot.x, 0.0, spot.z)
			m.setup(hero, colors[0], colors[1])
			Fx.hit_burst(_world(), m.global_position + Vector3(0, 1, 0), _accent, 1.0)
	await _t(1.2)

# A long beam along a red line.
func _mv_beam() -> void:
	_face_hero_now()
	var dir: Vector3 = forward()
	var from := Vector3(global_position.x, 0.0, global_position.z)
	var warn: float = _delay(0.9)
	var t: Node3D = Telegraph.line(_world(), from, dir, 32.0, 2.8, warn, _dmg(24.0), hero)
	t.on_strike = func() -> void:
		_shake(0.5)
		_beam_visual(from, dir, 32.0, 2.8, _accent)
	_play_move("beam", warn + 0.5)
	await _t(1.8)

# Vanishes and reappears behind the hero.
func _mv_blink() -> void:
	await _t(0.1)
	if not alive:
		return
	Fx.hit_burst(_world(), global_position + Vector3(0, hit_height * 0.4, 0), _accent, 1.4)
	_model.visible = false
	_invulnerable = true
	await _t(0.4)
	if not alive:
		return
	var behind: Vector3 = _hero_spot() - hero.facing * 2.6
	var spot: Vector3 = Arena.clamp_inside(behind, Arena.LIMIT - 1.5)
	global_position = Vector3(spot.x, global_position.y, spot.z)
	_face_hero_now()
	_model.visible = true
	_invulnerable = false
	Fx.hit_burst(_world(), global_position + Vector3(0, hit_height * 0.4, 0), _accent, 1.4)
	var warn: float = _delay(0.35)
	_circle(Vector3(spot.x, 0.0, spot.z), 2.6, warn, 22.0)
	_play_move("blink", warn + 0.3)
	await _t(0.9)

# Spins toward the hero, hurting everything near it.
func _mv_spin() -> void:
	_play_move("spin", 1.0)
	Fx.ring(_world(), global_position, hit_radius + 1.8, Color(1, 0.3, 0.2, 0.5), 0.4)
	var elapsed: float = 0.0
	var tick: float = 0.0
	var spin_start: float = _model.rotation.y
	while elapsed < 2.3 and _ok():
		var dt: float = get_physics_process_delta_time()
		await get_tree().physics_frame
		elapsed += dt
		var rel: Vector3 = _flat_to_hero()
		var d: float = rel.length()
		if d > 0.05:
			global_position = Arena.clamp_inside(global_position + rel / d * 6.5 * dt, Arena.LIMIT - 1.5)
		_model.rotation.y += 22.0 * dt
		tick -= dt
		if tick <= 0.0 and d < hit_radius + 1.8:
			tick = 0.3
			hero.take_damage(_dmg(9.0))
			Fx.hit_burst(_world(), hero.global_position + Vector3(0, 1.0, 0), _accent, 0.8)
	_model.rotation.y = spin_start
	await _t(0.3)

# Ink pillars rise one after the other along a line toward the hero.
func _mv_pillars() -> void:
	_face_hero_now()
	var dir: Vector3 = forward()
	var origin := Vector3(global_position.x, 0.0, global_position.z)
	var n: int = 9 if phase == 2 else 7
	_play_move("pillars", 1.2)
	for i in n:
		if not alive:
			return
		var spot: Vector3 = origin + dir * (2.5 + i * 2.4)
		if Vector2(spot.x, spot.z).length() < Arena.LIMIT - 1.0:
			var t: Node3D = Telegraph.circle(_world(), spot, 1.6, _delay(0.55), _dmg(18.0), hero)
			t.on_strike = _pillar.bind(spot)
		await _t(0.17)
	await _t(1.0)

func _pillar(spot: Vector3) -> void:
	var pl := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 1.3
	cyl.height = 5.0
	cyl.radial_segments = 8
	pl.mesh = cyl
	pl.material_override = Toon.flat(Color("14141c"), 0.06)
	_world().add_child(pl)
	pl.global_position = Vector3(spot.x, -2.5, spot.z)
	var tw: Tween = pl.create_tween()
	tw.tween_property(pl, "global_position:y", 2.0, 0.12)
	tw.tween_interval(0.3)
	tw.tween_property(pl, "global_position:y", -2.6, 0.2)
	tw.tween_callback(pl.queue_free)
	_impact(spot, 1.7)

# A rain of ink around the hero.
func _mv_rain() -> void:
	_play_move("rain", 1.0)
	for i in 12:
		if not _ok():
			break
		var a: float = randf() * TAU
		var r: float = randf() * 8.0
		var spot: Vector3 = Arena.clamp_inside(_hero_spot() + Vector3(cos(a) * r, 0, sin(a) * r), Arena.LIMIT - 1.5)
		_circle(spot, 1.8, _delay(0.7), 13.0)
		await _t(0.18)
	await _t(0.8)

# Two long lines crossing under the hero.
func _mv_cross() -> void:
	_play_move("cross", 1.0)
	var center: Vector3 = _hero_spot()
	var a: float = randf() * PI
	var warn: float = _delay(1.0)
	for k in 2:
		var dir := Vector3(sin(a + k * PI * 0.5), 0.0, cos(a + k * PI * 0.5))
		var t: Node3D = Telegraph.line(_world(), center - dir * 14.0, dir, 28.0, 2.4, warn, _dmg(18.0), hero)
		t.on_strike = _cross_strike.bind(center - dir * 14.0, dir)
	await _t(1.7)

func _cross_strike(from: Vector3, dir: Vector3) -> void:
	_shake(0.45)
	_beam_visual(from, dir, 28.0, 2.4, Color.WHITE)

# Orbs circle out from the boss in a widening ring.
func _mv_orbit() -> void:
	_play_move("orbit", 1.2)
	var n: int = 6 if phase == 2 else 4
	for i in n:
		var offset: float = float(i) / float(n) * TAU
		var mover: Callable = func(age: float, _dt: float) -> Vector3:
			var r: float = 2.0 + age / 3.1 * 14.0
			var a: float = age * 2.4 + offset
			return Vector3(global_position.x + cos(a) * r, 1.2, global_position.z + sin(a) * r)
		Orb.spawn(_world(), _accent, 0.45, hero, _dmg(12.0), 1.0, 3.1, mover, global_position)
	await _t(3.3)

# Drags the hero in, then bursts. Rolling (invincible) breaks free.
func _mv_pull() -> void:
	_play_move("pull", 1.4)
	var center := Vector3(global_position.x, 0.0, global_position.z)
	var t: Node3D = Telegraph.circle(_world(), center, 4.2, 1.75, _dmg(26.0), hero)
	t.on_strike = func() -> void:
		_shake(0.6)
		Fx.ring(_world(), center, 8.0, Color(_accent, 0.8), 0.5)
		Fx.hit_burst(_world(), center + Vector3(0, 0.5, 0), _accent, 2.0)
	var elapsed: float = 0.0
	while elapsed < 1.3 and _ok():
		var dt: float = get_physics_process_delta_time()
		await get_tree().physics_frame
		elapsed += dt
		var rel: Vector3 = center - _hero_spot()
		if rel.length() > 2.5 and hero.invincible_t <= 0.0:
			hero.global_position += rel.normalized() * 7.5 * dt
	await _t(0.9)

# A white stroke of nothingness: hurts when it lands, and the white ground keeps hurting for a while.
func _mv_stroke() -> void:
	_face_hero_now()
	_play_move("stroke", 1.0)
	var rel: Vector3 = _flat_to_hero().normalized().rotated(Vector3.UP, randf_range(-0.3, 0.3))
	var from: Vector3 = _hero_spot() - rel * 16.0
	var warn: float = _delay(1.0)
	var t: Node3D = Telegraph.line(_world(), from, rel, 32.0, 3.6, warn, _dmg(22.0), hero)
	t.on_strike = _stroke_strike.bind(from, rel)
	await _t(2.2)

func _stroke_strike(from: Vector3, dir: Vector3) -> void:
	_shake(0.5)
	_beam_visual(from, dir, 32.0, 3.6, Color.WHITE)
	_white_strip(from, dir, 32.0, 3.4, 5.0)

# A lingering white strip on the ground that ticks damage.
func _white_strip(from: Vector3, dir: Vector3, length: float, width: float, duration: float) -> void:
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.04, length)
	strip.mesh = box
	var mat: StandardMaterial3D = Fx.flat_material(Color(1, 1, 1, 0.8))
	strip.material_override = mat
	var world: Node3D = _world()
	world.add_child(strip)
	strip.global_position = Vector3(from.x, 0.1, from.z) + dir * length * 0.5
	strip.rotation.y = atan2(-dir.x, -dir.z)
	var tween: Tween = strip.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.tween_callback(strip.queue_free)
	var elapsed: float = 0.0
	var tick: float = 0.0
	while elapsed < duration and is_instance_valid(strip) and _ok():
		var dt: float = get_physics_process_delta_time()
		await get_tree().physics_frame
		elapsed += dt
		tick -= dt
		if tick <= 0.0 and hero.is_on_floor() and _in_strip(from, dir, length, width):
			tick = 0.5
			hero.take_damage(_dmg(6.0))

func _in_strip(from: Vector3, dir: Vector3, length: float, width: float) -> bool:
	var rel: Vector3 = _hero_spot() - from
	var along: float = rel.dot(dir)
	var side: float = absf(rel.dot(Vector3(-dir.z, 0, dir.x)))
	return along > -1.0 and along < length and side < width * 0.5 + 0.4

# A giant spirit hand rises out of an ink cloud under the hero and crushes the spot.
func _mv_hand() -> void:
	_play_move("hand", 1.2)
	var spot: Vector3 = _hero_spot()
	var warn: float = _delay(0.95)
	var t: Node3D = Telegraph.circle(_world(), spot, 3.2, warn, _dmg(26.0), hero)
	var purple: Color = Color("8a5aff")
	var hand := Node3D.new()
	var mat: ShaderMaterial = Toon.flat(purple, 0.05)
	mat.set_shader_parameter("emission", 0.5)
	var palm := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(2.4, 2.6, 0.8)
	palm.mesh = pbox
	palm.material_override = mat
	palm.position.y = 1.3
	hand.add_child(palm)
	var fingers: Array[Node3D] = []
	for i in 4:
		var f := Node3D.new()
		f.position = Vector3(-0.9 + i * 0.6, 2.6, 0)
		var fm := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.45, 1.6, 0.6)
		fm.mesh = fb
		fm.material_override = mat
		fm.position.y = 0.8
		f.add_child(fm)
		hand.add_child(f)
		fingers.append(f)
	_world().add_child(hand)
	hand.global_position = Vector3(spot.x, -6.0, spot.z)
	hand.rotation.y = rotation.y
	var tw: Tween = hand.create_tween()
	tw.tween_property(hand, "global_position:y", -0.8, 0.9)
	tw.tween_callback(func() -> void:
		for f in fingers:
			create_tween().tween_property(f, "rotation:x", 1.9, 0.2))
	tw.tween_interval(0.55)
	tw.tween_property(hand, "global_position:y", -7.0, 0.5)
	tw.tween_callback(hand.queue_free)
	t.on_strike = func() -> void:
		_shake(0.9)
		Fx.hit_burst(_world(), spot + Vector3(0, 1.5, 0), purple, 2.0)
		Fx.ring(_world(), spot, 3.2, Color(purple, 0.8), 0.4)
	await _t(2.4)

# Paints the arena in gold bands for a few seconds: stand where it is not painted. Gold fists fall meanwhile.
func _mv_paint() -> void:
	_play_move("paint", 1.2)
	var bands: Array[Dictionary] = []
	var a0: float = randf() * PI
	var off: float = (1.0 if randf() < 0.5 else -1.0) * (3.0 + randf() * 5.0)
	bands.append({"a": a0, "off": off, "w": 10.0})
	if randf() < 0.6:
		bands.append({"a": a0 + 1.4, "off": -off, "w": 7.0})
	var visuals: Array[MeshInstance3D] = []
	var mats: Array[StandardMaterial3D] = []
	for b: Dictionary in bands:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(b["w"], 0.03, Arena.LIMIT * 2.0 + 6.0)
		mi.mesh = box
		var m: StandardMaterial3D = Fx.flat_material(Color(1, 1, 1, 0.22))
		mi.material_override = m
		_world().add_child(mi)
		var dir := Vector3(sin(float(b["a"])), 0.0, cos(float(b["a"])))
		var side := Vector3(-dir.z, 0, dir.x)
		mi.global_position = Vector3(0, 0.12, 0) + side * float(b["off"])
		mi.rotation.y = atan2(-dir.x, -dir.z)
		visuals.append(mi)
		mats.append(m)
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = Fx.ring_mesh(Arena.LIMIT - 4.0, 8.0)
	var ring_mat: StandardMaterial3D = Fx.flat_material(Color(1, 1, 1, 0.22))
	ring_mi.material_override = ring_mat
	ring_mi.scale = Vector3(1, 0.02, 1)
	_world().add_child(ring_mi)
	ring_mi.global_position = Vector3(0, 0.12, 0)
	visuals.append(ring_mi)
	mats.append(ring_mat)
	Fx.popup(_world(), global_position + Vector3(0, hit_height + 1.0, 0), "画界!", Color("ffd36b"), 96)
	await _t(1.1)
	for m: StandardMaterial3D in mats:
		m.albedo_color = Color("c89a30", 0.62)
	_shake(0.8)
	var elapsed: float = 0.0
	var tick: float = 0.0
	var fist: float = 0.6
	while elapsed < 5.0 and _ok():
		var dt: float = get_physics_process_delta_time()
		await get_tree().physics_frame
		elapsed += dt
		tick -= dt
		if tick <= 0.0 and hero.is_on_floor() and _in_paint(bands):
			tick = 0.4
			hero.take_damage(_dmg(7.0))
		fist -= dt
		if fist <= 0.0:
			fist = 0.75
			var spot: Vector3 = _hero_spot()
			var t: Node3D = Telegraph.circle(_world(), spot, 2.3, 0.7, _dmg(15.0), hero)
			t.on_strike = _impact.bind(spot, 2.3)
	for m: StandardMaterial3D in mats:
		create_tween().tween_property(m, "albedo_color:a", 0.0, 0.8)
	await _t(0.8)
	for v in visuals:
		v.queue_free()

func _in_paint(bands: Array[Dictionary]) -> bool:
	var p: Vector3 = _hero_spot()
	if Vector2(p.x, p.z).length() > Arena.LIMIT - 8.0:
		return true
	for b: Dictionary in bands:
		var dir := Vector3(sin(float(b["a"])), 0.0, cos(float(b["a"])))
		var side := Vector3(-dir.z, 0, dir.x)
		if absf(p.dot(side) - float(b["off"])) < float(b["w"]) * 0.5:
			return true
	return false
