extends RefCounted

# Procedural boss bodies for the 3D Boss Raid, built from primitives the way the web game builds its campaign bosses:
# five body types (blade, spirit, giant, brute, flyer) plus optional parts (horns, crown, halo, wings, plates, mask,
# hat, tail, brush, scarf2). build() returns a rig dictionary; animate() poses it every frame.

const Toon := preload("res://scripts/toon.gd")

const SCALE: Dictionary = {"giant": 2.3, "brute": 2.2, "blade": 1.7, "flyer": 1.8, "spirit": 1.7}

static func scale_for(body: String) -> float:
	return float(SCALE.get(body, 1.4))

# Height of the finished body in metres (used for the hit height and the HP bar anchor).
static func height_for(body: String) -> float:
	return scale_for(body) * (2.4 if body != "brute" else 2.2)

static func _mat(color: Color, outline: float = 0.05, glow: float = 0.0, dark_rim: bool = false) -> ShaderMaterial:
	var m: ShaderMaterial = Toon.flat(color, outline)
	if glow > 0.0:
		m.set_shader_parameter("emission", glow)
	if dark_rim:
		m.set_shader_parameter("rim", 1.0)
	return m

static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func _sphere(r: float, segs: int = 14) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(segs / 2, 4)
	return s

static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.01)
	c.radial_segments = 10
	c.rings = 4
	return c

