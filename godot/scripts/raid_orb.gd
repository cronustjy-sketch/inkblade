extends Node3D

# A glowing ink orb that hurts the hero on touch. `mover` is called every frame with (age, delta) and returns the
# orb's new world position, so one script covers straight shots (fan) and circling rings (orbit).

const Toon := preload("res://scripts/toon.gd")

var hero: Node3D
var damage: float = 10.0
var hit_radius: float = 0.9
var life: float = 2.0
var mover: Callable = Callable()
var _age: float = 0.0
var _done: bool = false

static func spawn(parent: Node3D, color: Color, visual_radius: float, p_hero: Node3D, p_damage: float, p_hit_radius: float, p_life: float, p_mover: Callable, start: Vector3) -> Node3D:
	var orb: Node3D = load("res://scripts/raid_orb.gd").new()
	orb.hero = p_hero
	orb.damage = p_damage
	orb.hit_radius = p_hit_radius
	orb.life = p_life
	orb.mover = p_mover
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = visual_radius
	sphere.height = visual_radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	mesh.mesh = sphere
	var mat: ShaderMaterial = Toon.flat(color, 0.03)
	mat.set_shader_parameter("emission", 1.0)
	mesh.material_override = mat
	orb.add_child(mesh)
	parent.add_child(orb)
	orb.global_position = start
	return orb

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	if mover.is_valid():
		global_position = mover.call(_age, delta)
	if _done or hero == null or not is_instance_valid(hero) or "dead" in hero and hero.dead:
		return
	var d: float = Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length()
	if d < hit_radius + 0.3 and absf(hero.global_position.y + 1.0 - global_position.y) < 2.6:
		_done = true
		hero.take_damage(damage)
		queue_free()
