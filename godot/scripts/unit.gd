extends Node3D

const UnitData := preload("res://data/units.gd")
const StickmanScript := preload("res://scripts/stickman.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const Fx := preload("res://scripts/fx.gd")
const InkFx := preload("res://scripts/inkfx.gd")
const BossData := preload("res://data/bosses.gd")
const ModelRigScript := preload("res://scripts/modelrig.gd")
const SpriteRigScript := preload("res://scripts/spriterig.gd")
const Progress := preload("res://data/progress.gd")
const CASTLE_HALF_WIDTH: float = 2.4
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
var is_boss: bool = false
var _bar_half: float = 0.4

var enemy_castle: Node3D
var battle: Node3D # set for player units; enemies ignore orders
var controlled: bool = false
var _facing_right: bool = true
var _marker: Node3D
var _cd_left: float = 0.0
var _dir: float = 1.0
var _fill: MeshInstance3D
var _rig: Node3D
var _first_hit: bool = true
var _kb_vel: float = 0.0
var stun_t: float = 0.0 # frozen by the Frost spell
var _tint: Color = Color.WHITE
var lane_z: float = 0.0 # the lane this unit walks in (it slides there from behind its statue)
var _splash_cd: float = 0.0

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

# Level boss (enemy team). Stats come from data/bosses.gd and are not scaled.
func setup_boss(level: int, p_enemy_castle: Node3D) -> void:
	var b: Dictionary = BossData.for_level(level)
	team = 1
	key = "boss"
	is_boss = true
	enemy_castle = p_enemy_castle
	data = b.duplicate()
	data["pop"] = 3
	max_hp = b["hp"]
	hp = max_hp
	atk = b["atk"]
	attack_range = b["range"] / UnitData.PX_PER_M
	speed = b["speed"] / UnitData.PX_PER_M
	cooldown = b["cooldown"]
	pop = 3
	_dir = -1.0

func _ready() -> void:
	add_to_group("units")
	add_to_group("team_%d" % team)

	if is_boss:
		_bar_half = 1.2
		if SpriteRigScript.has_sprite(data["sprite"]):
			_rig = SpriteRigScript.new()
			_rig.setup(data["sprite"], team, speed, data["sprite_h"], "gold")
		else:
			# Fallback while the sprite art is missing: the old 3D boss model.
			_rig = ModelRigScript.new()
			_rig.setup(data)
	elif SpriteRigScript.has_sprite(key):
		_rig = SpriteRigScript.new()
		_rig.setup(key, team, speed)
	else:
		# Units without baked sprites (the dragon) keep the primitive stickman.
		_rig = StickmanScript.new()
		_rig.setup(key, team, speed)
	add_child(_rig)
	if _tint != Color.WHITE and _rig.has_method("set_tint"):
		_rig.set_tint(_tint)

	_fill = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(_bar_half * 2.0, 0.1 if not is_boss else 0.16)
	_fill.mesh = quad
	_fill.position.y = _rig.height + 0.12
	var bar_mat := _unshaded(Color("3ddc6a"))
	bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar_mat.billboard_keep_scale = true
	_fill.material_override = bar_mat
	add_child(_fill)

func _process(delta: float) -> void:
	_cd_left -= delta * _haste()
	global_position.z = move_toward(global_position.z, lane_z, 2.2 * delta)
	_splash_cd -= delta
	_apply_knockback(delta)
	if stun_t > 0.0:
		stun_t -= delta
		_rig.set_moving(false)
		return
	var is_healer: bool = data.has("heal")
	var target: Node3D = _nearest_enemy()
	var enemy_in_range: bool = target != null and _x_gap(target.global_position.x) <= attack_range
	if is_healer and not inside:
		_try_heal()
	if team == 0 and battle != null and _follow_orders(delta, target, enemy_in_range):
		return
	var moving: bool = false
	if enemy_in_range:
		_face(target.global_position.x - global_position.x)
		if not is_healer:
			_try_attack(target)
	elif enemy_castle != null and _castle_gap() <= attack_range:
		if not is_healer:
			_try_attack(enemy_castle)
	else:
		_face(_dir)
		global_position.x += _dir * speed * delta
		moving = true
	_rig.set_moving(moving)

# ---------- orders and take-control (player units only) ----------

# Returns true when the order fully handled this frame; false means "act normally" (Attack).
func _follow_orders(delta: float, target: Node3D, enemy_in_range: bool) -> bool:
	var castle: Node3D = battle.player_castle
	if controlled:
		_controlled_step(delta, target, enemy_in_range)
		return true
	var order: int = battle.order
	if order == UnitData.ORDER_RETREAT:
		_retreat_step(delta, castle)
		return true
	if inside:
		_set_inside(false)
	if order == UnitData.ORDER_DEFEND:
		_defend_step(delta, castle, target, enemy_in_range)
		return true
	return false

func _retreat_step(delta: float, castle: Node3D) -> void:
	var gate_x: float = castle.global_position.x + CASTLE_HALF_WIDTH
	if inside:
		heal(max_hp * UnitData.RETREAT_HEAL_PER_SEC * delta)
		return
	if global_position.x <= gate_x:
		_set_inside(true)
		return
	_face(-1.0)
	global_position.x -= speed * delta
	_rig.set_moving(true)

func _defend_step(delta: float, castle: Node3D, target: Node3D, enemy_in_range: bool) -> void:
	if enemy_in_range:
		_face(target.global_position.x - global_position.x)
		if not data.has("heal"):
			_try_attack(target)
		_rig.set_moving(false)
		return
	var line_x: float = castle.global_position.x + UnitData.DEFEND_LINE_M
	var off: float = line_x - global_position.x
	if absf(off) > 0.25:
		_face(off)
		global_position.x += signf(off) * minf(speed * delta, absf(off))
		_rig.set_moving(true)
	else:
		_face(1.0)
		_rig.set_moving(false)

func _controlled_step(delta: float, target: Node3D, enemy_in_range: bool) -> void:
	var axis: float = battle.move_axis()
	if axis != 0.0:
		_face(axis)
		var left: float = battle.player_castle.global_position.x + CASTLE_HALF_WIDTH + 0.3
		var right: float = enemy_castle.global_position.x - CASTLE_HALF_WIDTH - 0.3
		global_position.x = clampf(global_position.x + axis * speed * delta, left, right)
	_rig.set_moving(axis != 0.0)
	if enemy_in_range:
		if axis == 0.0:
			_face(target.global_position.x - global_position.x)
		if not data.has("heal"):
			_try_attack(target)
	elif _castle_gap() <= attack_range and not data.has("heal"):
		if axis == 0.0:
			_face(enemy_castle.global_position.x - global_position.x)
		_try_attack(enemy_castle)

func _set_inside(value: bool) -> void:
	inside = value
	_rig.visible = not value
	_fill.visible = not value
	_rig.set_moving(false)

func set_controlled(value: bool) -> void:
	controlled = value
	if value and _marker == null:
		_marker = Node3D.new()
		_marker.position.y = _rig.height + 0.75
		add_child(_marker)
		var cone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.22
		mesh.bottom_radius = 0.0
		mesh.height = 0.4
		mesh.radial_segments = 4
		cone.mesh = mesh
		cone.material_override = _unshaded(Color("e8b44a"))
		_marker.add_child(cone)
	elif not value and _marker != null:
		_marker.queue_free()
		_marker = null

func _face(dx: float) -> void:
	if dx == 0.0:
		return
	var right: bool = dx > 0.0
	if right != _facing_right:
		_facing_right = right
		_rig.set_facing(right)

func take_damage(amount: float) -> void:
	var taken: float = amount * (1.0 - armor)
	if team == 0 and battle != null and battle.wall_t > 0.0:
		taken *= 0.4
	hp -= taken
	if _rig.has_method("flash"):
		_rig.flash()
	_update_bar()
	var body: float = _rig.height
	if hp <= 0.0:
		if not is_queued_for_deletion():
			InkFx.death_burst(get_parent(), global_position, clampf(body / 2.6, 0.7, 2.6))
		queue_free()
	elif amount > 0.0 and _splash_cd <= 0.0:
		_splash_cd = 0.12
		InkFx.hit_splash(get_parent(), global_position + Vector3(0, body * 0.5, 0), clampf(body * 0.34, 0.6, 2.0))

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
	_fill.position.x = -_bar_half * (1.0 - hp / max_hp)

# ---------- attacks ----------

func _try_attack(target: Node3D) -> void:
	if _cd_left > 0.0:
		return
	_cd_left = cooldown
	_rig.play_attack(cooldown)
	var is_castle: bool = target == enemy_castle
	var dmg: float = atk * (UnitData.CONTROL_DAMAGE_MULT if controlled else 1.0)
	if team == 0 and battle != null and battle.rage_t > 0.0:
		dmg *= 1.5
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
	if team == 0 and battle != null:
		battle.add_ink(dmg, false)
	if data.has("projectile"):
		_shoot(target, dmg)
	elif data.has("aoe"):
		_aoe_hit(target, dmg, knock)
	else:
		# Melee: an ink brush stroke sweeps across the target.
		var facing: float = signf(target.global_position.x - global_position.x)
		if facing == 0.0:
			facing = _dir
		InkFx.slash(get_parent(), global_position + Vector3(0, _rig.height * 0.55, 0), facing, clampf(_rig.height * 0.8, 1.6, 4.5), randf_range(-35.0, 15.0), Color("f2b632") if team == 0 else Color("e0463b"))
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

# Rally (hero skill R) speeds up the player army's attacks.
func _haste() -> float:
	if team == 0 and battle != null and battle.rally_t > 0.0:
		return UnitData.HERO_SKILLS["rally"]["haste"]
	return 1.0

# Permanent upgrades for the player's army (data/progress.gd): HP, attack, speed and helm damage reduction.
func apply_mods(mods: Dictionary) -> void:
	var arm: Dictionary = Progress.arm_mul(key)
	max_hp *= float(arm["hp"])
	atk *= float(arm["atk"])
	_tint = Progress.skin_tint("army")
	max_hp *= float(mods["hp"])
	hp = max_hp
	atk *= float(mods["atk"])
	speed *= float(mods["spd"])
	armor = 1.0 - (1.0 - armor) * (1.0 - float(mods["helm"]))
