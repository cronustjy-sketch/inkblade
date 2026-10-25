extends Node3D

# A side's base: a giant carved stone statue of a stickman warrior raising a blade, on a pedestal.
# Player = grey stone with gold accents; enemy = dark stone with red accents (flipped to face the player).
# It gets cracks as its HP drops (three stages) and crumbles into rubble when destroyed.

signal destroyed(team: int)

enum Team { PLAYER, ENEMY }

const STATUE_FILES: Dictionary = {
	Team.PLAYER: "res://sprites/prop_statue_gold.png",
	Team.ENEMY: "res://sprites/prop_statue_red.png",
}
const STATUE_WIDTH: float = 4.6 # meters; the height follows the picture's proportions
const CRACK_STAGES: Array[float] = [0.75, 0.5, 0.25] # a new crack set appears below each HP fraction
const CRACK_LINES: Array[int] = [5, 6, 8]
const CRACK_SCALE: float = 0.5 # crack textures are drawn at half resolution
const SLICES: int = 7
const PEDESTAL_SLICES: int = 2 # the bottom slices stay put when the statue crumbles

@export var team: Team = Team.PLAYER
@export var max_hp: float = 500.0

var hp: float = 500.0
var invulnerable: bool = false
var height: float = 7.0

var _statue: Sprite3D
var _cracks: Array[Sprite3D] = []
var _ward: MeshInstance3D
var _tex: Texture2D
var _pixel_size: float = 0.01
var _crumbled: bool = false

func _ready() -> void:
	hp = max_hp
	_tex = load(STATUE_FILES[team])
	_pixel_size = STATUE_WIDTH / float(_tex.get_width())
	height = _tex.get_height() * _pixel_size
	_statue = _make_sprite(_tex)
	add_child(_statue)
	var image: Image = _tex.get_image()
	for i in CRACK_STAGES.size():
		var crack: Sprite3D = _make_sprite(_crack_texture(image, CRACK_LINES[i], 1000 + i * 17 + int(team) * 101))
		crack.pixel_size = _pixel_size / CRACK_SCALE
		crack.position.z = 0.03
		crack.visible = false
		add_child(crack)
		_cracks.append(crack)

func is_castle() -> bool:
	return true

func take_damage(amount: float) -> void:
	if hp <= 0.0 or invulnerable:
		return
	hp = maxf(0.0, hp - amount)
	_show_damage()
	if hp <= 0.0:
		_crumble()
		destroyed.emit(team)

# ---------- damage and destruction ----------

func _show_damage() -> void:
	var frac: float = hp / max_hp
	for i in _cracks.size():
		_cracks[i].visible = frac < CRACK_STAGES[i]
	_chips(3)
	var tw: Tween = create_tween()
	tw.tween_property(_statue, "position:x", 0.06, 0.04)
	tw.tween_property(_statue, "position:x", -0.04, 0.05)
	tw.tween_property(_statue, "position:x", 0.0, 0.05)

