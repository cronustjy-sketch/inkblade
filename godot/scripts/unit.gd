extends Node3D

const UnitData := preload("res://data/units.gd")
const StickmanScript := preload("res://scripts/stickman.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const Fx := preload("res://scripts/fx.gd")
const CASTLE_HALF_WIDTH: float = 3.2
const LANE_MIN_X: float = 0.0
const LANE_MAX_X: float = 40.0
const RANGED_MIN_RANGE: float = 3.0
const KNOCKBACK_DECAY: float = 6.0

var team: int = 0
var key: String = "soldier"
var data: Dictionary = {}
var hp: float = 60.0
var max_hp: float = 60.0
var atk: float = 10.0
var attack_range: float = 0.8
var speed: float = 1.5
var cooldown: float = 0.9
var pop: int = 1
var inside: bool = false
var flying: bool = false
var armor: float = 0.0
var blocks_arrows: bool = false

var enemy_castle: Node3D
var _cd_left: float = 0.0
var _dir: float = 1.0
var _fill: MeshInstance3D
var _rig: Node3D
var _first_hit: bool = true
var _kb_vel: float = 0.0

# stat_mult scales hp and atk (enemy level scaling).
func setup(p_team: int, p_key: String, p_enemy_castle: Node3D, stat_mult: float = 1.0) -> void:
	team = p_team
	key = p_key
	enemy_castle = p_enemy_castle
	data = UnitData.UNITS[key]
	max_hp = data["hp"] * stat_mult
	hp = max_hp
	atk = data["atk"] * stat_mult
	attack_range = data["range"] / UnitData.PX_PER_M
	speed = data["speed"] / UnitData.PX_PER_M
	cooldown = data["cooldown"]
	pop = data["pop"]
	flying = data.get("flying", false)
	armor = data.get("armor", 0.0)
	blocks_arrows = data.get("blocks_arrows", false)
	_dir = 1.0 if team == 0 else -1.0

func _ready() -> void:
	add_to_group("units")
	add_to_group("team_%d" % team)

	_rig = StickmanScript.new()
	_rig.setup(key, team, speed)
	add_child(_rig)

	_fill = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.1)
	_fill.mesh = quad
	_fill.position.y = _rig.height + 0.25
	var bar_mat := _unshaded(Color("3ddc6a"))
	bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar_mat.billboard_keep_scale = true
	_fill.material_override = bar_mat
	add_child(_fill)

func _process(delta: float) -> void:
	_cd_left -= delta
	_apply_knockback(delta)
	var is_healer: bool = data.has("heal")
	var target: Node3D = _nearest_enemy()
	var enemy_in_range: bool = target != null and _x_gap(target.global_position.x) <= attack_range
	if is_healer:
		_try_heal()
	var moving: bool = false
	if enemy_in_range:
		if not is_healer:
			_try_attack(target)
	elif enemy_castle != null and _castle_gap() <= attack_range:
		if not is_healer:
			_try_attack(enemy_castle)
	else:
		global_position.x += _dir * speed * delta
		moving = true
	_rig.set_moving(moving)

func take_damage(amount: float) -> void:
	hp -= amount * (1.0 - armor)
	_update_bar()
	if hp <= 0.0:
		queue_free()

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	_update_bar()

func is_big() -> bool:
	return pop >= 3

func apply_knockback(distance: float, from_x: float) -> void:
	var away: float = signf(global_position.x - from_x)
	if away == 0.0:
		away = _dir
	_kb_vel = away * distance * KNOCKBACK_DECAY

func _apply_knockback(delta: float) -> void:
	if absf(_kb_vel) < 0.01:
		return
	global_position.x = clampf(global_position.x + _kb_vel * delta, LANE_MIN_X, LANE_MAX_X)
	_kb_vel *= exp(-KNOCKBACK_DECAY * delta)

func _update_bar() -> void:
	_fill.scale.x = maxf(hp / max_hp, 0.001)
	_fill.position.x = -0.4 * (1.0 - hp / max_hp)

# ---------- attacks ----------

