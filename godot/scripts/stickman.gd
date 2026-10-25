extends Node3D

# Ink-style 3D stickman rigs built from primitives, with procedural walk / attack animation.
# Everything is built facing +X (toward the enemy for the player team); team 1 is flipped.
# Limb pivots rotate about Z: positive angles swing a hanging limb forward (+X).

const Ink := preload("res://scripts/ink.gd")
const TEAM_COLORS: Array[Color] = [Color("e8b44a"), Color("de4b3f")]
const BLACK := Color("0d0d0f")
const PARCH := Color("efe6cf")
const STEEL := Color("dfe3e6")
const WOOD := Color("8a5a2f")
const GOLD := Color("e8b44a")
const MAGIC := Color("7b4bd6")

enum Shape { BOX, CYL, SPHERE, CONE }

const HIP_Y: float = 0.8
const SHOULDER_Y: float = 1.36
const ARM_LEN: float = 0.55
const LEG_LEN: float = 0.8

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}
static var _hull: StandardMaterial3D

var kind: String = "human"
var key: String = "soldier"
var team: int = 0
var height: float = 1.9
var gait: float = 4.0

var _holder: Node3D
var _leg_r: Node3D
var _leg_l: Node3D
var _arm_r: Node3D
var _arm_l: Node3D
var _hand_r: Node3D
var _hand_l: Node3D
var _parts: Array[Node3D] = []
var _pose_r: float = 0.5
var _pose_l: float = 0.3
var _wind: float = 2.4
var _face: float = 1.0
var _moving: bool = false
var _phase: float = 0.0
var _clock: float = 0.0
var _attack_t: float = -1.0
var _attack_dur: float = 0.35

func setup(p_key: String, p_team: int, speed_mps: float) -> void:
	key = p_key
	team = p_team
	gait = 4.2 * speed_mps if speed_mps > 0.0 else 4.0
	_holder = Node3D.new()
	_face = 1.0 if team == 0 else -1.0
	_holder.rotation_degrees.y = 0.0 if team == 0 else 180.0
	add_child(_holder)
	match key:
		"cavalry":
			kind = "cavalry"
			_build_cavalry()
		"catapult":
			kind = "catapult"
			_build_catapult()
		"dragon":
			kind = "dragon"
			_build_dragon()
		_:
			kind = "human"
			var scl: float = 1.9 if key == "giant" else 1.0
			_holder.scale = Vector3.ONE * scl
			height = 1.95 * scl
			_build_human(_holder)
			_equip(key)

func set_moving(value: bool) -> void:
	_moving = value

func play_attack(duration: float) -> void:
	_attack_dur = clampf(duration * 0.5, 0.2, 0.6)
	_attack_t = 0.0

func _process(delta: float) -> void:
	_clock += delta
	if _moving:
		_phase += delta * gait
	if _attack_t >= 0.0:
		_attack_t += delta
		if _attack_t >= _attack_dur:
			_attack_t = -1.0
	match kind:
		"human":
			_anim_human()
		"cavalry":
			_anim_cavalry()
		"catapult":
			_anim_catapult()
		"dragon":
			_anim_dragon()

# ---------- animation ----------

func _attack_u() -> float:
	return clampf(_attack_t / _attack_dur, 0.0, 1.0)

func _attack_angle() -> float:
	var u: float = _attack_u()
	if u < 0.45:
		return lerpf(_pose_r, _wind, u / 0.45)
	return lerpf(_wind, _pose_r, smoothstep(0.0, 1.0, (u - 0.45) / 0.55))

func _anim_human(legs: bool = true) -> void:
	var s: float = sin(_phase) if _moving else 0.0
	if legs:
		_leg_r.rotation.z = s * 0.7
		_leg_l.rotation.z = -s * 0.7
		_holder.position.y = absf(s) * 0.05 if _moving else sin(_clock * 2.0) * 0.012
	_arm_l.rotation.z = _pose_l - s * 0.45
	_arm_r.rotation.z = _pose_r + s * 0.45
	if _attack_t >= 0.0:
		_arm_r.rotation.z = _attack_angle()
		if legs:
			_holder.position.x = sin(_attack_u() * PI) * 0.2 * _face
	elif legs:
		_holder.position.x = 0.0

