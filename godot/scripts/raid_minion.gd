extends Node3D

# A small ink soldier summoned by a boss. Chases the hero and slashes; the hero can kill it (it joins the
# "raid_boss" group so every hero attack already finds it). Not a win condition.

const Toon := preload("res://scripts/toon.gd")
const Fx := preload("res://scripts/raid_fx.gd")

var hero: Node3D
var alive: bool = true
var hp: float = 70.0
var hit_radius: float = 0.7
var hit_height: float = 1.8
var damage: float = 9.0
var speed: float = 4.6
var _cd: float = 1.0
var _mats: Array[ShaderMaterial] = []
var _flash: float = 0.0
var _clock: float = 0.0

func setup(p_hero: Node3D, body: Color, accent: Color) -> void:
	hero = p_hero
	add_to_group("raid_boss")
	add_to_group("raid_minion")
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.3
	torso.mesh = cap
	var m1: ShaderMaterial = Toon.flat(body.lerp(Color.WHITE, 0.15), 0.04)
	torso.material_override = m1
	torso.position.y = 0.95
	add_child(torso)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.24
	sph.height = 0.48
	head.mesh = sph
	var m2: ShaderMaterial = Toon.flat(accent, 0.04)
	head.material_override = m2
	head.position.y = 1.85
	add_child(head)
	_mats = [m1, m2]

func take_hit(amount: float, _from: Vector3) -> void:
	if not alive:
		return
	hp -= amount
	_flash = 0.1
	Toon.set_flash(_mats, 0.9)
	if hp <= 0.0:
		alive = false
		remove_from_group("raid_boss")
		Fx.hit_burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color.WHITE, 1.2)
		queue_free()

func _physics_process(delta: float) -> void:
	_clock += delta
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			Toon.set_flash(_mats, 0.0)
	if not alive or hero == null or not is_instance_valid(hero) or ("dead" in hero and hero.dead):
		return
	var rel := Vector3(hero.global_position.x - global_position.x, 0.0, hero.global_position.z - global_position.z)
	if rel.length() > 1.5:
		global_position += rel.normalized() * speed * delta
		global_position.y = 0.0
	rotation.y = atan2(-rel.x, -rel.z)
	_cd -= delta
	if _cd <= 0.0 and rel.length() <= 1.9:
		_cd = 1.3
		hero.take_damage(damage)
		Fx.ring(get_parent(), global_position, 1.6, Color(1, 0.8, 0.5, 0.6), 0.2)
	get_child(0).rotation.z = sin(_clock * 10.0) * 0.06
