extends Node3D

# Round boss arena (about 60 m wide): carved stone floor, tall walls with banners and fire braziers, pillars around
# the edge, rocks and grass, hills and far mountains. Toon materials with outlines (scripts/toon.gd), no real
# lights. Walls and pillars fade out when they block the camera (see raid_camera.gd and `fade_items`).

const Toon := preload("res://scripts/toon.gd")
const RADIUS: float = 30.0
const LIMIT: float = 28.4 # actors are kept inside this radius
const WALL_SEGMENTS: int = 30
const WALL_HEIGHT: float = 4.6
const PILLAR_COUNT: int = 8
const PILLAR_RING: float = 26.0
const PILLAR_RADIUS: float = 1.25

# World-space stone floor: brick tiles, carved rings and spokes in the middle, grass creeping in at the rim.
const FLOOR_SHADER: String = """
shader_type spatial;
render_mode unshaded;
varying vec2 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 p = wp;
	float r = length(p);
	// Offset brick rows.
	vec2 q = p / 3.2;
	float row = floor(q.y);
	q.x += 0.5 * mod(row, 2.0);
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float seam = 1.0 - smoothstep(0.0, 0.045, edge);
	float tone = hash(cell) * 0.55 + noise(p * 0.7) * 0.45;
	vec3 stone = mix(vec3(0.60, 0.58, 0.55), vec3(0.80, 0.77, 0.70), tone);
	stone = mix(stone, vec3(0.30, 0.29, 0.30), seam);
	// Carved pattern: ring grooves, eight spokes and a gold centre.
	float groove = 0.0;
	float gold = 0.0;
	for (int i = 0; i < 3; i++) {
		float rr = 3.4 + float(i) * 3.3;
		groove = max(groove, 1.0 - smoothstep(0.05, 0.22, abs(r - rr)));
	}
	float outer = 1.0 - smoothstep(0.05, 0.3, abs(r - 10.6));
	groove = max(groove, outer);
	gold = max(gold, 1.0 - smoothstep(0.0, 0.12, abs(r - 10.6)));
	float a = atan(p.y, p.x);
	float to_spoke = abs(fract(a / (TAU / 8.0) + 0.5) - 0.5) * r * (TAU / 8.0);
	float spoke = (1.0 - smoothstep(0.04, 0.2, to_spoke)) * step(0.8, r) * (1.0 - step(10.4, r));
	groove = max(groove, spoke);
	gold = max(gold, spoke * 0.7);
	gold = max(gold, 1.0 - smoothstep(0.8, 1.1, r));
	stone = mix(stone, vec3(0.22, 0.21, 0.24), groove * 0.85);
	stone = mix(stone, vec3(0.97, 0.74, 0.20), clamp(gold, 0.0, 1.0));
	// Grass at the rim.
	float g = smoothstep(23.0, 27.5, r + noise(p * 0.5) * 3.5);
	vec3 grass = mix(vec3(0.40, 0.74, 0.30), vec3(0.50, 0.82, 0.36), noise(p * 1.3));
	vec3 col = mix(stone, grass, g);
	// A touch of darkening at the wall foot.
	col *= 1.0 - smoothstep(28.0, 30.0, r) * 0.35;
	ALBEDO = col;
}
"""

var pillars: Array[Vector3] = []
# Things that fade out when between the camera and the hero: {mats: Array[ShaderMaterial], pos: Vector3, radius: float, alpha: float}
var fade_items: Array[Dictionary] = []
var _flames: Array[Node3D] = []
var _clock: float = 0.0

func build() -> void:
	_floor()
	_walls()
	_pillars()
	_edge_dressing()
	_hills()
	_mountains()

func _process(delta: float) -> void:
	_clock += delta
	for i in _flames.size():
		var f: Node3D = _flames[i]
		var flick: float = 1.0 + 0.18 * sin(_clock * 11.0 + i * 1.7) + 0.1 * sin(_clock * 17.0 + i)
		f.scale = Vector3(1.0 / flick * 0.9 + 0.1, flick, 1.0 / flick * 0.9 + 0.1)

func _mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _floor() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.4
	disc.radial_segments = 64
	var shader := Shader.new()
	shader.code = FLOOR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_mesh(self, disc, mat, Vector3(0, -0.2, 0))
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS + 2.0
	cyl.height = 0.4
	ground_shape.shape = cyl
	ground.add_child(ground_shape)
	ground.position = Vector3(0, -0.2, 0)
	add_child(ground)
	# Rim stones around the floor edge.
	var rim := TorusMesh.new()
	rim.inner_radius = RADIUS - 0.2
	rim.outer_radius = RADIUS + 0.9
	rim.rings = 64
	rim.ring_segments = 6
	var rim_mesh := _mesh(self, rim, Toon.flat(Color("a39a8a"), 0.06), Vector3(0, 0.0, 0))
	rim_mesh.scale = Vector3(1, 0.5, 1)