func _anim_cavalry() -> void:
	var s: float = sin(_phase) if _moving else 0.0
	_parts[0].rotation.z = s * 0.8
	_parts[1].rotation.z = sin(_phase + 0.6) * 0.8 if _moving else 0.0
	_parts[2].rotation.z = -s * 0.8
	_parts[3].rotation.z = -sin(_phase + 0.6) * 0.8 if _moving else 0.0
	_holder.position.y = absf(s) * 0.08 if _moving else sin(_clock * 2.0) * 0.01
	_anim_human(false)

func _anim_catapult() -> void:
	var wheel_spin: float = -_phase * 0.8
	_parts[1].rotation.z = wheel_spin
	_parts[2].rotation.z = wheel_spin
	var arm: float = 2.4
	if _attack_t >= 0.0:
		var u: float = _attack_u()
		arm = lerpf(2.4, 0.4, u / 0.3) if u < 0.3 else lerpf(0.4, 2.4, (u - 0.3) / 0.7)
	_parts[0].rotation.z = arm

func _anim_dragon() -> void:
	var flap: float = sin(_clock * 7.0) * 0.55
	_parts[0].rotation.x = flap
	_parts[1].rotation.x = -flap
	_holder.position.y = 2.3 + sin(_clock * 2.5) * 0.12
	var bite: float = sin(_attack_u() * PI) * 0.25 if _attack_t >= 0.0 else 0.0
	_parts[2].rotation.z = -bite

# ---------- primitive helpers ----------

static func _mesh(shape: int) -> Mesh:
	if _meshes.has(shape):
		return _meshes[shape]
	var m: Mesh
	match shape:
		Shape.BOX:
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			m = b
		Shape.CYL:
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 8
			c.rings = 1
			m = c
		Shape.SPHERE:
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 10
			s.rings = 5
			m = s
		_:
			var k := CylinderMesh.new()
			k.top_radius = 0.0
			k.bottom_radius = 0.5
			k.height = 1.0
			k.radial_segments = 8
			k.rings = 1
			m = k
	_meshes[shape] = m
	return m

static func _mat(color: Color) -> StandardMaterial3D:
	var id: String = color.to_html()
	if not _mats.has(id):
		_mats[id] = Ink.fill_mat(color)
	return _mats[id]

static func _hull_material() -> StandardMaterial3D:
	if _hull == null:
		_hull = Ink.fill_mat(Ink.INK)
		_hull.cull_mode = BaseMaterial3D.CULL_FRONT
	return _hull

