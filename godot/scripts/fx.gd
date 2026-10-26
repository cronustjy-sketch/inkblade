extends RefCounted

# Small ink-style visual effects. All are cheap unshaded meshes that fade out and free themselves.

const Ink := preload("res://scripts/ink.gd")
const InkFx := preload("res://scripts/inkfx.gd")

static func _fade_mat(color: Color) -> StandardMaterial3D:
	var mat := Ink.fill_mat(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

# Three brush strokes sweeping out in front of `pos` along `facing` (+1 / -1).
static func slash_wave(parent: Node3D, pos: Vector3, facing: float, length: float) -> void:
	# Three overlapping brush strokes sweeping out in front of `pos`.
	for i in 3:
		var at: Vector3 = pos + Vector3(facing * (0.4 + i * 0.5), 0.6 + i * 0.55, 0.0)
		InkFx.slash(parent, at, facing, length * (0.55 - i * 0.05), -24.0 + i * 20.0, Color("f2b632"))

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

# Falling swords between x0 and x1 over `duration` seconds (Sword Rain).
static func sword_rain(parent: Node3D, x0: float, x1: float, duration: float, count: int = 26) -> void:
	for i in count:
		var sword := Node3D.new()
		parent.add_child(sword)
		Ink.box(sword, Vector3(0.12, 1.3, 0.04), Vector3.ZERO, Color("dfe3e6"), Vector3.ZERO, 0.025)
		Ink.box(sword, Vector3(0.4, 0.07, 0.06), Vector3(0, 0.6, 0), Color("0d0d0f"), Vector3.ZERO, 0.0)
		sword.rotation_degrees.z = 180.0
		sword.visible = false
		var x: float = randf_range(minf(x0, x1), maxf(x0, x1))
		var z: float = randf_range(-1.3, 1.3)
		sword.global_position = Vector3(x, 10.0, z)
		var tw: Tween = sword.create_tween()
		tw.tween_interval(randf() * maxf(duration - 0.4, 0.05))
		tw.tween_callback(sword.set_visible.bind(true))
		tw.tween_property(sword, "global_position:y", 0.7, 0.35)
		tw.tween_interval(0.15)
		tw.tween_callback(sword.queue_free)
