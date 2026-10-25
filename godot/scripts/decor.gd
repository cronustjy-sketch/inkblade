extends Node3D

# Ink-wash ground dressing: mottled parchment, brush strokes, rocks and grass tufts.

const Ink := preload("res://scripts/ink.gd")
const ROCK := Color("d8cfb8")
const LAVA := Color("ff7a2a")

var _lava: bool = false

func build(ground: MeshInstance3D, length: float, lava: bool = false) -> void:
	_lava = lava
	_texture_ground(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1204
	_brush_strokes(rng, length)
	_rocks(rng, length)
	_tufts(rng, length)
	if _lava:
		_lava_pools(rng, length)

func _texture_ground(ground: MeshInstance3D) -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color("c4b79c"), Color("dccfb4")] if _lava else [Color("e6d9b8"), Color("f3ead3")])
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 128
	tex.noise = noise
	tex.color_ramp = ramp
	var mat := Ink.fill_mat(Color.WHITE)
	mat.albedo_texture = tex
	ground.material_override = mat

# Long flat translucent dashes, like dry-brush strokes.
func _brush_strokes(rng: RandomNumberGenerator, length: float) -> void:
	var mat := Ink.fill_mat(Color(0.05, 0.05, 0.07, 0.28))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 22:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(rng.randf_range(2.0, 7.0), rng.randf_range(0.06, 0.2))
		mi.mesh = quad
		mi.material_override = mat
		mi.rotation_degrees = Vector3(-90, rng.randf_range(-4, 4), 0)
		mi.position = Vector3(rng.randf_range(0, length), 0.02, rng.randf_range(-6.2, 6.2))
		add_child(mi)

func _rocks(rng: RandomNumberGenerator, length: float) -> void:
	for i in 14:
		var x: float = rng.randf_range(5.0, length - 5.0)
		var z: float = rng.randf_range(2.6, 6.2) * (1.0 if rng.randf() < 0.5 else -1.0)
		var r: float = rng.randf_range(0.25, 0.6)
		Ink.blob(self, r, Vector3(1.3, 0.7, 1.0), Vector3(x, r * 0.35, z), Color("8c8070") if _lava else ROCK, 0.07)

# Each tuft is three thin black blades; all share one MultiMesh to stay cheap.
func _tufts(rng: RandomNumberGenerator, length: float) -> void:
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.05
	blade.height = 0.5
	blade.radial_segments = 4
	blade.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	var tufts: int = 70
	mm.instance_count = tufts * 3
	for t in tufts:
		var base := Vector3(rng.randf_range(0, length), 0.2, rng.randf_range(-6.5, 6.5))
		for b in 3:
			var tilt: float = (b - 1) * 22.0 + rng.randf_range(-6, 6)
			var xf := Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(tilt))), base + Vector3((b - 1) * 0.1, 0, rng.randf_range(-0.05, 0.05)))
			mm.set_instance_transform(t * 3 + b, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Ink.fill_mat(Ink.INK)
	add_child(mmi)

# Lava terrain (levels 11-20): glowing pools beside the lane and thin cracks across it.
func _lava_pools(rng: RandomNumberGenerator, length: float) -> void:
	var glow := Ink.fill_mat(LAVA)
	for i in 9:
		var x: float = rng.randf_range(4.0, length - 4.0)
		var z: float = rng.randf_range(2.8, 6.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var w: float = rng.randf_range(1.6, 3.4)
		var d: float = rng.randf_range(0.8, 1.5)
		var rim := MeshInstance3D.new()
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = 0.5
		rim_mesh.bottom_radius = 0.5
		rim_mesh.height = 0.03
		rim_mesh.radial_segments = 16
		rim.mesh = rim_mesh
		rim.material_override = Ink.fill_mat(Ink.INK)
		rim.scale = Vector3(w + 0.3, 1.0, d + 0.3)
		rim.position = Vector3(x, 0.03, z)
		add_child(rim)
		var pool := MeshInstance3D.new()
		pool.mesh = rim_mesh
		pool.material_override = glow
		pool.scale = Vector3(w, 1.0, d)
		pool.position = Vector3(x, 0.045, z)
		add_child(pool)
	for i in 14:
		var crack := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(rng.randf_range(0.8, 2.2), 0.07)
		crack.mesh = quad
		crack.material_override = glow
		crack.rotation_degrees = Vector3(-90, rng.randf_range(-25, 25), 0)
		crack.position = Vector3(rng.randf_range(0, length), 0.025, rng.randf_range(-1.8, 1.8))
		add_child(crack)