# Size is the full extent: cylinders use (diameter, length, diameter).
func _part(parent: Node3D, shape: int, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, outline: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = rot
	var f := MeshInstance3D.new()
	f.mesh = _mesh(shape)
	f.material_override = _mat(color)
	f.scale = size
	root.add_child(f)
	if outline > 0.0:
		var h := MeshInstance3D.new()
		h.mesh = _mesh(shape)
		h.material_override = _hull_material()
		h.scale = size + Vector3.ONE * 2.0 * outline
		root.add_child(h)
	parent.add_child(root)
	return root

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p

func _limb(parent: Node3D, pos: Vector3, length: float, thick: float) -> Node3D:
	var pivot: Node3D = _pivot(parent, pos)
	_part(pivot, Shape.CYL, Vector3(thick, length, thick), Vector3(0, -length * 0.5, 0), BLACK)
	return pivot

# A weapon root: its +Y axis is the weapon's length; grip_deg tilts it relative to the arm.
func _mount(hand: Node3D, grip_deg: float) -> Node3D:
	var w: Node3D = _pivot(hand, Vector3.ZERO)
	w.rotation_degrees.z = grip_deg
	return w

# ---------- builders ----------

func _build_human(parent: Node3D) -> void:
	var color: Color = TEAM_COLORS[team]
	_leg_r = _limb(parent, Vector3(0, HIP_Y, 0.07), LEG_LEN, 0.07)
	_leg_l = _limb(parent, Vector3(0, HIP_Y, -0.07), LEG_LEN, 0.07)
	_part(parent, Shape.CYL, Vector3(0.17, 0.62, 0.17), Vector3(0, HIP_Y + 0.29, 0), color)
	_part(parent, Shape.SPHERE, Vector3(0.38, 0.38, 0.38), Vector3(0, 1.6, 0), PARCH, Vector3.ZERO, 0.035)
	_arm_r = _limb(parent, Vector3(0, SHOULDER_Y, 0.12), ARM_LEN, 0.06)
	_arm_l = _limb(parent, Vector3(0, SHOULDER_Y, -0.12), ARM_LEN, 0.06)
	_hand_r = _pivot(_arm_r, Vector3(0, -ARM_LEN, 0))
	_hand_l = _pivot(_arm_l, Vector3(0, -ARM_LEN, 0))

func _equip(unit_key: String) -> void:
	var color: Color = TEAM_COLORS[team]
	match unit_key:
		"soldier":
			_sword(_hand_r, 1.0)
			_pose_r = 0.5
			_pose_l = 0.2
		"shield":
			_sword(_hand_r, 1.0)
			var s: Node3D = _mount(_hand_l, 0.0)
			_part(s, Shape.CYL, Vector3(0.72, 0.07, 0.72), Vector3(0.1, 0.0, 0.0), color, Vector3(90, 0, 0), 0.04)
			_part(s, Shape.SPHERE, Vector3(0.22, 0.22, 0.14), Vector3(0.1, 0.0, 0.07), PARCH, Vector3.ZERO, 0.025)
			_pose_r = 0.5
			_pose_l = 0.9
		"giant":
			var c: Node3D = _mount(_hand_r, -65.0)
			_part(c, Shape.CYL, Vector3(0.07, 0.5, 0.07), Vector3(0, 0.1, 0), WOOD)
			_part(c, Shape.CONE, Vector3(0.3, 0.95, 0.3), Vector3(0, 0.75, 0), WOOD, Vector3(180, 0, 0), 0.03)
			_pose_r = 0.6
			_pose_l = 0.2
			_wind = 2.6
		"spear":
			var p: Node3D = _mount(_hand_r, -75.0)
			_part(p, Shape.CYL, Vector3(0.04, 2.0, 0.04), Vector3(0, 0.5, 0), WOOD)
			_part(p, Shape.CONE, Vector3(0.1, 0.3, 0.1), Vector3(0, 1.65, 0), STEEL, Vector3.ZERO, 0.02)
			_pose_r = 0.9
			_pose_l = 0.5
			_wind = 0.2
		"archer":
			var b: Node3D = _mount(_hand_l, -80.0)
			_part(b, Shape.BOX, Vector3(0.05, 0.5, 0.05), Vector3(0, 0, 0), WOOD)
			_part(b, Shape.BOX, Vector3(0.05, 0.5, 0.05), Vector3(-0.07, 0.43, 0), WOOD, Vector3(0, 0, 15))
			_part(b, Shape.BOX, Vector3(0.05, 0.5, 0.05), Vector3(-0.07, -0.43, 0), WOOD, Vector3(0, 0, -15))
			_part(b, Shape.BOX, Vector3(0.015, 1.0, 0.015), Vector3(-0.13, 0, 0), BLACK)
			_pose_l = 1.4
			_pose_r = 1.3
			_wind = 0.3
		"witch":
			_staff(MAGIC)
			_part(_holder, Shape.CONE, Vector3(0.34, 0.5, 0.34), Vector3(0, 2.0, 0), BLACK, Vector3.ZERO, 0.0)
			_part(_holder, Shape.CYL, Vector3(0.55, 0.03, 0.55), Vector3(0, 1.78, 0), BLACK)
			_wind = 2.0
		"assassin":
			_dagger(_hand_r)
			_dagger(_hand_l)
			_part(_holder, Shape.BOX, Vector3(0.5, 0.07, 0.05), Vector3(-0.3, 1.4, 0), color, Vector3(0, 0, 12))
			_pose_r = 1.0
			_pose_l = 1.0
			_wind = 2.0
		"priest":
			_staff(GOLD)
			_part(_holder, Shape.CYL, Vector3(0.46, 0.025, 0.46), Vector3(0, 1.92, 0), GOLD, Vector3(0, 0, 0), 0.02)
			_wind = 1.9

func _sword(hand: Node3D, length: float) -> void:
	var w: Node3D = _mount(hand, -60.0)
	_part(w, Shape.BOX, Vector3(0.24, 0.05, 0.07), Vector3(0, 0.05, 0), BLACK)
	_part(w, Shape.BOX, Vector3(0.07, 0.7 * length, 0.025), Vector3(0, 0.05 + 0.35 * length, 0), STEEL, Vector3.ZERO, 0.02)

func _dagger(hand: Node3D) -> void:
	var w: Node3D = _mount(hand, -60.0)
	_part(w, Shape.BOX, Vector3(0.05, 0.4, 0.02), Vector3(0, 0.22, 0), STEEL, Vector3.ZERO, 0.015)

func _staff(orb_color: Color) -> void:
	var w: Node3D = _mount(_hand_r, -80.0)
	_part(w, Shape.CYL, Vector3(0.04, 1.5, 0.04), Vector3(0, 0.4, 0), WOOD)
	_part(w, Shape.SPHERE, Vector3(0.22, 0.22, 0.22), Vector3(0, 1.2, 0), orb_color, Vector3.ZERO, 0.03)
	_pose_r = 1.2
	_pose_l = 0.25

func _build_cavalry() -> void:
	height = 2.7
	gait *= 0.7
	# Horse: legs first so _parts[0..3] are the gallop legs.
	var leg_specs: Array = [Vector3(0.5, 0.85, 0.13), Vector3(0.5, 0.85, -0.13), Vector3(-0.5, 0.85, 0.13), Vector3(-0.5, 0.85, -0.13)]
	for spec: Vector3 in leg_specs:
		_parts.append(_limb(_holder, spec, 0.85, 0.09))
	_part(_holder, Shape.BOX, Vector3(1.3, 0.5, 0.4), Vector3(0, 1.1, 0), PARCH, Vector3.ZERO, 0.04)
	_part(_holder, Shape.BOX, Vector3(0.45, 0.07, 0.44), Vector3(0, 1.38, 0), TEAM_COLORS[team])
	_part(_holder, Shape.BOX, Vector3(0.28, 0.6, 0.22), Vector3(0.62, 1.4, 0), PARCH, Vector3(0, 0, -35), 0.035)
	_part(_holder, Shape.BOX, Vector3(0.45, 0.2, 0.2), Vector3(0.95, 1.68, 0), PARCH, Vector3(0, 0, -20), 0.035)
	_part(_holder, Shape.BOX, Vector3(0.1, 0.5, 0.1), Vector3(-0.72, 1.15, 0), BLACK, Vector3(0, 0, 25))
	var rider: Node3D = _pivot(_holder, Vector3(0, 0.55, 0))
	_build_human(rider)
	var p: Node3D = _mount(_hand_r, -75.0)
	_part(p, Shape.CYL, Vector3(0.04, 2.2, 0.04), Vector3(0, 0.6, 0), WOOD)
	_part(p, Shape.CONE, Vector3(0.1, 0.3, 0.1), Vector3(0, 1.85, 0), STEEL, Vector3.ZERO, 0.02)
	_leg_r.rotation.z = 0.6
	_leg_l.rotation.z = 0.6
	_pose_r = 1.3
	_pose_l = 0.8
	_wind = 0.3

func _build_catapult() -> void:
	height = 2.6
	var arm_pivot: Node3D = _pivot(_holder, Vector3(0, 1.45, 0))
	_parts.append(arm_pivot)
	var wheels: Array[Node3D] = []
	for wz: float in [0.62, -0.62]:
		var wp: Node3D = _pivot(_holder, Vector3(0.0, 0.45, wz))
		_part(wp, Shape.CYL, Vector3(0.9, 0.12, 0.9), Vector3.ZERO, WOOD, Vector3(90, 0, 0), 0.04)
		_part(wp, Shape.BOX, Vector3(0.85, 0.07, 0.15), Vector3.ZERO, BLACK)
		wheels.append(wp)
	_parts.append(wheels[0])
	_parts.append(wheels[1])
	_part(_holder, Shape.BOX, Vector3(2.0, 0.25, 1.0), Vector3(0, 0.75, 0), WOOD, Vector3.ZERO, 0.05)
	for pz: float in [0.5, -0.5]:
		_part(_holder, Shape.BOX, Vector3(0.18, 0.8, 0.1), Vector3(0, 1.15, pz), WOOD, Vector3.ZERO, 0.04)
	_part(arm_pivot, Shape.BOX, Vector3(1.8, 0.12, 0.14), Vector3(0.8, 0, 0), WOOD, Vector3.ZERO, 0.03)
	_part(arm_pivot, Shape.BOX, Vector3(0.45, 0.3, 0.4), Vector3(1.65, 0.12, 0), TEAM_COLORS[team], Vector3.ZERO, 0.04)
	_part(arm_pivot, Shape.SPHERE, Vector3(0.3, 0.3, 0.3), Vector3(1.65, 0.38, 0), PARCH, Vector3.ZERO, 0.03)
	_part(arm_pivot, Shape.BOX, Vector3(0.35, 0.35, 0.35), Vector3(-0.2, 0, 0), BLACK)
	arm_pivot.rotation.z = 2.4

func _build_dragon() -> void:
	height = 4.6
	gait = 3.0
	var color: Color = TEAM_COLORS[team]
	var wing_r: Node3D = _pivot(_holder, Vector3(0.0, 0.5, 0.3))
	var wing_l: Node3D = _pivot(_holder, Vector3(0.0, 0.5, -0.3))
	_parts.append(wing_r)
	_parts.append(wing_l)
	_part(wing_r, Shape.BOX, Vector3(1.0, 0.05, 1.9), Vector3(-0.2, 0.0, 0.95), color, Vector3(0, 0, 0), 0.04)
	_part(wing_l, Shape.BOX, Vector3(1.0, 0.05, 1.9), Vector3(-0.2, 0.0, -0.95), color, Vector3(0, 0, 0), 0.04)
	var head: Node3D = _pivot(_holder, Vector3(1.4, 0.55, 0))
	_parts.append(head)
	_part(head, Shape.BOX, Vector3(0.7, 0.3, 0.3), Vector3(0.3, 0, 0), PARCH, Vector3.ZERO, 0.04)
	_part(head, Shape.CONE, Vector3(0.12, 0.3, 0.12), Vector3(0.0, 0.25, 0.1), BLACK, Vector3(0, 0, 20))
	_part(_holder, Shape.SPHERE, Vector3(1.8, 0.8, 0.7), Vector3(0, 0, 0), PARCH, Vector3.ZERO, 0.05)
	_part(_holder, Shape.BOX, Vector3(0.6, 0.3, 0.3), Vector3(1.0, 0.3, 0), PARCH, Vector3(0, 0, 40), 0.04)
	_part(_holder, Shape.CONE, Vector3(0.5, 2.0, 0.5), Vector3(-1.7, -0.1, 0), PARCH, Vector3(0, 0, 90), 0.04)
	_part(_holder, Shape.BOX, Vector3(1.4, 0.1, 0.1), Vector3(0, 0.45, 0), color)
	_holder.position.y = 2.3

func set_facing(right: bool) -> void:
	_face = 1.0 if right else -1.0
	_holder.rotation_degrees.y = 0.0 if right else 180.0
