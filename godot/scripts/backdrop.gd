extends Node3D

# Flat cartoon landscape behind the lane: gradient sky, big sun, drifting clouds, 3 layers of smooth rolling hills
# (each with a thick dark outline) and a few scenery props. The palette depends on the chapter
# (grassland / desert / lava). Sky, sun and clouds hang off the camera so they always fill the view; the hills
# and props sit in the world at different depths, so ordinary camera movement gives the parallax.

const Levels := preload("res://data/levels.gd")
const SKY_DEPTH: float = 260.0
const HILL_WIDTH: float = 520.0
const HILL_STEP: float = 2.0
const HILL_BOTTOM: float = -60.0

const SKY_SHADER: String = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
uniform vec4 top_color : source_color;
uniform vec4 horizon_color : source_color;
void fragment() {
	ALBEDO = mix(top_color.rgb, horizon_color.rgb, smoothstep(0.12, 0.95, UV.y));
}
"""

const DISC_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 color : source_color;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = color.rgb;
	ALPHA = color.a * (1.0 - smoothstep(0.97, 1.0, d));
}
"""

# One entry per chapter. hills: [color, z, base height (m), amplitude (m), wavelength (m), jagged 0..1]
const PALETTES: Dictionary = {
	1: { # grassland
		"sky_top": Color("3d9be9"), "sky_horizon": Color("c4ecff"),
		"sun": Color("fff2a8"), "sun_halo": Color("fff8d0"), "cloud": Color("ffffff"),
		"ground": Color("6cc04a"), "ground_far": Color("a6dc78"), "outline": Color("1b3a2a"),
		"hills": [
			[Color("9bd6b0"), -150.0, 3.0, 13.0, 150.0, 0.0],
			[Color("6cbf74"), -85.0, 1.0, 8.0, 95.0, 0.0],
			[Color("49a25a"), -42.0, 0.0, 3.8, 60.0, 0.0],
		],
		"props": "grass",
	},
	2: { # desert
		"sky_top": Color("f08a3c"), "sky_horizon": Color("ffe7a6"),
		"sun": Color("fff4c2"), "sun_halo": Color("ffd98a"), "cloud": Color("fff1d6"),
		"ground": Color("e9b862"), "ground_far": Color("f6d48c"), "outline": Color("5a3410"),
		"hills": [
			[Color("f3c98b"), -150.0, 3.0, 12.0, 190.0, 0.0],
			[Color("e8ae63"), -85.0, 1.0, 7.0, 120.0, 0.0],
			[Color("d6924a"), -42.0, 0.0, 3.2, 80.0, 0.0],
		],
		"props": "desert",
	},
	3: { # lava
		"sky_top": Color("45203a"), "sky_horizon": Color("ff8a3e"),
		"sun": Color("ffcf5a"), "sun_halo": Color("ff9a3c"), "cloud": Color("5b2a34"),
		"ground": Color("7a5446"), "ground_far": Color("b45a3a"), "outline": Color("2a0e10"),
		"hills": [
			[Color("b0584a"), -150.0, 4.0, 16.0, 110.0, 0.8],
			[Color("84403c"), -85.0, 1.5, 10.0, 80.0, 0.8],
			[Color("5c2c2e"), -42.0, 0.0, 5.0, 55.0, 0.7],
		],
		"props": "lava",
	},
}

var _clouds: Array[Node3D] = []

# camera hosts the sky, sun and clouds; x_center is the middle of the lane.
func build(level: int, camera: Camera3D, x_center: float = 20.0) -> void:
	var pal: Dictionary = PALETTES[Levels.chapter(level)]
	_build_sky(pal, camera)
	for i in pal["hills"].size():
		var h: Array = pal["hills"][i]
		_build_hills(h[0], pal["outline"], h[1], h[2], h[3], h[4], h[5], x_center, i)
	_build_props(pal["props"], x_center)

func _process(delta: float) -> void:
	for cloud in _clouds:
		cloud.position.x += delta * 1.5
		if cloud.position.x > 130.0:
			cloud.position.x = -130.0

# ---------- sky ----------

func _build_sky(pal: Dictionary, camera: Camera3D) -> void:
	var sky := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(340.0, 150.0)
	sky.mesh = quad
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SKY_SHADER
	mat.shader = shader
	mat.set_shader_parameter("top_color", pal["sky_top"])
	mat.set_shader_parameter("horizon_color", pal["sky_horizon"])
	sky.material_override = mat
	sky.position = Vector3(0.0, 0.0, -SKY_DEPTH)
	camera.add_child(sky)

	# Big flat sun with two soft halo discs.
	var sun_pos := Vector3(58.0, 30.0, -SKY_DEPTH + 10.0)
	_disc(camera, sun_pos + Vector3(0, 0, -3), 42.0, Color(pal["sun_halo"], 0.25))
	_disc(camera, sun_pos + Vector3(0, 0, -2), 31.0, Color(pal["sun_halo"], 0.45))
	_disc(camera, sun_pos, 20.0, pal["sun"])

	# Flat cartoon clouds (a few overlapping discs each).
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 5:
		var cloud := Node3D.new()
		cloud.position = Vector3(rng.randf_range(-120.0, 120.0), rng.randf_range(8.0, 40.0), -SKY_DEPTH + 25.0)
		camera.add_child(cloud)
		var s: float = rng.randf_range(0.45, 0.8)
		for part in [Vector3(0, 0, 0), Vector3(14, 3, 0), Vector3(-14, 2, 0), Vector3(27, -3, 0), Vector3(-26, -3, 0)]:
			_disc(cloud, part * s, (22.0 - absf(part.x) * 0.35) * s, pal["cloud"])
		_clouds.append(cloud)

