extends Node3D

# Arrows, magic orbs and rocks. Homes in on the target while flying along an arc, then applies damage on arrival.

const Ink := preload("res://scripts/ink.gd")
const Fx := preload("res://scripts/fx.gd")
const CASTLE_HALF_WIDTH: float = 2.4

const KINDS: Dictionary = {
	"arrow": {"speed": 16.0, "arc": 0.7},
	"orb": {"speed": 9.0, "arc": 0.4},
	"rock": {"speed": 9.0, "arc": 3.2},
}

var kind: String = "arrow"
var team: int = 0
var damage: float = 0.0
var splash: float = 0.0
var target: Node3D
var _from: Vector3
var _to: Vector3
var _t: float = 0.0
var _dur: float = 1.0
var _arc: float = 0.5
var _prev: Vector3

# splash_m is the splash radius in meters (0 = single target).
func launch(p_kind: String, from: Vector3, p_target: Node3D, p_damage: float, p_team: int, splash_m: float) -> void:
	kind = p_kind
	team = p_team
	damage = p_damage
	splash = splash_m
	target = p_target
	_from = from
	_to = _aim_point()
	_arc = KINDS[kind]["arc"]
	_dur = maxf(0.15, _from.distance_to(_to) / KINDS[kind]["speed"])
	_prev = from
	position = from
	_build_visual()

func _build_visual() -> void:
	match kind:
		"arrow":
			Ink.box(self, Vector3(0.55, 0.05, 0.05), Vector3.ZERO, Color("0d0d0f"), Vector3.ZERO, 0.012)
		"orb":
			Ink.blob(self, 0.2, Vector3.ONE, Vector3.ZERO, Color("7b4bd6"), 0.04)
		_:
			Ink.blob(self, 0.32, Vector3.ONE, Vector3.ZERO, Color("b8b09a"), 0.06)

func _aim_point() -> Vector3:
	if is_instance_valid(target):
		var y: float = 3.0 if target.has_method("is_castle") else 1.0
		return Vector3(target.global_position.x, y, target.global_position.z)
	return _to

func _process(delta: float) -> void:
	if is_instance_valid(target):
		_to = _aim_point()
	_t += delta / _dur
	if _t >= 1.0:
		_impact()
		queue_free()
		return
	var p: Vector3 = _from.lerp(_to, _t)
	p.y += _arc * sin(PI * _t) * (1.0 + _from.distance_to(_to) * 0.08)
	var v: Vector3 = p - _prev
	if kind == "arrow" and v.length() > 0.0001:
		rotation.z = atan2(v.y, v.x)
	_prev = p
	global_position = p

func _impact() -> void:
	var spot: Vector3 = Vector3(_to.x, 0.0, _to.z)
	if splash > 0.0:
		Fx.ring(get_parent(), spot, splash, Color("7b4bd6") if kind == "orb" else Color("8a7a55"))
		for u: Node3D in get_tree().get_nodes_in_group("team_%d" % (1 - team)):
			if u.is_queued_for_deletion() or u.inside:
				continue
			if absf(u.global_position.x - _to.x) <= splash:
				u.take_damage(damage)
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		# Splash already covered units; castles are never in a group, so hit them directly.
		if splash == 0.0 or target.has_method("is_castle"):
			target.take_damage(damage)
