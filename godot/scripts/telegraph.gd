extends Node3D

# A ground warning (red circle / line / cone / expanding ring) that fills up and then strikes.
# Create one with the static helpers; it damages the hero if the hero is inside when the fill completes.

const Fx := preload("res://scripts/raid_fx.gd")
const BASE_COLOR := Color(1.0, 0.1, 0.08, 0.32)
const FILL_COLOR := Color(1.0, 0.14, 0.1, 0.7)
const STRIKE_COLOR := Color(1.0, 0.95, 0.8, 0.9)

enum Shape { CIRCLE, LINE, CONE, RING }

var shape: int = Shape.CIRCLE
var radius: float = 3.0
var length: float = 8.0
var width: float = 2.0
var angle_deg: float = 90.0
var delay: float = 1.0
var damage: float = 20.0
var hero: Node3D
var dir: Vector3 = Vector3(0, 0, -1)
var wave_time: float = 0.5 # RING: how long the shockwave takes to expand
var on_strike: Callable = Callable()

var _t: float = 0.0
var _fill: MeshInstance3D
var _base: MeshInstance3D
var _fill_mat: StandardMaterial3D
var _struck: bool = false
var _wave_hit: bool = false

static func _make(parent: Node3D, pos: Vector3, p_shape: int, p_delay: float, p_damage: float, p_hero: Node3D) -> Node3D:
	var t: Node3D = load("res://scripts/telegraph.gd").new()
	t.shape = p_shape
	t.delay = p_delay
	t.damage = p_damage
	t.hero = p_hero
	parent.add_child(t)
	t.global_position = Vector3(pos.x, 0.06, pos.z)
	return t

static func circle(parent: Node3D, pos: Vector3, p_radius: float, p_delay: float, p_damage: float, p_hero: Node3D) -> Node3D:
	var t: Node3D = _make(parent, pos, Shape.CIRCLE, p_delay, p_damage, p_hero)
	t.radius = p_radius
	t.call("_build")
	return t

# A rectangle from `pos` along `p_dir`.
static func line(parent: Node3D, pos: Vector3, p_dir: Vector3, p_length: float, p_width: float, p_delay: float, p_damage: float, p_hero: Node3D) -> Node3D:
	var t: Node3D = _make(parent, pos, Shape.LINE, p_delay, p_damage, p_hero)
	t.dir = Vector3(p_dir.x, 0, p_dir.z).normalized()
	t.length = p_length
	t.width = p_width
	t.call("_build")
	return t

static func cone(parent: Node3D, pos: Vector3, p_dir: Vector3, p_angle: float, p_radius: float, p_delay: float, p_damage: float, p_hero: Node3D) -> Node3D:
	var t: Node3D = _make(parent, pos, Shape.CONE, p_delay, p_damage, p_hero)
	t.dir = Vector3(p_dir.x, 0, p_dir.z).normalized()
	t.angle_deg = p_angle
	t.radius = p_radius
	t.call("_build")
	return t

# A shockwave: warns with a ring at the final radius, then expands from the centre; stepping over it in time (or
# rolling through it) avoids the damage.
static func ring(parent: Node3D, pos: Vector3, p_radius: float, p_delay: float, p_damage: float, p_hero: Node3D) -> Node3D:
	var t: Node3D = _make(parent, pos, Shape.RING, p_delay, p_damage, p_hero)
	t.radius = p_radius
	t.call("_build")
	return t

func _build() -> void:
	var base_mat: StandardMaterial3D = Fx.flat_material(BASE_COLOR)
	_fill_mat = Fx.flat_material(FILL_COLOR)
	_base = MeshInstance3D.new()
	_fill = MeshInstance3D.new()
	match shape:
		Shape.CIRCLE:
			_base.mesh = Fx.disc_mesh(radius)
			_fill.mesh = Fx.disc_mesh(radius)
		Shape.LINE:
			var box := BoxMesh.new()
			box.size = Vector3(width, 0.02, length)
			_base.mesh = box
			var fbox := BoxMesh.new()
			fbox.size = Vector3(width, 0.03, 1.0)
			_fill.mesh = fbox
			rotation.y = atan2(-dir.x, -dir.z)
		Shape.CONE:
			_base.mesh = Fx.cone_mesh(angle_deg, radius)
			_fill.mesh = Fx.cone_mesh(angle_deg, radius)
			rotation.y = atan2(-dir.x, -dir.z)
		Shape.RING:
			_base.mesh = Fx.ring_mesh(radius, 0.5)
			_fill.mesh = Fx.disc_mesh(radius)
	_base.material_override = base_mat
	_fill.material_override = _fill_mat
	add_child(_base)
	add_child(_fill)
	if shape == Shape.LINE:
		_base.position = Vector3(0, 0, -length * 0.5)
	_update_fill(0.0)

func _process(delta: float) -> void:
	_t += delta
	if _t < delay:
		_update_fill(_t / delay)
		return
	if not _struck:
		_struck = true
		_strike()
	if shape == Shape.RING:
		_expand_wave()
	elif _t > delay + 0.22:
		queue_free()

func _update_fill(p: float) -> void:
	p = clampf(p, 0.001, 1.0)
	if shape == Shape.LINE:
		_fill.scale = Vector3(1, 1, p * length)
		_fill.position = Vector3(0, 0.02, -p * length * 0.5)
	else:
		_fill.scale = Vector3(p, 1, p)

func _strike() -> void:
	_fill_mat.albedo_color = STRIKE_COLOR
	if shape == Shape.RING:
		_fill.visible = false
		_base.mesh = Fx.ring_mesh(1.0, 0.6)
		_base.scale = Vector3(0.3, 1.0, 0.3)
		(_base.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.45, 0.2, 0.85)
	else:
		_update_fill(1.0)
		if _hero_inside():
			_hit_hero()
	if on_strike.is_valid():
		on_strike.call()

func _expand_wave() -> void:
	var p: float = clampf((_t - delay) / wave_time, 0.0, 1.0)
	var r: float = p * radius
	_base.scale = Vector3(maxf(r, 0.3), 1.0, maxf(r, 0.3))
	if not _wave_hit and hero != null and is_instance_valid(hero):
		var d: float = Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length()
		if absf(d - r) < 0.9:
			_wave_hit = true
			_hit_hero()
	if p >= 1.0:
		queue_free()

func _hit_hero() -> void:
	if hero != null and is_instance_valid(hero) and hero.has_method("take_damage"):
		hero.take_damage(damage)

func _hero_inside() -> bool:
	if hero == null or not is_instance_valid(hero):
		return false
	var rel := Vector3(hero.global_position.x - global_position.x, 0.0, hero.global_position.z - global_position.z)
	match shape:
		Shape.CIRCLE:
			return rel.length() <= radius + 0.35
		Shape.LINE:
			var along: float = rel.dot(-dir) * -1.0
			var side: float = absf(rel.dot(Vector3(-dir.z, 0, dir.x)))
			return along >= -0.3 and along <= length + 0.3 and side <= width * 0.5 + 0.35
		Shape.CONE:
			if rel.length() > radius + 0.35:
				return false
			if rel.length() < 0.5:
				return true
			return rel.normalized().dot(dir) >= cos(deg_to_rad(angle_deg * 0.5))
	return false