func _try_attack(target: Node3D) -> void:
	if _cd_left > 0.0:
		return
	_cd_left = cooldown
	_rig.play_attack(cooldown)
	var is_castle: bool = target == enemy_castle
	var dmg: float = atk
	if data.has("crit_chance") and randf() < data["crit_chance"]:
		dmg *= data["crit_mult"]
	if is_castle and data.has("castle_mult"):
		dmg *= data["castle_mult"]
	if not is_castle and data.has("big_mult") and target.is_big():
		dmg *= data["big_mult"]
	var knock: float = data.get("knockback", 0.0)
	if data.has("charge_mult"):
		if _first_hit:
			dmg *= data["charge_mult"]
		else:
			knock = 0.0
	_first_hit = false
	if data.has("projectile"):
		_shoot(target, dmg)
	elif data.has("aoe"):
		_aoe_hit(target, dmg, knock)
	else:
		target.take_damage(dmg)
		if knock > 0.0 and target.has_method("apply_knockback"):
			target.apply_knockback(knock, global_position.x)

func _shoot(target: Node3D, dmg: float) -> void:
	var kind: String = data["projectile"]
	var aim: Node3D = target
	if kind == "arrow":
		aim = _arrow_blocker(target)
	var p: Node3D = ProjectileScript.new()
	get_parent().add_child(p)
	var from: Vector3 = global_position + Vector3(_dir * 0.4, 1.3, 0.0)
	p.launch(kind, from, aim, dmg, team, data.get("splash", 0.0) / UnitData.PX_PER_M)

# A shield knight standing between the archer and its target soaks the arrow instead.
func _arrow_blocker(target: Node3D) -> Node3D:
	if target == enemy_castle:
		return target
	var best: Node3D = target
	var best_dist: float = (target.global_position.x - global_position.x) * _dir
	for u: Node3D in get_tree().get_nodes_in_group("team_%d" % (1 - team)):
		if u.is_queued_for_deletion() or u.get("blocks_arrows") != true:
			continue
		var d: float = (u.global_position.x - global_position.x) * _dir
		if d > 0.0 and d < best_dist:
			best = u
			best_dist = d
	return best

# Giant: hits everything near the target and knocks it back.
func _aoe_hit(target: Node3D, dmg: float, knock: float) -> void:
	var radius: float = data["aoe"] / UnitData.PX_PER_M
	Fx.ring(get_parent(), target.global_position, radius, Color("0d0d0f"))
	if target == enemy_castle:
		target.take_damage(dmg)
		return
	for u: Node3D in get_tree().get_nodes_in_group("team_%d" % (1 - team)):
		if u.is_queued_for_deletion() or u.inside:
			continue
		if absf(u.global_position.x - target.global_position.x) <= radius:
			u.take_damage(dmg)
			if knock > 0.0 and u.has_method("apply_knockback"):
				u.apply_knockback(knock, global_position.x)

# Priest: heals the lowest-HP wounded ally in range.
func _try_heal() -> void:
	if _cd_left > 0.0:
		return
	var best: Node3D = null
	var best_ratio: float = 1.0
	for u: Node3D in get_tree().get_nodes_in_group("team_%d" % team):
		if u.is_queued_for_deletion() or u.hp >= u.max_hp:
			continue
		if _x_gap(u.global_position.x) > attack_range:
			continue
		var ratio: float = u.hp / u.max_hp
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	if best == null:
		return
	_cd_left = cooldown
	_rig.play_attack(cooldown)
	best.heal(data["heal"])
	Fx.rise(get_parent(), best.global_position + Vector3(0, 1.0, 0.3), Color("e8b44a"))

# ---------- targeting ----------

func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_gap: float = INF
	var can_hit_air: bool = attack_range >= RANGED_MIN_RANGE or flying
	for u: Node3D in get_tree().get_nodes_in_group("team_%d" % (1 - team)):
		if u.is_queued_for_deletion() or u.inside:
			continue
		# Ground melee units can't reach flying targets.
		if u.flying and not can_hit_air:
			continue
		var gap: float = _x_gap(u.global_position.x)
		if gap < best_gap:
			best_gap = gap
			best = u
	return best

func _x_gap(other_x: float) -> float:
	return absf(other_x - global_position.x)

func _castle_gap() -> float:
	return _x_gap(enemy_castle.global_position.x) - CASTLE_HALF_WIDTH

func _unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat
