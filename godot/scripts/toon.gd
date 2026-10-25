extends RefCounted

# Toon (cel) shading with thick black outlines for the 3D raid mode, cheap enough for integrated GPUs:
# unshaded 3-band lighting from one fixed direction (no real lights or shadows) plus an inverted-hull outline pass.

const LIGHT_DIR := Vector3(0.45, 0.85, 0.35)
const INK := Color(0.04, 0.04, 0.07)

const TOON_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_tex = false;
uniform vec3 light_dir = vec3(0.45, 0.85, 0.35);
uniform float flash = 0.0;
uniform float brightness = 1.0;
uniform vec4 flash_color : source_color = vec4(1.0);
varying vec3 wnormal;
void vertex() {
	wnormal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
	vec4 c = albedo;
	if (use_tex) {
		c *= texture(albedo_tex, UV);
	}
	float nl = dot(normalize(wnormal), normalize(light_dir));
	float band = nl > 0.3 ? 1.0 : (nl > -0.25 ? 0.8 : 0.62);
	vec3 col = min(c.rgb * brightness, vec3(1.0)) * band;
	col = mix(col, flash_color.rgb, flash);
	ALBEDO = col;
}
"""

const OUTLINE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_front;
uniform float width = 0.03;
uniform vec4 color : source_color = vec4(0.04, 0.04, 0.07, 1.0);
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = color.rgb;
}
"""

static var _toon_shader: Shader
static var _outline_shader: Shader

static func _shaders() -> void:
	if _toon_shader == null:
		_toon_shader = Shader.new()
		_toon_shader.code = TOON_SHADER
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER

static func outline_material(width: float, color: Color = INK) -> ShaderMaterial:
	_shaders()
	var m := ShaderMaterial.new()
	m.shader = _outline_shader
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("color", color)
	return m

# A flat-colour toon material, optionally with an outline pass (width in the mesh's local units).
static func flat(color: Color, outline_width: float = 0.05) -> ShaderMaterial:
	_shaders()
	var m := ShaderMaterial.new()
	m.shader = _toon_shader
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("light_dir", LIGHT_DIR)
	if outline_width > 0.0:
		m.next_pass = outline_material(outline_width)
	return m

# Replaces every material under `root` with a toon version of itself (keeps the albedo texture / colour) plus an
# outline. world_scale is the node scale applied to the model, so the outline stays `outline_world` metres thick.
# Returns the toon materials so callers can flash them on hit.
static func apply_model(root: Node, world_scale: float, outline_world: float = 0.035, tint: Color = Color.WHITE, brightness: float = 1.0) -> Array[ShaderMaterial]:
	_shaders()
	var made: Array[ShaderMaterial] = []
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = mi as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for s in mesh_instance.mesh.get_surface_count():
			var src: Material = mesh_instance.get_active_material(s)
			var toon := ShaderMaterial.new()
			toon.shader = _toon_shader
			toon.set_shader_parameter("light_dir", LIGHT_DIR)
			toon.set_shader_parameter("brightness", brightness)
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