func _walls() -> void:
	var chord: float = 2.0 * RADIUS * sin(PI / WALL_SEGMENTS)
	var box := BoxMesh.new()
	box.size = Vector3(chord + 0.25, WALL_HEIGHT, 1.4)
	var cap := BoxMesh.new()
	cap.size = Vector3(chord + 0.5, 0.45, 1.9)
	var trim := BoxMesh.new()
	trim.size = Vector3(chord + 0.3, 0.3, 1.55)
	var banner_colors: Array[Color] = [Color("f2b632"), Color("e0463b"), Color("2f6fd8")]
	for i in WALL_SEGMENTS:
		var a: float = TAU * i / WALL_SEGMENTS
		var pos := Vector3(cos(a) * RADIUS, WALL_HEIGHT * 0.5, sin(a) * RADIUS)
		var rot := Vector3(0, -a + PI * 0.5, 0)
		var wall_mat: ShaderMaterial = Toon.flat(Color("d9d0b8") if i % 2 == 0 else Color("cfc5ab"), 0.09, true)
		var wall := _mesh(self, box, wall_mat, pos, rot)
		var cap_mat: ShaderMaterial = Toon.flat(Color("b9ad92"), 0.08, true)
		var cap_mesh := _mesh(self, cap, cap_mat, pos + Vector3(0, WALL_HEIGHT * 0.5 + 0.2, 0), rot)
		var gold_mat: ShaderMaterial = Toon.flat(Color("f2b632"), 0.05, true)
		var gold_trim := _mesh(self, trim, gold_mat, pos + Vector3(0, WALL_HEIGHT * 0.5 - 1.2, 0), rot)
		fade_items.append({"mats": [wall_mat, cap_mat, gold_mat], "pos": pos + Vector3(0, 0.5, 0), "radius": 3.2, "alpha": 1.0})
		if wall == null or cap_mesh == null or gold_trim == null:
			continue
		var inward := Vector3(-cos(a), 0.0, -sin(a))
		if i % 3 == 0:
			_banner(pos + inward * 0.85 + Vector3(0, 0.1, 0), rot, banner_colors[floori(i / 3.0) % banner_colors.size()])
		elif i % 3 == 1:
			_brazier(Vector3(cos(a) * (RADIUS - 0.2), WALL_HEIGHT + 0.45, sin(a) * (RADIUS - 0.2)))

func _banner(pos: Vector3, rot: Vector3, color: Color) -> void:
	var cloth := BoxMesh.new()
	cloth.size = Vector3(1.9, 3.3, 0.1)
	_mesh(self, cloth, Toon.flat(color, 0.05), pos, rot)
	var bar := BoxMesh.new()
	bar.size = Vector3(2.3, 0.18, 0.2)
	_mesh(self, bar, Toon.flat(Color("3a2a1a"), 0.04), pos + Vector3(0, 1.75, 0), rot)
	var emblem := CylinderMesh.new()
	emblem.top_radius = 0.42
	emblem.bottom_radius = 0.42
	emblem.height = 0.06
	emblem.radial_segments = 14
	var e := _mesh(self, emblem, Toon.flat(Color("fff3d1"), 0.04), pos + Vector3(0, 0.4, 0) + Vector3(0, 0, 0), rot + Vector3(PI * 0.5, 0, 0))
	e.translate_object_local(Vector3(0, 0.06, 0))

func _brazier(pos: Vector3) -> void:
	var stand := CylinderMesh.new()
	stand.top_radius = 0.28
	stand.bottom_radius = 0.4
	stand.height = 0.7
	stand.radial_segments = 10
	_mesh(self, stand, Toon.flat(Color("3a3340"), 0.05), pos)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.75
	bowl.bottom_radius = 0.38
	bowl.height = 0.5
	bowl.radial_segments = 12
	_mesh(self, bowl, Toon.flat(Color("2a2430"), 0.06), pos + Vector3(0, 0.55, 0))
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 0.8, 0)
	add_child(holder)
	var outer := CylinderMesh.new()
	outer.top_radius = 0.0
	outer.bottom_radius = 0.55
	outer.height = 1.5
	outer.radial_segments = 8
	var outer_mi := _mesh(holder, outer, _fire_material(Color(1.0, 0.42, 0.08, 0.95)), Vector3(0, 0.75, 0))
	var inner := CylinderMesh.new()
	inner.top_radius = 0.0
	inner.bottom_radius = 0.32
	inner.height = 1.0
	inner.radial_segments = 8
	var inner_mi := _mesh(holder, inner, _fire_material(Color(1.0, 0.9, 0.35, 1.0)), Vector3(0, 0.5, 0))
	if outer_mi != null and inner_mi != null:
		_flames.append(holder)

func _fire_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	return mat

