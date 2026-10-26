extends RefCounted

# 墨 ink effects for the 2D campaign: ink splashes on hits, brush-stroke slashes, ink bursts when units die and
# ground stains. All textures are painted procedurally once (no art files) and drawn as billboard sprites.

const INK := Color(0.05, 0.05, 0.07)
const SPLAT_SIZE: int = 128
const STROKE_W: int = 256
const STROKE_H: int = 128

static var _splat: Array[Texture2D] = []
static var _stroke: Texture2D

# ---------- textures ----------

static func _splat_textures() -> Array[Texture2D]:
	if _splat.is_empty():
		for variant in 4:
			_splat.append(_paint_splat(7000 + variant * 31))
	return _splat

# An irregular ink blot: a wobbly disc with spikes and a few detached droplets, with a thin light halo so it
# stays readable on top of black stickmen.
static func _paint_splat(seed_value: int) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mask := PackedFloat32Array()
	mask.resize(SPLAT_SIZE * SPLAT_SIZE)
	var c := Vector2(SPLAT_SIZE, SPLAT_SIZE) * 0.5
	var lobes: int = rng.randi_range(7, 11)
	var phase: float = rng.randf() * TAU
	var amps: Array[float] = []
	for i in lobes:
		amps.append(rng.randf_range(0.0, 0.42))
	var drops: Array[Vector3] = []
	for i in rng.randi_range(4, 7):
		var a: float = rng.randf() * TAU
		var d: float = rng.randf_range(0.62, 0.86)
		drops.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(0.04, 0.09)))
	for y in SPLAT_SIZE:
		for x in SPLAT_SIZE:
			var p := (Vector2(x, y) - c) / (SPLAT_SIZE * 0.5)
			var r: float = p.length()
			var a: float = atan2(p.y, p.x)
			var edge: float = 0.4
			for k in lobes:
				edge += amps[k] * 0.35 * maxf(0.0, cos((a - phase) * (k + 2) * 0.5 + k)) * (0.55 if k % 2 else 1.0)
			var alpha: float = 1.0 - smoothstep(edge - 0.035, edge + 0.01, r)
			for d: Vector3 in drops:
				alpha = maxf(alpha, 1.0 - smoothstep(d.z - 0.02, d.z + 0.01, p.distance_to(Vector2(d.x, d.y))))
			mask[y * SPLAT_SIZE + x] = alpha
	return _with_halo(mask, SPLAT_SIZE, SPLAT_SIZE, Color(1, 1, 1), 3, 0.0)

# Turns a coverage mask into ink pixels: black inside (optionally with a coloured core), light halo outside.
static func _with_halo(mask: PackedFloat32Array, w: int, h: int, halo: Color, halo_px: int, core_px: float) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var m: float = mask[y * w + x]
			if m > 0.5:
				var col := Color(INK.r, INK.g, INK.b, m)
				if core_px > 0.0:
					var deep: bool = true
					for oy in range(-int(core_px), int(core_px) + 1, 2):
						for ox in range(-int(core_px), int(core_px) + 1, 2):
							var qx: int = x + ox
							var qy: int = y + oy
							if qx < 0 or qy < 0 or qx >= w or qy >= h or mask[qy * w + qx] < 0.5:
								deep = false
					if deep:
						col = Color(1, 1, 1, 1)
				img.set_pixel(x, y, col)
			else:
				var near: bool = false
				for oy in range(-halo_px, halo_px + 1):
					for ox in range(-halo_px, halo_px + 1):
						var qx: int = x + ox
						var qy: int = y + oy
						if qx >= 0 and qy >= 0 and qx < w and qy < h and mask[qy * w + qx] > 0.5:
							near = true
				if near:
					img.set_pixel(x, y, Color(halo.r, halo.g, halo.b, 0.85))
	return ImageTexture.create_from_image(img)

# A tapered brush stroke sweeping left to right along an arc, with dry-brush streaks near the tail. The core is
# white (so it can be tinted gold / red) inside a black ink edge.
static func _stroke_texture() -> Texture2D:
	if _stroke != null:
		return _stroke
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var mask := PackedFloat32Array()
	mask.resize(STROKE_W * STROKE_H)
	var steps: int = 420
	for i in steps + 1:
		var u: float = float(i) / steps
		var x: float = 10.0 + u * (STROKE_W - 24.0)
		var y: float = STROKE_H * 0.62 - sin(PI * u) * STROKE_H * 0.42
		var thick: float = pow(sin(PI * clampf(u * 0.97 + 0.015, 0.0, 1.0)), 0.75) * 17.0 * (0.7 + 0.5 * u)
		var rr: int = int(ceil(thick))
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				if dx * dx + dy * dy > thick * thick:
					continue
				var px: int = int(x) + dx
				var py: int = int(y) + dy
				if px < 0 or py < 0 or px >= STROKE_W or py >= STROKE_H:
					continue
				var streak: float = 0.5 + 0.5 * sin((dy + rr) * 2.7 + rng.randf() * 0.4)
				if u > 0.55 and streak < (u - 0.55) * 1.6:
					continue
				mask[py * STROKE_W + px] = 1.0
	_stroke = _with_halo(mask, STROKE_W, STROKE_H, Color(1, 1, 1), 2, 4.0)
	return _stroke

