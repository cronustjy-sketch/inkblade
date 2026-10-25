extends RefCounted

# Hand-drawn ink look: an unshaded fill mesh plus a slightly larger black back-face hull as the outline.

const OUTLINE: float = 0.12
const INK := Color("0d0d0f")

static var _outline_mat: StandardMaterial3D

static func fill_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat

static func _hull_mat() -> StandardMaterial3D:
	if _outline_mat == null:
		_outline_mat = fill_mat(INK)
		_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	return _outline_mat

static func _add(parent: Node3D, fill: Mesh, hull: Mesh, pos: Vector3, rot: Vector3, color: Color, scl: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = rot
	root.scale = scl
	var f := MeshInstance3D.new()
	f.mesh = fill
	f.material_override = fill_mat(color)
	root.add_child(f)
	var h := MeshInstance3D.new()
	h.mesh = hull
	h.material_override = _hull_mat()
	root.add_child(h)
	parent.add_child(root)
	return root

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, t: float = OUTLINE) -> Node3D:
	var a := BoxMesh.new()
	a.size = size
	var b := BoxMesh.new()
	b.size = size + Vector3.ONE * 2.0 * t
	return _add(parent, a, b, pos, rot, color, Vector3.ONE)

static func cyl(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, t: float = OUTLINE) -> Node3D:
	var a := CylinderMesh.new()
	a.top_radius = top_r
	a.bottom_radius = bot_r
	a.height = h
	a.radial_segments = 14
	a.rings = 1
	var b := CylinderMesh.new()
	b.top_radius = top_r + t if top_r > 0.0 else 0.0
	b.bottom_radius = bot_r + t
	b.height = h + 2.0 * t
	b.radial_segments = 14
	b.rings = 1
	return _add(parent, a, b, pos, rot, color, Vector3.ONE)

# Squashed sphere (rocks).
static func blob(parent: Node3D, radius: float, scl: Vector3, pos: Vector3, color: Color, t: float = OUTLINE) -> Node3D:
	var a := SphereMesh.new()
	a.radius = radius
	a.height = radius * 2.0
	a.radial_segments = 10
	a.rings = 5
	var b := SphereMesh.new()
	b.radius = radius + t
	b.height = (radius + t) * 2.0
	b.radial_segments = 10
	b.rings = 5
	return _add(parent, a, b, pos, Vector3.ZERO, color, scl)
