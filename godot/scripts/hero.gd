extends Node3D

# The player's hero. Model: hero_anim.glb (rigged hero.glb: idle, run, slash1-3, spin, roll, hit, jump, power).
# Moves with the arrow keys (driven by battle.gd), auto-attacks the nearest enemy in range, casts skills.

const UnitData := preload("res://data/units.gd")
const Fx := preload("res://scripts/fx.gd")
const Ink := preload("res://scripts/ink.gd")
const GOLD := Color("e8b44a")
const SCARF_POINTS: int = 14
const SCARF_NECK_Y: float = 2.3
const MODEL: PackedScene = preload("res://models/hero_anim.glb")
const LOOPING: Array[String] = ["idle", "run"]
const HERO_SCALE: float = 1.65
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
var _scarf_fill: MeshInstance3D
var _scarf_outline: MeshInstance3D
var _scarf_t: float = 0.0
var _dash_left: float = 0.0
var _dash_dir: float = 1.0
var _dash_speed: float = 0.0
var _dash_hit: Array[Node3D] = []

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

	_build_aura()
	_bar = Node3D.new()
	_bar.position.y = 2.95
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
	_update_scarf(delta)
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
		"dash":
			_cast_dash()
		"rally":
			_cast_rally()
		"rain":
			_cast_rain()
		"special":
			_cast_vortex()
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

# ---------- "this is mine" markers: gold glow, ground ring and a flowing gold scarf ----------

func _build_aura() -> void:
	# Soft gold glow behind the hero (additive, always upright to the camera).
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(GOLD, 0.65), Color(GOLD, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4.2, 4.6)
	glow.mesh = quad
	var gmat := _additive(tex, Color.WHITE)
	gmat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	glow.material_override = gmat
	glow.position = Vector3(0.0, 1.5, -0.35)
	add_child(glow)
	# Ring on the ground under the feet.
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.95
	disc.bottom_radius = 0.95
	disc.height = 0.02
	disc.radial_segments = 24
	ring.mesh = disc
	ring.material_override = _additive(null, Color(GOLD, 0.35))
	ring.scale = Vector3(1.0, 1.0, 0.45)
	ring.position.y = 0.04
	add_child(ring)
	# Scarf: a tapered gold ribbon (with a black ink outline) streaming behind the neck.
	_scarf_outline = MeshInstance3D.new()
	_scarf_outline.mesh = ImmediateMesh.new()
	_scarf_outline.material_override = _flat_mat(Ink.INK)
	add_child(_scarf_outline)
	_scarf_fill = MeshInstance3D.new()
	_scarf_fill.mesh = ImmediateMesh.new()
	_scarf_fill.material_override = _flat_mat(GOLD)
	add_child(_scarf_fill)
	_update_scarf(0.0)

func _additive(tex: Texture2D, color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	if tex != null:
		mat.albedo_texture = tex
	return mat

func _flat_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	return mat

# The scarf streams backwards (opposite to the facing) and ripples; it lifts more while running.
func _update_scarf(delta: float) -> void:
	if _scarf_fill == null:
		return
	_scarf_t += delta * (9.0 if _moving else 4.0)
	var lift: float = 0.35 if _moving else 0.12
	_draw_ribbon(_scarf_outline.mesh as ImmediateMesh, 0.045, -0.01, lift)
	_draw_ribbon(_scarf_fill.mesh as ImmediateMesh, 0.0, 0.0, lift)

func _draw_ribbon(mesh: ImmediateMesh, extra: float, z: float, lift: float) -> void:
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n: int = SCARF_POINTS
	for i in n:
		var f: float = float(i) / float(n - 1)
		var x: float = -0.1 - f * 1.5
		var y: float = SCARF_NECK_Y + lift * f - 0.35 * f * f + sin(_scarf_t - f * 5.0) * 0.12 * f
		var half: float = (0.13 * (1.0 - f * 0.65)) + extra
		mesh.surface_add_vertex(Vector3(x, y + half, z))
		mesh.surface_add_vertex(Vector3(x, y - half, z))
	mesh.surface_end()
