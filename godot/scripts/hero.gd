extends Node3D

# The player's hero. Model: hero_anim.glb (rigged hero.glb: idle, run, slash1-3, spin, roll, hit, jump, power).
# Moves with the arrow keys (driven by battle.gd), auto-attacks the nearest enemy in range, casts skills.

const UnitData := preload("res://data/units.gd")
const Fx := preload("res://scripts/fx.gd")
const MODEL: PackedScene = preload("res://models/hero_anim.glb")
const LOOPING: Array[String] = ["idle", "run"]
const HERO_SCALE: float = 1.15
const CASTLE_HALF_WIDTH: float = 3.2
const MIN_X: float = 3.8
const MAX_X: float = 36.2
const SPAWN_X: float = 6.0

var team: int = 0
var pop: int = 0
var flying: bool = false
var inside: bool = false
var battle: Node3D
var level: int = 1
var hp: float = 400.0
var max_hp: float = 400.0
var atk: float = 22.0
var attack_range: float = 2.0
var speed: float = 4.0
var cooldown: float = 0.6
var facing: float = 1.0
var skill_cd: Dictionary = {}
var invincible_t: float = 0.0

var _cd_left: float = 0.0
var _hits: int = 0
var _busy: float = 0.0
var _moving: bool = false
var _dead_t: float = -1.0
var _anim: AnimationPlayer
var _model: Node3D
var _fill: MeshInstance3D
var _bar: Node3D
var _current: String = ""

func setup(p_battle: Node3D, p_level: int) -> void:
	battle = p_battle
	level = p_level
	var d: Dictionary = UnitData.HERO
	max_hp = d["hp"]
	hp = max_hp
	atk = d["atk"]
	attack_range = d["range"] / UnitData.PX_PER_M
	speed = d["speed"] / UnitData.PX_PER_M
	cooldown = d["cooldown"]

func _ready() -> void:
	add_to_group("team_0")
	add_to_group("hero")
	_model = MODEL.instantiate()
	_model.scale = Vector3.ONE * HERO_SCALE
	# Mixamo models face +Z; the battle runs along +X.
	_model.rotation_degrees.y = 90.0
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		push_warning("hero: no AnimationPlayer found in model")
	else:
		for anim_name: StringName in _anim.get_animation_list():
			if String(anim_name) in LOOPING:
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_play("idle")

	_bar = Node3D.new()
	_bar.position.y = 2.5
	add_child(_bar)
	var back := _bar_quad(Vector2(1.0, 0.14), Color("0d0d0f"), 0.0)
	_bar.add_child(back)
	_fill = _bar_quad(Vector2(0.94, 0.09), Color("e8b44a"), 0.01)
	_bar.add_child(_fill)

func _process(delta: float) -> void:
	for id: String in skill_cd:
		skill_cd[id] = maxf(0.0, skill_cd[id] - delta)
	invincible_t = maxf(0.0, invincible_t - delta)
	_busy = maxf(0.0, _busy - delta)
	if _dead_t >= 0.0:
		_dead_t -= delta
		if _dead_t < 0.0:
			_respawn()
		return
	_cd_left -= delta
	_auto_attack()
	_update_anim()
	_moving = false

# Called by battle.gd while the player is steering the hero.
func move(dir: float, delta: float) -> void:
	if _dead_t >= 0.0 or dir == 0.0:
		return
	_moving = true
	facing = signf(dir)
	position.x = clampf(position.x + dir * speed * delta, MIN_X, MAX_X)
	rotation_degrees.y = 0.0 if facing > 0.0 else 180.0

func can_cast(id: String) -> bool:
	var s: Dictionary = UnitData.HERO_SKILLS[id]
	return _dead_t < 0.0 and level >= s["unlock"] and skill_cd.get(id, 0.0) <= 0.0

func cooldown_fraction(id: String) -> float:
	return skill_cd.get(id, 0.0) / UnitData.HERO_SKILLS[id]["cooldown"]

func cast(id: String) -> bool:
	if not can_cast(id):
		return false
	match id:
		"slash":
			_cast_slash()
		_:
			return false
	skill_cd[id] = UnitData.HERO_SKILLS[id]["cooldown"]
	return true

