extends Node3D

# The player's hero: a 2D sprite (sprites/hero_gold.png) drawn by the same billboard rig as the army units.
# Moves with the arrow keys (driven by battle.gd), auto-attacks the nearest enemy in range, casts skills.

const UnitData := preload("res://data/units.gd")
const Progress := preload("res://data/progress.gd")
const Fx := preload("res://scripts/fx.gd")
const SpriteRigScript := preload("res://scripts/spriterig.gd")
const GOLD := Color("f2b632")
const CASTLE_HALF_WIDTH: float = 2.4
const MIN_X: float = 3.4
const MAX_X: float = 36.2
const SPAWN_X: float = 5.0

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
var hero_id: String = "blade"
var armor: float = 0.0
var _cd_total: Dictionary = {}

var _cd_left: float = 0.0
var _hits: int = 0
var _busy: float = 0.0
var _moving: bool = false
var _dead_t: float = -1.0
var _fill: MeshInstance3D
var _bar: Node3D
var _rig: Node3D
var _dash_left: float = 0.0
var _dash_dir: float = 1.0
var _dash_speed: float = 0.0
var _dash_hit: Array[Node3D] = []

func setup(p_battle: Node3D, p_level: int) -> void:
	battle = p_battle
	level = p_level
	hero_id = Progress.selected_hero()
	var d: Dictionary = Progress.HEROES[hero_id]
	var m: Dictionary = p_battle.mods
	max_hp = float(d["hp"]) * float(m["hp"])
	hp = max_hp
	atk = float(d["atk"]) * float(m["atk"])
	attack_range = d["range"] / UnitData.PX_PER_M
	speed = float(d["speed"]) / UnitData.PX_PER_M * float(m["spd"])
	cooldown = d["cooldown"]
	armor = float(d.get("armor", 0.0))

func _ready() -> void:
	add_to_group("team_0")
	add_to_group("hero")
	_rig = SpriteRigScript.new()
	# Until the hero sheet is baked, borrow the footsoldier sprite.
	_rig.setup("hero" if SpriteRigScript.has_sprite("hero") else "soldier", 0, speed, UnitData.HERO["sprite_h"], "gold")
	add_child(_rig)
	_rig.set_tint(Progress.HEROES[hero_id]["tint"])
	_rig.scale = Vector3.ONE * float(Progress.HEROES[hero_id]["scale"])
	_build_ring()
	_bar = Node3D.new()
	_bar.position.y = UnitData.HERO["sprite_h"] + 0.3
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
	_cd_left -= delta * (UnitData.HERO_SKILLS["rally"]["haste"] if battle.rally_t > 0.0 else 1.0)
	_dash_step(delta)
	_auto_attack()
	_update_anim()
	_moving = false

# Called by battle.gd while the player is steering the hero.
func move(dir: float, delta: float) -> void:
	if _dead_t >= 0.0 or dir == 0.0 or _dash_left > 0.0:
		return
	_moving = true
	facing = signf(dir)
	position.x = clampf(position.x + dir * speed * delta, MIN_X, MAX_X)
	_rig.set_facing(facing > 0.0)

func can_cast(id: String) -> bool:
	var s: Dictionary = UnitData.HERO_SKILLS[id]
	return _dead_t < 0.0 and level >= s["unlock"] and skill_cd.get(id, 0.0) <= 0.0

func cooldown_fraction(id: String) -> float:
	return skill_cd.get(id, 0.0) / maxf(_cd_total.get(id, 1.0), 0.01)

func cast(id: String) -> bool:
	if not can_cast(id):
		return false
	match id:
		"slash":
			_cast_slash()
		"dash":
			_cast_dash()
		"rally":
			_cast_rally()
		"rain":
			_cast_rain()
		"special":
			_cast_ex()
		_:
			return false
	var cd: float = _skill_cooldown(id)
	skill_cd[id] = cd
	_cd_total[id] = cd
	return true