func _pillars() -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = PILLAR_RADIUS * 0.9
	shaft.bottom_radius = PILLAR_RADIUS
	shaft.height = 7.0
	shaft.radial_segments = 16
	var cap := BoxMesh.new()
	cap.size = Vector3(3.2, 0.6, 3.2)
	for i in PILLAR_COUNT:
		var a: float = TAU * (i + 0.5) / PILLAR_COUNT
		var p := Vector3(cos(a) * PILLAR_RING, 0.0, sin(a) * PILLAR_RING)
		pillars.append(p)
		var shaft_mat: ShaderMaterial = Toon.flat(Color("efd9a4"), 0.07, true)
		var cap_mat: ShaderMaterial = Toon.flat(Color("f2b632"), 0.06, true)
		_mesh(self, shaft, shaft_mat, p + Vector3(0, 3.5, 0))
		_mesh(self, cap, cap_mat, p + Vector3(0, 7.2, 0))
		_mesh(self, cap, cap_mat, p + Vector3(0, 0.3, 0)).scale = Vector3(0.9, 1.0, 0.9)
		fade_items.append({"mats": [shaft_mat, cap_mat], "pos": p + Vector3(0, 3.0, 0), "radius": 2.6, "alpha": 1.0})
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = PILLAR_RADIUS
		shape.height = 7.0
		col.shape = shape
		body.add_child(col)
		body.position = p + Vector3(0, 3.5, 0)
		add_child(body)

# Rocks and grass tufts along the inner edge of the arena.
func _edge_dressing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var rock_colors: Array[Color] = [Color("9a948a"), Color("b0a999"), Color("847e76")]
	for i in 16:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(23.5, 28.3)
		var size: float = rng.randf_range(0.5, 1.2)
		var sphere := SphereMesh.new()
		sphere.radius = size
		sphere.height = size * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		var rock := _mesh(self, sphere, Toon.flat(rock_colors[i % 3], 0.07), Vector3(cos(a) * r, size * 0.35, sin(a) * r))
		rock.scale = Vector3(1.3, 0.75, 1.0)
		rock.rotation.y = rng.randf() * TAU
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.09
	blade.height = 0.75
	blade.radial_segments = 4
	blade.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	var tufts: int = 70
	mm.instance_count = tufts * 3
	for t in tufts:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(21.0, 28.8)
		var base := Vector3(cos(a) * r, 0.3, sin(a) * r)
		for b in 3:
			var tilt: float = (b - 1) * 0.4 + rng.randf_range(-0.15, 0.15)
			var blade_basis := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, tilt))
			mm.set_instance_transform(t * 3 + b, Transform3D(blade_basis, base + Vector3((b - 1) * 0.12, 0, rng.randf_range(-0.1, 0.1))))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var grass := StandardMaterial3D.new()
	grass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grass.albedo_color = Color("2f8f3a")
	grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = grass
	add_child(mmi)

func _hills() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	var colors: Array[Color] = [Color("5fb85a"), Color("7fcf6a"), Color("4aa352")]
	for i in 18:
		var a: float = TAU * i / 18.0 + rng.randf_range(-0.1, 0.1)
		var r: float = rng.randf_range(52.0, 66.0)
		var size: float = rng.randf_range(10.0, 20.0)
		var sphere := SphereMesh.new()
		sphere.radius = size
		sphere.height = size * 2.0
		sphere.radial_segments = 20
		sphere.rings = 10
		var hill := _mesh(self, sphere, Toon.flat(colors[i % colors.size()], 0.25), Vector3(cos(a) * r, -size * 0.45, sin(a) * r))
		hill.scale = Vector3(1.6, 0.8, 1.2)

# Big blue-grey mountains with snow caps far behind the hills.
func _mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var tones: Array[Color] = [Color("7d93b8"), Color("8aa0c4"), Color("6f86ad")]
	for i in 16:
		var a: float = TAU * i / 16.0 + rng.randf_range(-0.12, 0.12)
		var r: float = rng.randf_range(115.0, 165.0)
		var height: float = rng.randf_range(45.0, 85.0)
		var base: float = height * rng.randf_range(0.7, 1.0)
		var peak := CylinderMesh.new()
		peak.top_radius = 0.0
		peak.bottom_radius = base
		peak.height = height
		peak.radial_segments = 6
		peak.rings = 1
		var pos := Vector3(cos(a) * r, height * 0.5 - 4.0, sin(a) * r)
		_mesh(self, peak, Toon.flat(tones[i % 3], 0.9), pos)
		var snow := CylinderMesh.new()
		snow.top_radius = 0.0
		snow.bottom_radius = base * 0.34
		snow.height = height * 0.34
		snow.radial_segments = 6
		snow.rings = 1
		_mesh(self, snow, Toon.flat(Color("f4f8ff"), 0.0), pos + Vector3(0, height * 0.33, 0))

# Keeps a position inside the arena.
static func clamp_inside(pos: Vector3, limit: float = LIMIT) -> Vector3:
	var flat := Vector2(pos.x, pos.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
	return Vector3(flat.x, pos.y, flat.y)