func take_damage(amount: float) -> void:
	if invincible_t > 0.0 or _dead_t >= 0.0:
		return
	hp -= amount
	_fill.scale.x = maxf(hp / max_hp, 0.001)
	_fill.position.x = -0.47 * (1.0 - hp / max_hp)
	if hp <= 0.0:
		_die()

func play(anim_name: String, busy_time: float = 0.0) -> void:
	_play(anim_name, busy_time)

# ---------- skills ----------

func _cast_slash() -> void:
	var s: Dictionary = UnitData.HERO_SKILLS["slash"]
	var reach: float = s["range"] / UnitData.PX_PER_M
	for u: Node3D in _enemies():
		var ahead: float = (u.global_position.x - global_position.x) * facing
		if ahead >= -0.5 and ahead <= reach:
			u.take_damage(s["damage"])
			_dealt(s["damage"])
	var castle: Node3D = battle.enemy_castle
	var gap: float = (castle.global_position.x - global_position.x) * facing - CASTLE_HALF_WIDTH
	if gap <= reach and gap > -CASTLE_HALF_WIDTH * 2.0 and castle.hp > 0.0:
		castle.take_damage(s["damage"])
		_dealt(s["damage"])
	Fx.slash_wave(battle, global_position, facing, reach)
	_play("power", 0.5)

# ---------- combat ----------

func _auto_attack() -> void:
	if _cd_left > 0.0:
		return
	var target: Node3D = _nearest_enemy()
	var castle: Node3D = battle.enemy_castle
	if target == null or absf(target.global_position.x - global_position.x) > attack_range:
		target = null
		var castle_gap: float = absf(castle.global_position.x - global_position.x) - CASTLE_HALF_WIDTH
		if castle_gap <= attack_range and castle.hp > 0.0:
			target = castle
		else:
			return
	var dir: float = signf(target.global_position.x - global_position.x)
	if dir != 0.0:
		facing = dir
		rotation_degrees.y = 0.0 if facing > 0.0 else 180.0
	_cd_left = cooldown
	_hits += 1
	var crit_every: int = UnitData.HERO["crit_every"]
	var dmg: float = atk
	if _hits % crit_every == 0:
		dmg *= UnitData.HERO["crit_mult"]
	target.take_damage(dmg)
	_dealt(dmg)
	_play("slash%d" % ((_hits - 1) % 3 + 1), 0.4)

func _dealt(amount: float) -> void:
	if battle.has_method("add_ink"):
		battle.add_ink(amount)

func _enemies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for u: Node3D in get_tree().get_nodes_in_group("team_1"):
		if not u.is_queued_for_deletion() and not u.inside:
			out.append(u)
	return out

func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_gap: float = INF
	for u: Node3D in _enemies():
		if u.flying:
			continue
		var gap: float = absf(u.global_position.x - global_position.x)
		if gap < best_gap:
			best_gap = gap
			best = u
	return best

func _die() -> void:
	_dead_t = UnitData.HERO["respawn"]
	visible = false
	remove_from_group("team_0")

func _respawn() -> void:
	hp = max_hp
	_fill.scale.x = 1.0
	_fill.position.x = 0.0
	position.x = SPAWN_X
	visible = true
	add_to_group("team_0")

func is_dead() -> bool:
	return _dead_t >= 0.0

# ---------- animation ----------

func _update_anim() -> void:
	if _busy > 0.0:
		return
	_play("run" if _moving else "idle")

func _play(anim_name: String, busy_time: float = 0.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if busy_time > 0.0:
		var anim_len: float = _anim.get_animation(anim_name).length
		_anim.speed_scale = maxf(1.0, anim_len / busy_time)
		_busy = busy_time
		_current = ""
		_anim.play(anim_name, 0.08)
		return
	if _current == anim_name:
		return
	_current = anim_name
	_anim.speed_scale = 1.0
	_anim.play(anim_name, 0.15)

func _bar_quad(size: Vector2, color: Color, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.position.z = z
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mi.material_override = mat
	return mi

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	_fill.scale.x = maxf(hp / max_hp, 0.001)
	_fill.position.x = -0.47 * (1.0 - hp / max_hp)

func is_big() -> bool:
	return false
