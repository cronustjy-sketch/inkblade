extends RefCounted

# Small, cheap visual effects for the 3D raid (flat translucent shapes, billboards and tweens).

static func flat_material(color: Color, additive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat

# Triangle fan on the ground pointing toward -Z with its apex at the origin.
static func cone_mesh(angle_deg: float, radius: float, segments: int = 28) -> ArrayMesh:
	var verts := PackedVector3Array()
	var half: float = deg_to_rad(angle_deg) * 0.5
	for i in segments:
		var a0: float = -half + 2.0 * half * i / segments
		var a1: float = -half + 2.0 * half * (i + 1) / segments
		verts.append(Vector3.ZERO)
		verts.append(Vector3(sin(a0) * radius, 0.0, -cos(a0) * radius))
		verts.append(Vector3(sin(a1) * radius, 0.0, -cos(a1) * radius))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func disc_mesh(radius: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.02
	m.radial_segments = 40
	m.rings = 1
	return m

static func ring_mesh(radius: float, thickness: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = maxf(radius - thickness * 0.5, 0.05)
	t.outer_radius = radius + thickness * 0.5
	t.rings = 48
	t.ring_segments = 4
	return t

# A burst at a hit point.
static func spark(parent: Node3D, pos: Vector3, color: Color = Color("fff2a8")) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	sphere.radial_segments = 10
	sphere.rings = 5
	mi.mesh = sphere
	var mat: StandardMaterial3D = flat_material(color, true)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.4
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.6, 0.18)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(mi.queue_free)

# A floating damage number.
static func popup(parent: Node3D, pos: Vector3, text: String, color: Color = Color.WHITE, size: int = 64) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.01
	label.modulate = color
	label.outline_size = 14
	label.outline_modulate = Color(0.05, 0.05, 0.08)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = pos
	var tw: Tween = label.create_tween().set_parallel(true)
	tw.tween_property(label, "global_position:y", pos.y + 1.6, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)

# A flat expanding ring on the ground.
static func ring(parent: Node3D, pos: Vector3, radius: float, color: Color, duration: float = 0.45) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = ring_mesh(1.0, 0.25)
	var mat: StandardMaterial3D = flat_material(color, true)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.08, pos.z)
	mi.scale = Vector3(0.2, 0.2, 0.2)
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.2, radius), duration)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)

# A white slash fan in front of the hero.
static func slash_arc(parent: Node3D, pos: Vector3, dir: Vector3, angle_deg: float, radius: float, color: Color = Color(1, 1, 1, 0.65)) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = cone_mesh(angle_deg, radius)
	var mat: StandardMaterial3D = flat_material(color, true)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.9, pos.z)
	mi.rotation.y = atan2(-dir.x, -dir.z)
	mi.scale = Vector3(0.6, 1, 0.6)
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.12)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(mi.queue_free)

# Falling swords over a circle for `duration` seconds.
static func sword_rain(parent: Node3D, center: Vector3, radius: float, duration: float, count: int = 24) -> void:
	var blade_mat := flat_material(Color("dfe3e6"))
	var edge_mat := flat_material(Color("0d0d12"))
	for i in count:
		var sword := Node3D.new()
		parent.add_child(sword)
		var blade := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 2.0, 0.06)
		blade.mesh = box
		blade.material_override = blade_mat
		sword.add_child(blade)
		var guard := MeshInstance3D.new()
		var gbox := BoxMesh.new()
		gbox.size = Vector3(0.7, 0.12, 0.1)
		guard.mesh = gbox
		guard.material_override = edge_mat
		guard.position.y = 1.0
		sword.add_child(guard)
		sword.rotation_degrees.z = 180.0
		var a: float = randf() * TAU
		var r: float = sqrt(randf()) * radius
		var land := Vector3(center.x + cos(a) * r, 1.1, center.z + sin(a) * r)
		sword.global_position = Vector3(land.x, 13.0, land.z)
		sword.visible = false
		var tw: Tween = sword.create_tween()
		tw.tween_interval(randf() * maxf(duration - 0.4, 0.05))
		tw.tween_callback(sword.set_visible.bind(true))
		tw.tween_property(sword, "global_position:y", land.y, 0.3)
		tw.tween_callback(spark.bind(parent, land - Vector3(0, 0.9, 0), Color("ffffff")))
		tw.tween_interval(0.25)
		tw.tween_callback(sword.queue_free)