func take_damage(amount: float) -> void:
	if invincible_t > 0.0 or _dead_t >= 0.0:
		return
	hp -= amount * (1.0 - armor)
	_rig.flash()
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
			u.take_damage(_skill_dmg(s["damage"]))
			_dealt(s["damage"])
	var castle: Node3D = battle.enemy_castle
	var gap: float = (castle.global_position.x - global_position.x) * facing - CASTLE_HALF_WIDTH
	if gap <= reach and gap > -CASTLE_HALF_WIDTH * 2.0 and castle.hp > 0.0:
		castle.take_damage(_skill_dmg(s["damage"]))
		_dealt(s["damage"])
	Fx.slash_wave(battle, global_position, facing, reach)
	_play("power", 0.5)

func _cast_dash() -> void:
	var s: Dictionary = UnitData.HERO_SKILLS["dash"]
	var duration: float = 0.25
	_dash_left = duration
	_dash_dir = facing
	_dash_speed = s["distance"] / UnitData.PX_PER_M / duration
	_dash_hit.clear()
	invincible_t = s["invincible"]
	_play("roll", 0.35)

func _dash_step(delta: float) -> void:
	if _dash_left <= 0.0:
		return
	_dash_left -= delta
	position.x = clampf(position.x + _dash_dir * _dash_speed * delta, MIN_X, MAX_X)
	var dmg: float = UnitData.HERO_SKILLS["dash"]["damage"]
	for u: Node3D in _enemies():
		if u in _dash_hit or absf(u.global_position.x - global_position.x) > 1.0:
			continue
		_dash_hit.append(u)
		u.take_damage(dmg)
		_dealt(dmg)

# Whole army heals and attacks faster for a few seconds.
func _cast_rally() -> void:
	var s: Dictionary = UnitData.HERO_SKILLS["rally"]
	battle.rally_t = s["duration"]
	for u: Node3D in get_tree().get_nodes_in_group("team_0"):
		if u.is_queued_for_deletion():
			continue
		u.heal(u.max_hp * s["heal"])
		Fx.rise(battle, u.global_position + Vector3(0, 1.0, 0.3), Color("e8b44a"))
	Fx.ring(battle, global_position, 12.0, Color("e8b44a"), 0.6)
	_play("power", 0.6)

# Swords fall on an area in front of the hero for a couple of seconds.
func _cast_rain() -> void:
	var s: Dictionary = UnitData.HERO_SKILLS["rain"]
	var reach: float = s["range"] / UnitData.PX_PER_M
	var lo: float = minf(global_position.x, global_position.x + facing * reach)
	var hi: float = maxf(global_position.x, global_position.x + facing * reach)
	var ticks: int = s["ticks"]
	Fx.sword_rain(battle, lo, hi, s["duration"])
	var tw: Tween = create_tween()
	for i in ticks:
		tw.tween_callback(_rain_tick.bind(lo, hi, s["damage"]))
		tw.tween_interval(s["duration"] / ticks)
	_play("power", 0.6)

func _rain_tick(lo: float, hi: float, dmg: float) -> void:
	for u: Node3D in _enemies():
		if u.global_position.x >= lo and u.global_position.x <= hi:
			u.take_damage(dmg)
			_dealt(dmg)
	var castle: Node3D = battle.enemy_castle
	if castle.hp > 0.0 and castle.global_position.x - CASTLE_HALF_WIDTH <= hi and castle.global_position.x + CASTLE_HALF_WIDTH >= lo:
		castle.take_damage(dmg)
		_dealt(dmg)

# Hero's own skill (G): an ink vortex that damages and shoves everything around the hero.
func _cast_vortex() -> void:
	var s: Dictionary = UnitData.HERO_SKILLS["special"]
	var radius: float = s["range"] / UnitData.PX_PER_M
	for u: Node3D in _enemies():
		if u.flying or absf(u.global_position.x - global_position.x) > radius:
			continue
		u.take_damage(s["damage"])
		_dealt(s["damage"])
		if u.has_method("apply_knockback"):
			u.apply_knockback(s["knockback"], global_position.x)
	Fx.ring(battle, global_position, radius, Color("0d0d0f"), 0.5)
	_play("spin", 0.6)

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
		_rig.set_facing(facing > 0.0)
	_cd_left = cooldown
	_hits += 1
	var spec: Dictionary = Progress.HEROES[hero_id]
	var dmg: float = atk
	if spec.has("crit"):
		if randf() < float(spec["crit"]):
			dmg *= 2.5
	elif _hits % int(UnitData.HERO["crit_every"]) == 0:
		dmg *= UnitData.HERO["crit_mult"]
	target.take_damage(dmg)
	_dealt(dmg)
	if spec.has("splash") or spec.has("aoe"):
		var radius: float = float(spec.get("splash", spec.get("aoe", 0.0))) / UnitData.PX_PER_M
		for u: Node3D in _enemies():
			if u != target and not u.flying and absf(u.global_position.x - target.global_position.x) <= radius:
				u.take_damage(dmg * 0.6)
				_dealt(dmg * 0.6)
				if spec.has("aoe") and u.has_method("apply_knockback"):
					u.apply_knockback(1.5, global_position.x)
		Fx.ring(battle, target.global_position, radius, Color(spec["tint"]), 0.3)
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
	_rig.set_moving(_moving)