# A few stone chips fall off the statue.
func _chips(count: int) -> void:
	for i in count:
		var chip := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var s: float = randf_range(0.1, 0.24)
		quad.size = Vector2(s, s)
		chip.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.62, 0.62, 0.66) if team == Team.PLAYER else Color(0.26, 0.27, 0.34)
		chip.material_override = mat
		add_child(chip)
		chip.position = Vector3(randf_range(-1.4, 1.4), randf_range(height * 0.35, height * 0.9), 0.1)
		var tw: Tween = chip.create_tween().set_parallel(true)
		tw.tween_property(chip, "position:y", 0.05, randf_range(0.5, 0.8)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(chip, "position:x", chip.position.x + randf_range(-0.8, 0.8), 0.7)
		tw.tween_property(chip, "rotation:z", randf_range(-6.0, 6.0), 0.7)
		tw.chain().tween_callback(chip.queue_free)

# The statue breaks into horizontal slabs that fall into a heap of rubble; the pedestal stays.
func _crumble() -> void:
	if _crumbled:
		return
	_crumbled = true
	_statue.visible = false
	for crack in _cracks:
		crack.visible = false
	if _ward != null:
		_ward.visible = false
	var tex_h: float = float(_tex.get_height())
	var slice_px: float = tex_h / SLICES
	var flip: bool = team == Team.ENEMY
	for i in SLICES:
		var piece := Sprite3D.new()
		piece.texture = _tex
		piece.region_enabled = true
		piece.region_rect = Rect2(0.0, slice_px * i, float(_tex.get_width()), slice_px)
		piece.pixel_size = _pixel_size
		piece.flip_h = flip
		piece.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		piece.shaded = false
		piece.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		piece.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var y: float = height - (i + 0.5) * slice_px * _pixel_size
		piece.position = Vector3(0.0, y, 0.0)
		add_child(piece)
		if i >= SLICES - PEDESTAL_SLICES:
			continue
		var rest_y: float = 0.35 + (SLICES - PEDESTAL_SLICES - 1 - i) * 0.12
		var drift: float = randf_range(-1.6, 1.6) * (1.0 - float(i) / SLICES)
		var delay: float = 0.06 * (SLICES - i)
		var tw: Tween = piece.create_tween().set_parallel(true)
		tw.tween_property(piece, "position:y", rest_y, 0.55 + 0.08 * (SLICES - i)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(delay)
		tw.tween_property(piece, "position:x", drift, 0.7).set_delay(delay)
		tw.tween_property(piece, "rotation:z", randf_range(-0.5, 0.5), 0.7).set_delay(delay)
		tw.tween_property(piece, "position:z", randf_range(0.2, 0.6), 0.7)
	_dust()

func _dust() -> void:
	for i in 9:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = randf_range(0.5, 0.9)
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 10
		sphere.rings = 5
		puff.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.85, 0.82, 0.76, 0.75)
		puff.material_override = mat
		add_child(puff)
		puff.position = Vector3(randf_range(-2.0, 2.0), randf_range(0.3, 2.2), 0.6)
		var tw: Tween = puff.create_tween().set_parallel(true)
		tw.tween_property(puff, "scale", Vector3.ONE * randf_range(2.0, 3.2), 1.1)
		tw.tween_property(puff, "position:y", puff.position.y + randf_range(1.0, 2.6), 1.1)
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.1).set_delay(0.2)
		tw.chain().tween_callback(puff.queue_free)

# While a level boss is alive the base can't be damaged; a translucent ward dome shows it.
func set_invulnerable(value: bool) -> void:
	invulnerable = value
	if value and _ward == null:
		_ward = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 4.6
		sphere.height = 9.2
		sphere.radial_segments = 16
		sphere.rings = 8
		_ward.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.48, 0.29, 0.84, 0.22)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ward.material_override = mat
		_ward.position.y = 3.2
		add_child(_ward)
	if _ward != null:
		_ward.visible = value and not _crumbled

# ---------- helpers ----------

func _make_sprite(tex: Texture2D) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.pixel_size = _pixel_size
	sprite.offset = Vector2(0.0, tex.get_height() * 0.5)
	sprite.flip_h = team == Team.ENEMY
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.5
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite

# Dark jagged cracks drawn only where the statue is solid. The same seed gives the same cracks every run.
func _crack_texture(statue: Image, lines: int, seed_value: int) -> ImageTexture:
	var w: int = int(statue.get_width() * CRACK_SCALE)
	var h: int = int(statue.get_height() * CRACK_SCALE)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ink := Color(0.06, 0.06, 0.08, 0.9)
	for n in lines:
		var p := Vector2.ZERO
		var found: bool = false
		for attempt in 40:
			p = Vector2(rng.randf_range(0.2, 0.8) * w, rng.randf_range(0.06, 0.72) * h)
			if statue.get_pixel(int(p.x / CRACK_SCALE), int(p.y / CRACK_SCALE)).a > 0.5:
				found = true
				break
		if not found:
			continue
		var angle: float = rng.randf_range(0.0, TAU)
		for step in rng.randi_range(12, 22):
			angle += rng.randf_range(-0.8, 0.8)
			var next: Vector2 = p + Vector2.from_angle(angle) * rng.randf_range(5.0, 9.0)
			_draw_line(img, statue, p, next, ink)
			if rng.randf() < 0.12:
				_draw_line(img, statue, next, next + Vector2.from_angle(angle + rng.randf_range(-1.2, 1.2)) * rng.randf_range(10.0, 22.0), ink)
			p = next
	return ImageTexture.create_from_image(img)

func _draw_line(img: Image, statue: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var steps: int = int(from.distance_to(to)) + 1
	for s in steps + 1:
		var q: Vector2 = from.lerp(to, float(s) / steps)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x: int = int(q.x) + dx
				var y: int = int(q.y) + dy
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				if statue.get_pixel(int(x / CRACK_SCALE), int(y / CRACK_SCALE)).a > 0.5:
					img.set_pixel(x, y, color)