func _disc(parent: Node3D, pos: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = DISC_SHADER
	mat.shader = shader
	mat.set_shader_parameter("color", color)
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

# ---------- hills ----------

func _build_hills(color: Color, outline: Color, z: float, base: float, amp: float, wave: float, jagged: float, x_center: float, index: int) -> void:
	var dist: float = 27.0 - z
	var line: float = dist * 0.0021 # about 3-4 px of outline on screen
	var top := _hill_mesh(base, amp, wave, jagged, index, line)
	var back := MeshInstance3D.new()
	back.mesh = top
	back.material_override = _flat(outline)
	back.position = Vector3(x_center, 0.0, z - 0.2)
	add_child(back)
	var front := MeshInstance3D.new()
	front.mesh = _hill_mesh(base, amp, wave, jagged, index, 0.0)
	front.material_override = _flat(color)
	front.position = Vector3(x_center, 0.0, z)
	add_child(front)

func _hill_mesh(base: float, amp: float, wave: float, jagged: float, index: int, lift: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var count: int = int(HILL_WIDTH / HILL_STEP)
	for i in count + 1:
		var x: float = -HILL_WIDTH * 0.5 + i * HILL_STEP
		var k: float = TAU / wave
		var s: float = 0.55 * sin(k * x + index * 2.1) + 0.3 * sin(k * 2.3 * x + index * 1.3 + 1.0) + 0.15 * sin(k * 4.7 * x + index)
		if jagged > 0.0:
			# Sharper, craggier peaks for volcanic chapters.
			s = lerpf(s, 1.0 - absf(sin(k * 0.5 * x + index * 1.7)) * 1.6 + 0.3 * sin(k * 3.1 * x), jagged)
		verts.append(Vector3(x, base + amp * 0.5 * (s + 1.0) + lift, 0.0))
		verts.append(Vector3(x, HILL_BOTTOM, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return mesh

func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

# ---------- props ----------

# Scenery sprites (baked from the Codex prop sheet) scattered behind the lane.
func _build_props(theme: String, x_center: float) -> void:
	var textures: Array[Texture2D] = []
	for i in 6:
		var path: String = "res://sprites/props_%s_%d.png" % [theme, i]
		if ResourceLoader.exists(path):
			textures.append(load(path))
	if textures.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var x: float = x_center - 60.0
	while x < x_center + 60.0:
		x += rng.randf_range(6.0, 12.0)
		if x < 7.0 or (x > 33.0 and x < 47.0 and false):
			continue
		var tex: Texture2D = textures[rng.randi() % textures.size()]
		var height: float = rng.randf_range(1.2, 2.6)
		var sprite := Sprite3D.new()
		sprite.texture = tex
		sprite.pixel_size = height / float(tex.get_height())
		sprite.offset = Vector2(0.0, tex.get_height() * 0.5)
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.5
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.position = Vector3(x, 0.0, rng.randf_range(-16.0, -7.0))
		add_child(sprite)

# ---------- ground ----------

const GROUND_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 ground_color : source_color;
uniform vec3 far_color : source_color;
uniform vec3 outline_color : source_color;
varying float wz;
void vertex() {
	wz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}
void fragment() {
	float far_t = clamp((-wz - 5.0) / 90.0, 0.0, 1.0);
	vec3 c = mix(ground_color, far_color, far_t);
	// A slightly darker path along the lane, with a thick outline line at its back edge.
	float lane = 1.0 - smoothstep(3.4, 3.6, abs(wz + 0.5));
	c = mix(c, c * 0.88, lane);
	float edge = 1.0 - smoothstep(0.0, 0.18, abs(wz + 4.0));
	c = mix(c, outline_color, edge * 0.55);
	ALBEDO = c;
}
"""

# The flat ground slab: lane path, fading to a lighter colour toward the horizon.
func style_ground(ground: MeshInstance3D, level: int) -> void:
	var pal: Dictionary = PALETTES[Levels.chapter(level)]
	(ground.mesh as BoxMesh).size = Vector3(700.0, 0.4, 600.0)
	ground.position = Vector3(20.0, -0.2, -100.0)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	mat.shader = shader
	mat.set_shader_parameter("ground_color", pal["ground"])
	mat.set_shader_parameter("far_color", pal["ground_far"])
	mat.set_shader_parameter("outline_color", pal["outline"])
	ground.material_override = mat
