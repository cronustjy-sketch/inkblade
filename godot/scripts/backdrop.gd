extends Node3D

# Layered shan shui (ink-wash) backdrops behind the lane. Each layer is a row of mirrored quads at its own
# depth, so ordinary camera movement gives the parallax. The paintings are black ink on white paper and are
# drawn with multiply blending: white leaves the scene colour untouched, ink darkens it.

# layers back to front: texture name, depth z, quad width (m), world height of the quad centre (m)
const LAYERS: Array[Dictionary] = [
	{"name": "far", "z": -75.0, "width": 44.0, "y": 8.0},
	{"name": "mid", "z": -34.0, "width": 30.0, "y": 8.2},
	{"name": "near", "z": -15.0, "width": 19.0, "y": 7.6},
]
const SPAN_X: Array[float] = [-70.0, 110.0] # world x range every layer must cover
const ASPECT: float = 1280.0 / 853.0

# x_center is where the layer's copies are centred (the middle of the lane).
func build(lava: bool, x_center: float = 20.0) -> void:
	var theme: String = "lava" if lava else "ink"
	for layer in LAYERS:
		var path: String = "res://backgrounds/%s_%s.jpg" % [theme, layer["name"]]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var width: float = layer["width"]
		var height: float = width / ASPECT
		# Deeper layers need to cover more world width, because the camera sees more of it.
		var spread: float = (SPAN_X[1] - SPAN_X[0]) * (1.0 + absf(layer["z"]) / 60.0) * 0.6
		var copies: int = maxi(3, ceili(spread / width) | 1) # odd count keeps one copy centred
		for i in copies:
			var idx: int = i - floori(copies * 0.5)
			var quad := MeshInstance3D.new()
			var mesh := QuadMesh.new()
			mesh.size = Vector2(width, height)
			quad.mesh = mesh
			quad.material_override = _material(tex, idx % 2 != 0)
			quad.position = Vector3(x_center + idx * width, layer["y"], layer["z"])
			add_child(quad)

func _material(tex: Texture2D, mirror: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_repeat = false
	if mirror:
		mat.uv1_scale = Vector3(-1.0, 1.0, 1.0)
		mat.uv1_offset = Vector3(1.0, 0.0, 0.0)
	return mat