# Run / idle are the walk cycle; everything else plays the attack frames over busy_time seconds.
func _play(anim_name: String, busy_time: float = 0.0) -> void:
	if anim_name == "run":
		_rig.set_moving(true)
	elif anim_name == "idle":
		_rig.set_moving(false)
	elif busy_time > 0.0:
		_busy = busy_time
		_rig.play_attack(busy_time / 0.6)

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

# ---------- marker: a flat gold ring under the hero's feet (the gold scarf is in the sprite) ----------

func _build_ring() -> void:
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9
	disc.bottom_radius = 0.9
	disc.height = 0.02
	disc.radial_segments = 24
	ring.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(GOLD, 0.5)
	ring.material_override = mat
	ring.scale = Vector3(1.0, 1.0, 0.3)
	ring.position.y = 0.03
	add_child(ring)

# ---------- upgrades and per-hero skill ----------

func _skill_dmg(base: float) -> float:
	return base * float(battle.mods["skill_atk"])

func _skill_cooldown(id: String) -> float:
	var base: float = UnitData.HERO_SKILLS[id]["cooldown"]
	if id == "special":
		base = float(Progress.HEROES[hero_id]["ex_cd"])
		return base * float(battle.mods["drum"])
	return base * float(battle.mods["cd_slash"] if id == "slash" else battle.mods["cd_other"])

# G: each hero has its own skill (web HERO_EX).
func _cast_ex() -> void:
	match hero_id:
		"knight":
			battle.wall_t = 5.0
			Fx.ring(battle, global_position, 12.0, Color("9fb4d8"), 0.7)
			_play("power", 0.6)
		"assassin":
			var far: Node3D = null
			var far_gap: float = 0.0
			for u: Node3D in _enemies():
				var gap: float = absf(u.global_position.x - global_position.x)
				if gap <= 14.0 and gap > far_gap:
					far_gap = gap
					far = u
			if far != null:
				position.x = clampf(far.global_position.x - signf(far.global_position.x - position.x) * 0.9, MIN_X, MAX_X)
				var dmg: float = atk * 4.0
				far.take_damage(dmg)
				_dealt(dmg)
				Fx.ring(battle, global_position, 3.0, Color("c8a0ff"), 0.4)
			invincible_t = maxf(invincible_t, 0.6)
			_play("slash1", 0.4)
		"mage":
			var targets: Array[Node3D] = _enemies()
			targets.shuffle()
			for i in mini(5, targets.size()):
				var t: Node3D = targets[i]
				get_tree().create_timer(0.15 * i + 0.4).timeout.connect(_meteor.bind(t))
			_play("power", 0.6)
		"titan":
			var dmg_q: float = _skill_dmg(40.0)
			for u: Node3D in _enemies():
				if u.flying or absf(u.global_position.x - global_position.x) > 6.0:
					continue
				u.take_damage(dmg_q)
				_dealt(dmg_q)
				if u.has_method("apply_knockback"):
					u.apply_knockback(2.5, global_position.x)
			Fx.ring(battle, global_position, 6.0, Color("d8a070"), 0.6)
			battle.shake_camera(0.6)
			_play("power", 0.6)
		_:
			_cast_vortex()

func _meteor(target: Node3D) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	var spot: Vector3 = target.global_position
	var dmg: float = _skill_dmg(60.0)
	for u: Node3D in _enemies():
		if absf(u.global_position.x - spot.x) <= 2.5:
			u.take_damage(dmg)
			_dealt(dmg)
	Fx.ring(battle, spot, 2.5, Color("ff9a6a"), 0.4)
