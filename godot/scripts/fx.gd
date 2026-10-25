extends RefCounted

# Small ink-style visual effects. All are cheap unshaded meshes that fade out and free themselves.

const Ink := preload("res://scripts/ink.gd")

static func _fade_mat(color: Color) -> StandardMaterial3D:
	var mat := Ink.fill_mat(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

# Three brush strokes sweeping out in front of `pos` along `facing` (+1 / -1).
static func slash_wave(parent: Node3D, pos: Vector3, facing: float, length: float) -> void:
	for i in 3:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(length, 0.14 - i * 0.03, 0.05)
		mi.mesh = box
		var mat := _fade_mat(Color(0.05, 0.05, 0.07, 0.8))
		mi.material_override = mat
		parent.add_child(mi)
		mi.global_position = pos + Vector3(facing * length * 0.5, 0.7 + i * 0.5, 1.0)
		mi.rotation_degrees.z = (-14.0 + i * 14.0) * facing
		mi.scale.x = 0.1
		var tw: Tween = mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "scale:x", 1.0, 0.12)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.3).set_delay(0.1)
		tw.chain().tween_callback(mi.queue_free)

# A flat expanding ring on the ground.
static func ring(parent: Node3D, pos: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 0.04
	cyl.radial_segments = 20
	mi.mesh = cyl
	var mat := _fade_mat(Color(color, 0.55))
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.05, pos.z)
	mi.scale = Vector3(0.2, 1.0, 0.2)
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius * 2.0, 1.0, radius * 2.0), duration)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)

# A short rising marker (used for heals).
static func rise(parent: Node3D, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.34, 0.12)
	mi.mesh = box
	var mat := _fade_mat(color)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = pos
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "global_position:y", pos.y + 1.2, 0.6)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(mi.queue_free)