static func _cone(r: float, h: float, segs: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c

static func _cyl(top: float, bottom: float, h: float, segs: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

# A limb: a pivot at the joint with a capsule hanging down from it.
static func _limb(parent: Node3D, pos: Vector3, r: float, length: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	_mesh(pivot, _capsule(r, length), mat, Vector3(0, -length * 0.5, 0))
	return pivot

# Builds the body. cfg needs "body" and "colors" (3 Colors); "parts" is optional. The returned dictionary holds the
# root node and the pieces animate() moves. The root's origin is at the feet.
static func build(cfg: Dictionary) -> Dictionary:
	var body: String = cfg.get("body", "blade")
	var colors: Array = cfg["colors"]
	var c0: Color = (colors[0] as Color).lerp(Color.WHITE, 0.1)
	var accent: Color = colors[1]
	var eye: Color = colors[2]
	var s: float = scale_for(body)
	var dark: bool = c0.get_luminance() < 0.2
	var root := Node3D.new()
	var rig: Dictionary = {"root": root, "body": body, "scale": s, "wings": [], "halos": [], "tail": [], "hover": 0.0}
	var main: ShaderMaterial = _mat(c0, 0.05, 0.12, dark)
	var accent_mat: ShaderMaterial = _mat(accent, 0.04, 0.35)
	var glow: ShaderMaterial = _mat(eye, 0.0, 1.0)
	var hip := Node3D.new() # everything above the legs hangs off the hip so the body can lean and bob
	rig["hip"] = hip
	root.add_child(hip)
	var torso := Node3D.new()
	rig["torso"] = torso
	hip.add_child(torso)
	var head := Node3D.new()
	rig["head"] = head
	torso.add_child(head)
	match body:
		"giant":
			hip.position = Vector3(0, 1.15 * s, 0)
			_mesh(torso, _sphere(0.62 * s), main, Vector3(0, 0.55 * s, 0), Vector3.ZERO, Vector3(1.05, 1.1, 1.25))
			_mesh(torso, _sphere(0.42 * s), main, Vector3(-0.18 * s, 0.95 * s, 0), Vector3.ZERO, Vector3(1.1, 0.9, 1.3))
			for side in [1.0, -1.0]:
				_mesh(torso, _sphere(0.3 * s), main, Vector3(0, 1.0 * s, side * 0.62 * s))
				for i in 2:
					_mesh(torso, _cone(0.08 * s, 0.5 * s, 5), accent_mat, Vector3(-0.1 * s - i * 0.14 * s, 1.3 * s + i * 0.05 * s, side * (0.55 + i * 0.1) * s), Vector3(side * 30.0, 0, 15.0))
			_mesh(torso, _sphere(0.13 * s, 8), glow, Vector3(0.6 * s, 0.7 * s, 0), Vector3.ZERO, Vector3(0.6, 1.4, 1.0))
			head.position = Vector3(0.2 * s, 1.35 * s, 0)
			_mesh(head, _sphere(0.28 * s), main)
			for side in [1.0, -1.0]:
				_mesh(head, _sphere(0.05 * s, 6), glow, Vector3(0.24 * s, 0.04 * s, side * 0.1 * s))
			rig["arm_l"] = _arm(torso, Vector3(0, 1.0 * s, 0.78 * s), 0.2 * s, 0.9 * s, 0.34 * s, main, accent_mat)
			rig["arm_r"] = _arm(torso, Vector3(0, 1.0 * s, -0.78 * s), 0.2 * s, 0.9 * s, 0.34 * s, main, accent_mat)
			rig["leg_l"] = _limb(hip, Vector3(0, 0, 0.34 * s), 0.24 * s, 1.15 * s, main)
			rig["leg_r"] = _limb(hip, Vector3(0, 0, -0.34 * s), 0.24 * s, 1.15 * s, main)
			rig["lean"] = -0.22
		"brute":
			hip.position = Vector3(0, 1.0 * s, 0)
			_mesh(torso, _sphere(0.55 * s), main, Vector3(0, 0.5 * s, 0), Vector3.ZERO, Vector3(1.0, 0.95, 1.2))
			_mesh(torso, _sphere(0.45 * s), main, Vector3(-0.28 * s, 0.85 * s, 0), Vector3.ZERO, Vector3(1.0, 0.85, 1.2))
			for i in 3:
				_mesh(torso, _box(0.08 * s, 0.16 * s, (0.6 - i * 0.12) * s), accent_mat, Vector3(-0.5 * s + i * 0.1 * s, 1.05 * s - i * 0.22 * s, 0), Vector3(0, 0, 25.0 + i * 12.0))
			head.position = Vector3(0.32 * s, 0.9 * s, 0)
			_mesh(head, _sphere(0.26 * s), main)
			_mesh(head, _sphere(0.1 * s, 8), glow, Vector3(0.22 * s, 0.03 * s, 0), Vector3.ZERO, Vector3(1.0, 1.3, 1.3))
			rig["arm_l"] = _arm(torso, Vector3(0, 0.95 * s, 0.7 * s), 0.17 * s, 0.85 * s, 0.3 * s, main, accent_mat)
			rig["arm_r"] = _arm(torso, Vector3(0, 0.95 * s, -0.7 * s), 0.17 * s, 0.85 * s, 0.3 * s, main, accent_mat)
			rig["leg_l"] = _limb(hip, Vector3(0, 0, 0.3 * s), 0.2 * s, 1.0 * s, main)
			rig["leg_r"] = _limb(hip, Vector3(0, 0, -0.3 * s), 0.2 * s, 1.0 * s, main)
			rig["lean"] = -0.3
		"spirit":
			hip.position = Vector3(0, 0.15 * s, 0)
			var robe: ShaderMaterial = _mat(c0, 0.05, 0.2, dark)
			_mesh(torso, _cyl(0.2 * s, 0.62 * s, 1.5 * s), robe, Vector3(0, 0.75 * s, 0))
			_mesh(torso, _cyl(0.64 * s, 0.64 * s, 0.1 * s), accent_mat, Vector3(0, 0.08 * s, 0))
			head.position = Vector3(0, 1.75 * s, 0)
			_mesh(head, _sphere(0.24 * s), main)
			for side in [1.0, -1.0]:
				_mesh(head, _sphere(0.045 * s, 6), glow, Vector3(0.2 * s, 0.03 * s, side * 0.09 * s))
			rig["arm_l"] = _limb(torso, Vector3(0, 1.4 * s, 0.4 * s), 0.1 * s, 0.9 * s, main)
			rig["arm_r"] = _limb(torso, Vector3(0, 1.4 * s, -0.4 * s), 0.1 * s, 0.9 * s, main)
			rig["hover"] = 0.6 * s * 0.5
			rig["lean"] = 0.0
		"flyer":
			hip.position = Vector3(0, 0.9 * s, 0)
			_mesh(torso, _sphere(0.5 * s), main, Vector3(0, 0.4 * s, 0), Vector3.ZERO, Vector3(1.0, 0.95, 1.25))
			head.position = Vector3(0.45 * s, 0.85 * s, 0)
			_mesh(head, _sphere(0.26 * s), main)
			_mesh(head, _cone(0.1 * s, 0.34 * s, 6), accent_mat, Vector3(0.3 * s, -0.04 * s, 0), Vector3(0, 0, -90.0))
			for side in [1.0, -1.0]:
				_mesh(head, _sphere(0.05 * s, 6), glow, Vector3(0.14 * s, 0.1 * s, side * 0.12 * s))
			rig["arm_l"] = _limb(torso, Vector3(0.1 * s, 0.7 * s, 0.5 * s), 0.1 * s, 0.8 * s, main)
			rig["arm_r"] = _limb(torso, Vector3(0.1 * s, 0.7 * s, -0.5 * s), 0.1 * s, 0.8 * s, main)
			rig["leg_l"] = _limb(hip, Vector3(0, 0, 0.22 * s), 0.1 * s, 0.9 * s, main)
			rig["leg_r"] = _limb(hip, Vector3(0, 0, -0.22 * s), 0.1 * s, 0.9 * s, main)
			rig["hover"] = 0.5 * s
			rig["lean"] = -0.12
		_: # blade: a slim swordsman with a long scarf
			hip.position = Vector3(0, 1.0 * s, 0)
			_mesh(torso, _capsule(0.24 * s, 0.9 * s), main, Vector3(0, 0.45 * s, 0))
			_mesh(torso, _box(0.5 * s, 0.1 * s, 0.1 * s), accent_mat, Vector3(0, 0.12 * s, 0))
			head.position = Vector3(0, 1.1 * s, 0)
			_mesh(head, _sphere(0.2 * s), main)
			for side in [1.0, -1.0]:
				_mesh(head, _sphere(0.04 * s, 6), glow, Vector3(0.17 * s, 0.03 * s, side * 0.07 * s))
			var scarf := _mesh(torso, _box(0.9 * s, 0.14 * s, 0.22 * s), accent_mat, Vector3(-0.55 * s, 0.9 * s, 0), Vector3(0, 0, -12.0))
			(rig["tail"] as Array).append(scarf)
			rig["arm_l"] = _limb(torso, Vector3(0, 0.82 * s, 0.34 * s), 0.1 * s, 0.85 * s, main)
			var sword_arm: Node3D = _limb(torso, Vector3(0, 0.82 * s, -0.34 * s), 0.1 * s, 0.85 * s, main)
			rig["arm_r"] = sword_arm
			_mesh(sword_arm, _box(0.07 * s, 1.5 * s, 0.14 * s), glow, Vector3(0.12 * s, -0.95 * s, 0), Vector3(-8.0, 0, 0))
			_mesh(sword_arm, _box(0.07 * s, 0.1 * s, 0.4 * s), accent_mat, Vector3(0.12 * s, -0.78 * s, 0))
			rig["leg_l"] = _limb(hip, Vector3(0, 0, 0.16 * s), 0.11 * s, 1.0 * s, main)
			rig["leg_r"] = _limb(hip, Vector3(0, 0, -0.16 * s), 0.11 * s, 1.0 * s, main)
			rig["lean"] = -0.08
	_add_parts(rig, cfg.get("parts", []), main, accent_mat, c0, accent)
	rig["height"] = height_for(body)
	return rig

# A big arm: upper arm pivot at the shoulder with a forearm and a fist hanging from it.
static func _arm(parent: Node3D, pos: Vector3, r: float, length: float, fist: float, mat: Material, accent: Material) -> Node3D:
	var pivot := _limb(parent, pos, r, length * 0.9, mat)
	_mesh(pivot, _sphere(fist, 10), mat, Vector3(0, -length * 0.95, 0), Vector3.ZERO, Vector3(1.05, 0.95, 1.05))
	for k in 3:
		_mesh(pivot, _sphere(fist * 0.18, 5), accent, Vector3(fist * 0.8, -length * 0.95, (k - 1) * fist * 0.5))
	return pivot

static func _add_parts(rig: Dictionary, parts: Array, main: Material, accent_mat: Material, c0: Color, accent: Color) -> void:
	var s: float = rig["scale"]
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	var hip: Node3D = rig["hip"]
	var gold: ShaderMaterial = _mat(Color("e8c060"), 0.04, 0.4)
	for p: String in parts:
		match p:
			"horns":
				for side in [1.0, -1.0]:
					_mesh(head, _cone(0.08 * s, 0.45 * s, 6), accent_mat, Vector3(-0.02 * s, 0.3 * s, side * 0.18 * s), Vector3(side * -28.0, 0, 12.0))
			"crown":
				_mesh(head, _cyl(0.24 * s, 0.26 * s, 0.12 * s, 10), gold, Vector3(0, 0.27 * s, 0))
				for i in 5:
					var a: float = float(i) / 5.0 * TAU
					_mesh(head, _cone(0.05 * s, 0.18 * s, 4), gold, Vector3(cos(a) * 0.24 * s, 0.4 * s, sin(a) * 0.24 * s))
			"halo", "halo2":
				var big: bool = p == "halo2"
				var tor := TorusMesh.new()
				tor.inner_radius = (0.7 if big else 0.42) * s - 0.03 * s
				tor.outer_radius = (0.7 if big else 0.42) * s + 0.03 * s
				tor.rings = 24
				tor.ring_segments = 6
				var ring := _mesh(head, tor, _mat(Color("fff2c0") if not big else accent, 0.0, 1.0), Vector3(-0.2 * s, 0.0 if big else 0.45 * s, 0))
				(rig["halos"] as Array).append(ring)
			"wings":
				for side in [1.0, -1.0]:
					var pivot := Node3D.new()
					pivot.position = Vector3(-0.15 * s, 0.7 * s, side * 0.3 * s)
					torso.add_child(pivot)
					var plane := _mesh(pivot, _box(0.05, 0.9 * s, 1.5 * s), _mat(accent, 0.03, 0.5), Vector3(0, 0.25 * s, side * 0.75 * s), Vector3(side * 12.0, 0, 0))
					plane.set_meta("side", side)
					(rig["wings"] as Array).append(pivot)
			"plates":
				for side in [1.0, -1.0]:
					_mesh(torso, _box(0.32 * s, 0.14 * s, 0.34 * s), accent_mat, Vector3(0, 0.85 * s, side * 0.4 * s), Vector3(side * 17.0, 0, 0))
			"mask":
				_mesh(head, _box(0.06 * s, 0.34 * s, 0.36 * s), _mat(Color("f2eee4"), 0.03), Vector3(0.2 * s, 0.0, 0))
			"hat":
				_mesh(head, _cone(0.55 * s, 0.25 * s, 14), accent_mat, Vector3(0, 0.3 * s, 0))
			"tail":
				var parent: Node3D = hip
				for i in 4:
					var seg := Node3D.new()
					seg.position = Vector3(-0.3 * s if i == 0 else -0.42 * s, 0.0, 0)
					parent.add_child(seg)
					_mesh(seg, _cone((0.12 - 0.02 * i) * s, 0.45 * s, 6), accent_mat if i % 2 == 1 else main, Vector3(-0.2 * s, 0, 0), Vector3(0, 0, 90.0))
					(rig["tail"] as Array).append(seg)
					parent = seg
			"brush":
				var arm: Node3D = rig.get("arm_l") as Node3D
				if arm != null:
					_mesh(arm, _cyl(0.04 * s, 0.05 * s, 1.1 * s, 8), _mat(Color("5a2a10"), 0.03), Vector3(0, -0.85 * s, 0))
					_mesh(arm, _cone(0.13 * s, 0.4 * s, 10), _mat(Color("0b0b10"), 0.03), Vector3(0, -1.55 * s, 0), Vector3(180.0, 0, 0))
			"scarf2":
				_mesh(torso, _box(0.5 * s, 0.1 * s, 0.5 * s), accent_mat, Vector3(0, 0.95 * s, 0))

# Poses the rig. walk: 0..1 amount of walking, attack: 0..1 arm-raise amount, t: running clock.
static func animate(rig: Dictionary, t: float, walk: float, attack: float, gait: float = 6.0) -> void:
	var body: String = rig["body"]
	var s: float = rig["scale"]
	var root: Node3D = rig["root"]
	var hover: float = rig["hover"]
	var hip: Node3D = rig["hip"]
	var base_y: float = hip.get_meta("base_y") if hip.has_meta("base_y") else hip.position.y
	hip.set_meta("base_y", base_y)
	var bob: float = sin(t * 2.2) * 0.04 * s + absf(sin(t * gait)) * 0.05 * s * walk
	root.position.y = hover + (sin(t * 2.2) * 0.25 if hover > 0.0 else 0.0)
	hip.position.y = base_y + bob
	var lean: float = float(rig.get("lean", 0.0))
	(rig["torso"] as Node3D).rotation.z = lean * (1.0 - attack * 0.5) - attack * 0.35
	var swing: float = sin(t * gait) * 0.7 * walk
	for key: String in ["leg_l", "leg_r"]:
		var leg: Node3D = rig.get(key) as Node3D
		if leg != null:
			leg.rotation.z = swing * (1.0 if key == "leg_l" else -1.0)
	var raise: float = 2.4 * attack
	for key: String in ["arm_l", "arm_r"]:
		var arm: Node3D = rig.get(key) as Node3D
		if arm != null:
			var sign: float = 1.0 if key == "arm_l" else -1.0
			var rest: float = -swing * sign * 0.8
			if body == "spirit":
				rest = 0.35 * sign + sin(t * 2.0 + sign) * 0.1
			arm.rotation.z = lerpf(rest, raise, attack)
	var wings: Array = rig["wings"]
	for i in wings.size():
		var w: Node3D = wings[i]
		var side: float = 1.0 if i == 0 else -1.0
		w.rotation.x = side * (0.3 + sin(t * (9.0 if body == "flyer" else 4.0)) * 0.45)
	var halos: Array = rig["halos"]
	for i in halos.size():
		(halos[i] as Node3D).rotation.y += 0.03 * (1.0 if i == 0 else -1.0)
	var tail: Array = rig["tail"]
	for i in tail.size():
		var seg: Node3D = tail[i]
		if body == "blade":
			seg.rotation.z = -0.2 + sin(t * 3.0) * 0.12
		else:
			seg.rotation.y = sin(t * 3.0 + i) * 0.3
