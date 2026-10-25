extends Node3D

# Training dummy used while the boss ladder is not running (and in tests): takes hits like a boss and now and then
# throws a red-circle telegraph at the hero so the warning + dodge-roll can be practised.

const Toon := preload("res://scripts/toon.gd")
const Telegraph := preload("res://scripts/telegraph.gd")

var hp: float = 2000.0
var max_hp: float = 2000.0
var alive: bool = true
var hit_radius: float = 0.9
var hit_height: float = 1.6
var hero: Node3D
var attack_enabled: bool = true

var _t: float = 2.0
var _body: Node3D
var _punch: float = 0.0

func _ready() -> void:
	add_to_group("raid_boss")
	_body = Node3D.new()
	add_child(_body)
	var post := CylinderMesh.new()
	post.top_radius = 0.35
	post.bottom_radius = 0.45
	post.height = 2.2
	var mi := MeshInstance3D.new()
	mi.mesh = post
	mi.material_override = Toon.flat(Color("b57a3c"), 0.06)
	mi.position.y = 1.1
	_body.add_child(mi)
	var target := CylinderMesh.new()
	target.top_radius = 0.8
	target.bottom_radius = 0.8
	target.height = 0.12
	var disc := MeshInstance3D.new()
	disc.mesh = target
	disc.material_override = Toon.flat(Color("e0463b"), 0.05)
	disc.rotation.x = deg_to_rad(90.0)
	disc.position = Vector3(0, 1.6, -0.45)
	_body.add_child(disc)

func take_hit(amount: float, _from: Vector3) -> void:
	hp = maxf(0.0, hp - amount)
	_punch = 0.12
	if hp <= 0.0:
		alive = false
		_body.visible = false

func _process(delta: float) -> void:
	_punch = maxf(0.0, _punch - delta)
	_body.scale = Vector3.ONE * (1.0 + _punch * 0.6)
	if not alive or not attack_enabled or hero == null or not is_instance_valid(hero):
		return
	_t -= delta
	if _t <= 0.0:
		_t = 3.2
		Telegraph.circle(get_parent(), hero.global_position, 3.0, 1.0, 20.0, hero)