# ---------- effects ----------

static func _sprite(parent: Node3D, tex: Texture2D, pos: Vector3, size_m: float, color: Color = Color.WHITE) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = size_m / float(tex.get_width())
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.double_sided = true
	s.modulate = color
	s.no_depth_test = false
	s.render_priority = 3
	parent.add_child(s)
	s.global_position = pos
	return s

# A quick ink blot popping out of a hit point.
static func hit_splash(parent: Node3D, pos: Vector3, size_m: float = 0.9, tint: Color = Color.WHITE) -> void:
	var tex: Texture2D = _splat_textures()[randi() % 4]
	var s: Sprite3D = _sprite(parent, tex, pos + Vector3(randf_range(-0.15, 0.15), randf_range(-0.1, 0.2), 0.35), size_m, tint)
	s.rotation.z = randf() * TAU
	s.scale = Vector3.ONE * 0.35
	var tw: Tween = s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 1.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.12)
	tw.chain().tween_callback(s.queue_free)

# A brush-stroke slash across the screen at `pos`, facing left or right.
static func slash(parent: Node3D, pos: Vector3, facing: float, size_m: float = 3.0, tilt_deg: float = -20.0, tint: Color = Color.WHITE) -> void:
	var s: Sprite3D = _sprite(parent, _stroke_texture(), pos + Vector3(facing * size_m * 0.3, 0.0, 0.5), size_m)
	s.flip_h = facing < 0.0
	s.rotation.z = deg_to_rad(tilt_deg) * facing
	s.scale = Vector3(0.3, 0.6, 1.0)
	s.modulate = Color(tint.r, tint.g, tint.b, 0.95)
	var tw: Tween = s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.22).set_delay(0.1)
	tw.chain().tween_callback(s.queue_free)

# A burst when a unit dies: a big blot, flying droplets, and a stain on the ground.
static func death_burst(parent: Node3D, pos: Vector3, scale_m: float = 1.0, tint: Color = Color.WHITE) -> void:
	var tex: Array[Texture2D] = _splat_textures()
	var big: Sprite3D = _sprite(parent, tex[randi() % 4], pos + Vector3(0, 0.9 * scale_m, 0.4), 2.1 * scale_m, tint)
	big.rotation.z = randf() * TAU
	big.scale = Vector3.ONE * 0.3
	var tb: Tween = big.create_tween().set_parallel(true)
	tb.tween_property(big, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tb.tween_property(big, "modulate:a", 0.0, 0.5).set_delay(0.18)
	tb.chain().tween_callback(big.queue_free)
	for i in 9:
		var drop: Sprite3D = _sprite(parent, tex[randi() % 4], pos + Vector3(0, 0.9 * scale_m, 0.4), randf_range(0.28, 0.55) * scale_m, tint)
		var vx: float = randf_range(-3.2, 3.2) * scale_m
		var vy: float = randf_range(2.0, 5.0) * scale_m
		var start: Vector3 = drop.global_position
		var tw: Tween = drop.create_tween().set_parallel(true)
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(drop):
				drop.global_position = start + Vector3(vx * t, vy * t - 6.0 * t * t, 0.0), 0.0, 0.6, 0.6)
		tw.tween_property(drop, "modulate:a", 0.0, 0.25).set_delay(0.35)
		tw.chain().tween_callback(drop.queue_free)
	stain(parent, pos, 1.3 * scale_m)

# A flat dark stain on the ground that fades slowly.
static func stain(parent: Node3D, pos: Vector3, size_m: float = 1.2) -> void:
	var tex: Texture2D = _splat_textures()[randi() % 4]
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = size_m / float(tex.get_width())
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.shaded = false
	s.double_sided = true
	s.rotation = Vector3(-PI * 0.5, 0.0, randf() * TAU)
	s.modulate = Color(1, 1, 1, 0.55)
	parent.add_child(s)
	s.global_position = Vector3(pos.x, 0.03, pos.z)
	s.scale = Vector3(1.0, 0.5, 1.0)
	var tw: Tween = s.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(s, "modulate:a", 0.0, 2.0)
	tw.tween_callback(s.queue_free)
