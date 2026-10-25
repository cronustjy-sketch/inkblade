extends Node3D

# Ink-wash ground dressing: mottled parchment, brush strokes, rocks and grass tufts.

const Ink := preload("res://scripts/ink.gd")
const ROCK := Color("d8cfb8")

func build(ground: MeshInstance3D, length: float) -> void:
	_texture_ground(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1204
	_brush_strokes(rng, length)
	_rocks(rng, length)
	_tufts(rng, length)

func _texture_ground(ground: MeshInstance3D) -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color("e6d9b8"), Color("f3ead3")])
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
		Ink.blob(self, r, Vector3(1.3, 0.7, 1.0), Vector3(x, r * 0.35, z), ROCK, 0.07)

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
