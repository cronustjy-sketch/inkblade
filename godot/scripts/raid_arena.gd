extends Node3D

# Round boss arena (about 60 m wide): grass floor, low stone walls, pillars for cover and a ring of far hills.
# Everything uses the toon material with outlines (scripts/toon.gd). The wall is visual; actors are kept inside
# by clamping to LIMIT, and the pillars have real colliders.

const Toon := preload("res://scripts/toon.gd")
const RADIUS: float = 30.0
const LIMIT: float = 28.4 # actors are kept inside this radius
const WALL_SEGMENTS: int = 30
const PILLAR_COUNT: int = 6
const PILLAR_RING: float = 14.5
const PILLAR_RADIUS: float = 1.3

var pillars: Array[Vector3] = []

func build() -> void:
	_floor()
	_walls()
	_pillars()
	_hills()

func _mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _floor() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.4
	disc.radial_segments = 56
	_mesh(self, disc, Toon.flat(Color("78cc58"), 0.0), Vector3(0, -0.2, 0))
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS + 2.0
	cyl.height = 0.4
	ground_shape.shape = cyl
	ground.add_child(ground_shape)
	ground.position = Vector3(0, -0.2, 0)
	add_child(ground)
	# A lighter inner ring with a black line, like a painted arena marking.
	var inner := CylinderMesh.new()
	inner.top_radius = 9.0
	inner.bottom_radius = 9.0
	inner.height = 0.02
	inner.radial_segments = 40
	_mesh(self, inner, Toon.flat(Color("9ae070"), 0.0), Vector3(0, 0.012, 0))
	var line := TorusMesh.new()
	line.inner_radius = 8.95
	line.outer_radius = 9.2
	line.rings = 40
	line.ring_segments = 4
	var line_mat := Toon.flat(Color("1c2a1c"), 0.0)
	var ring := _mesh(self, line, line_mat, Vector3(0, 0.03, 0))
	ring.scale = Vector3(1, 0.03, 1)

func _walls() -> void:
	var chord: float = 2.0 * RADIUS * sin(PI / WALL_SEGMENTS)
	var box := BoxMesh.new()
	box.size = Vector3(chord + 0.2, 1.5, 1.3)
	var mat := Toon.flat(Color("e4dcc4"), 0.07)
	var cap := BoxMesh.new()
	cap.size = Vector3(chord * 0.5, 0.35, 1.5)
	var cap_mat := Toon.flat(Color("f2b632"), 0.04)
	for i in WALL_SEGMENTS:
		var a: float = TAU * i / WALL_SEGMENTS
		var pos := Vector3(cos(a) * RADIUS, 0.75, sin(a) * RADIUS)
		var rot := Vector3(0, -a + PI * 0.5, 0)
		_mesh(self, box, mat, pos, rot)
		if i % 2 == 0:
			_mesh(self, cap, cap_mat, pos + Vector3(0, 0.9, 0), rot)

func _pillars() -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = PILLAR_RADIUS * 0.9
	shaft.bottom_radius = PILLAR_RADIUS
	shaft.height = 6.0
	shaft.radial_segments = 16
	var shaft_mat := Toon.flat(Color("efd9a4"), 0.07)
	var cap := BoxMesh.new()
	cap.size = Vector3(3.2, 0.6, 3.2)
	var cap_mat := Toon.flat(Color("f2b632"), 0.06)
	for i in PILLAR_COUNT:
		var a: float = TAU * i / PILLAR_COUNT
		var p := Vector3(cos(a) * PILLAR_RING, 0.0, sin(a) * PILLAR_RING)
		pillars.append(p)
		_mesh(self, shaft, shaft_mat, p + Vector3(0, 3.0, 0))
		_mesh(self, cap, cap_mat, p + Vector3(0, 6.2, 0))
		_mesh(self, cap, cap_mat, p + Vector3(0, 0.3, 0)).scale = Vector3(0.9, 1.0, 0.9)
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = PILLAR_RADIUS
		shape.height = 6.0
		col.shape = shape
		body.add_child(col)
		body.position = p + Vector3(0, 3.0, 0)
		add_child(body)

func _hills() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	var colors: Array[Color] = [Color("5fb85a"), Color("7fcf6a"), Color("4aa352")]
	for i in 18:
		var a: float = TAU * i / 18.0 + rng.randf_range(-0.1, 0.1)
		var r: float = rng.randf_range(52.0, 66.0)
		var size: float = rng.randf_range(10.0, 20.0)
		var sphere := SphereMesh.new()
		sphere.radius = size
		sphere.height = size * 2.0
		sphere.radial_segments = 20
		sphere.rings = 10
		var hill := _mesh(self, sphere, Toon.flat(colors[i % colors.size()], 0.25), Vector3(cos(a) * r, -size * 0.45, sin(a) * r))
		hill.scale = Vector3(1.6, 0.8, 1.2)

# Keeps a position inside the arena.
static func clamp_inside(pos: Vector3, limit: float = LIMIT) -> Vector3:
	var flat := Vector2(pos.x, pos.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
	return Vector3(flat.x, pos.y, flat.y)
