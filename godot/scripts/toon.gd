extends RefCounted

# Toon (cel) shading with thick black outlines for the 3D raid mode, cheap enough for integrated GPUs:
# 3-band lighting from the arena's directional light direction (no real-time shadows), a gamma lift + saturation
# boost so dark textures turn colourful, and an inverted-hull outline pass.

const LIGHT_DIR := Vector3(0.45, 0.85, 0.35)
const INK := Color(0.04, 0.04, 0.07)
const EMISSION: float = 0.22 # texture added back as glow, like the web game's emissive models

static var _smooth_cache: Dictionary = {}

# //ALPHA is replaced by "ALPHA = alpha;" in the fade variant (used for walls and pillars that fade out when
# they block the camera); plain characters keep the cheaper opaque pipeline.
const TOON_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_tex = false;
uniform vec3 light_dir = vec3(0.45, 0.85, 0.35);
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float brightness = 1.0;
uniform float lift = 1.0;
uniform float saturation = 1.0;
uniform float rim = 0.0;
uniform float alpha = 1.0;
uniform float emission = 0.0;
varying vec3 wnormal;
void vertex() {
	wnormal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
	vec4 c = albedo;
	if (use_tex) {
		c *= texture(albedo_tex, UV);
	}
	vec3 base = pow(max(c.rgb, vec3(0.0)), vec3(lift)) * brightness;
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(vec3(grey), base, saturation);
	vec3 n = normalize(wnormal);
	if (!FRONT_FACING) {
		n = -n;
	}
	float nl = dot(n, normalize(light_dir));
	float band = nl > 0.35 ? 1.08 : (nl > -0.2 ? 0.86 : 0.66);
	vec3 col = clamp(base * band + c.rgb * emission, vec3(0.0), vec3(1.0));
	float fres = pow(1.0 - clamp(dot(n, vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 3.0);
	col = mix(col, vec3(1.0), rim * step(0.55, fres) * 0.6);
	col = mix(col, flash_color.rgb, flash);
	ALBEDO = col;
	//ALPHA
}
"""

const OUTLINE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_front;
uniform float width = 0.03;
uniform vec4 color : source_color = vec4(0.04, 0.04, 0.07, 1.0);
uniform float alpha = 1.0;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = color.rgb;
	//ALPHA
}
"""

static var _toon_shader: Shader
static var _outline_shader: Shader
static var _toon_fade: Shader
static var _outline_fade: Shader

static func _shaders() -> void:
	if _toon_shader != null:
		return
	_toon_shader = Shader.new()
	_toon_shader.code = TOON_SHADER
	_outline_shader = Shader.new()
	_outline_shader.code = OUTLINE_SHADER
	_toon_fade = Shader.new()
	_toon_fade.code = TOON_SHADER.replace("//ALPHA", "ALPHA = alpha;").replace("render_mode unshaded, cull_disabled;", "render_mode unshaded, cull_disabled, depth_draw_always;")
	_outline_fade = Shader.new()
	_outline_fade.code = OUTLINE_SHADER.replace("//ALPHA", "ALPHA = alpha;")

static func outline_material(width: float, color: Color = INK, fade: bool = false) -> ShaderMaterial:
	_shaders()
	var m := ShaderMaterial.new()
	m.shader = _outline_fade if fade else _outline_shader
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("color", color)
	return m

# A flat-colour toon material, optionally with an outline pass (width in the mesh's local units).
static func flat(color: Color, outline_width: float = 0.05, fade: bool = false) -> ShaderMaterial:
	_shaders()
	var m := ShaderMaterial.new()
	m.shader = _toon_fade if fade else _toon_shader
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("light_dir", LIGHT_DIR)
	if outline_width > 0.0:
		m.next_pass = outline_material(outline_width, INK, fade)
	return m

# Sets the see-through amount of a fade material (and its outline pass).
static func set_alpha(m: ShaderMaterial, value: float) -> void:
	m.set_shader_parameter("alpha", value)
	if m.next_pass is ShaderMaterial:
		(m.next_pass as ShaderMaterial).set_shader_parameter("alpha", value)

# Replaces every material under `root` with a toon version of itself (keeps the albedo texture / colour) plus an
# outline. world_scale is the node scale applied to the model, so the outline stays `outline_world` metres thick.
# `lift` < 1 brightens dark textures, `saturation` > 1 makes them more colourful. Returns the toon materials so
# callers can flash them on hit.
static func apply_model(root: Node, world_scale: float, outline_world: float = 0.035, tint: Color = Color.WHITE, brightness: float = 1.0, lift: float = 0.55, saturation: float = 1.45, emission: float = EMISSION) -> Array[ShaderMaterial]:
	_shaders()
	var made: Array[ShaderMaterial] = []
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = mi as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_instance.mesh = smooth_mesh(mesh_instance.mesh)
		for s in mesh_instance.mesh.get_surface_count():
			var src: Material = mesh_instance.get_active_material(s)
			var toon := ShaderMaterial.new()
			toon.shader = _toon_shader
			toon.set_shader_parameter("light_dir", LIGHT_DIR)
			toon.set_shader_parameter("brightness", brightness)
			toon.set_shader_parameter("lift", lift)
			toon.set_shader_parameter("saturation", saturation)
			toon.set_shader_parameter("rim", 0.0)
			toon.set_shader_parameter("emission", emission)
			var color: Color = Color.WHITE
			if src is BaseMaterial3D:
				var base: BaseMaterial3D = src
				color = base.albedo_color
				if base.albedo_texture != null:
					toon.set_shader_parameter("albedo_tex", base.albedo_texture)
					toon.set_shader_parameter("use_tex", true)
			toon.set_shader_parameter("albedo", Color(color.r * tint.r, color.g * tint.g, color.b * tint.b, 1.0))
			toon.next_pass = outline_material(outline_world / maxf(world_scale, 0.001))
			mesh_instance.set_surface_override_material(s, toon)
			made.append(toon)
	return made

static func set_flash(materials: Array[ShaderMaterial], amount: float, color: Color = Color.WHITE) -> void:
	for m in materials:
		m.set_shader_parameter("flash", amount)
		m.set_shader_parameter("flash_color", color)

# Returns a copy of `mesh` whose normals are averaged over vertices that share a position. Imported AI-made models
# have hard split normals, which tear the inverted-hull outline into black shards; smooth normals keep it clean.
static func smooth_mesh(mesh: Mesh) -> Mesh:
	if _smooth_cache.has(mesh):
		return _smooth_cache[mesh]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			idx = arrays[Mesh.ARRAY_INDEX]
		else:
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var sums: Dictionary = {}
		for t in idx.size() / 3:
			var a: Vector3 = verts[idx[t * 3]]
			var b: Vector3 = verts[idx[t * 3 + 1]]
			var c: Vector3 = verts[idx[t * 3 + 2]]
			var face: Vector3 = (b - a).cross(c - a)
			for v: Vector3 in [a, b, c]:
				var key := Vector3i(roundi(v.x * 2000.0), roundi(v.y * 2000.0), roundi(v.z * 2000.0))
				sums[key] = sums.get(key, Vector3.ZERO) + face
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		for i in verts.size():
			var v: Vector3 = verts[i]
			var key := Vector3i(roundi(v.x * 2000.0), roundi(v.y * 2000.0), roundi(v.z * 2000.0))
			normals[i] = (sums[key] as Vector3).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays)
		out.surface_set_name(s, mesh.surface_get_name(s))
		out.surface_set_material(s, mesh.surface_get_material(s))
	_smooth_cache[mesh] = out
	return out
