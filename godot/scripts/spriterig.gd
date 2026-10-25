extends Node3D

# Billboard sprite visual for a unit, drawn from the baked ink sprite sheets (sprites/<key>_gold|red.png).
# Same interface as stickman.gd: set_moving(), play_attack(), set_facing(), flash(), `height`.
# Sheet layout: 4 columns x 2 rows; top row = walk cycle, bottom row = attack. Sprites are drawn facing right.

const UnitData := preload("res://data/units.gd")
const SpriteMeta := preload("res://data/sprite_meta.gd")

const FRAMES: int = 6 # walk frames and attack frames per sheet (cells 0-5 walk, 6-11 attack)
const FEET_MARGIN_PX: float = 8.0 # keep in sync with MARGIN in tools/bake_sprites.gd
const FLASH_TIME: float = 0.12

static var _shadow_mesh: CylinderMesh
static var _shadow_mat: StandardMaterial3D

var height: float = 2.0
var gait: float = 4.0

var _sprite: Sprite3D
var _moving: bool = false
var _phase: float = 0.0
var _attack_t: float = -1.0
var _attack_dur: float = 0.35
var _face: float = 1.0
var _flash_t: float = 0.0

static func has_sprite(key: String) -> bool:
	return SpriteMeta.META.has(key)

func setup(key: String, team: int, speed_mps: float, height_m: float = -1.0, variant: String = "") -> void:
	var meta: Dictionary = SpriteMeta.META[key]
	height = height_m if height_m > 0.0 else UnitData.UNITS[key]["sprite_h"]
	gait = 4.2 * speed_mps if speed_mps > 0.0 else 4.0
	var colour: String = variant if variant != "" else ("gold" if team == 0 else "red")
	var tex: Texture2D = load("res://sprites/%s_%s.png" % [key, colour])

	_sprite = Sprite3D.new()
	_sprite.texture = tex
	_sprite.hframes = int(meta.get("cols", 6))
	_sprite.vframes = int(meta.get("rows", 2))
	_sprite.pixel_size = height / float(meta["px_h"])
	_sprite.offset = Vector2(0.0, meta["cell_h"] * 0.5 - FEET_MARGIN_PX)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.alpha_scissor_threshold = 0.5
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)

	var shadow := MeshInstance3D.new()
	shadow.mesh = _get_shadow_mesh()
	shadow.material_override = _get_shadow_mat()
	var w: float = height * 0.55
	shadow.scale = Vector3(w, 1.0, w * 0.4)
	shadow.position.y = 0.02
	add_child(shadow)

	set_facing(team == 0)

func set_facing(right: bool) -> void:
	_face = 1.0 if right else -1.0
	_sprite.flip_h = not right

func set_moving(value: bool) -> void:
	_moving = value

func play_attack(duration: float) -> void:
	_attack_dur = clampf(duration * 0.6, 0.25, 0.8)
	_attack_t = 0.0

# Brief red tint when the unit is hit.
func flash() -> void:
	_flash_t = FLASH_TIME

func _process(delta: float) -> void:
	if _moving:
		_phase += delta * gait
	var frame: int
	if _attack_t >= 0.0:
		_attack_t += delta
		if _attack_t >= _attack_dur:
			_attack_t = -1.0
	if _attack_t >= 0.0:
		var u: float = clampf(_attack_t / _attack_dur, 0.0, 0.999)
		frame = FRAMES + int(u * FRAMES)
		_sprite.position.x = sin(u * PI) * 0.18 * _face
	else:
		frame = int(floor(_phase / (TAU / FRAMES))) % FRAMES if _moving else 0
		_sprite.position.x = 0.0
	_sprite.frame = frame
	if _flash_t > 0.0:
		_flash_t -= delta
		_sprite.modulate = Color(1.0, 0.55, 0.55)
	else:
		_sprite.modulate = Color.WHITE

static func _get_shadow_mesh() -> CylinderMesh:
	if _shadow_mesh == null:
		_shadow_mesh = CylinderMesh.new()
		_shadow_mesh.top_radius = 0.5
		_shadow_mesh.bottom_radius = 0.5
		_shadow_mesh.height = 0.02
		_shadow_mesh.radial_segments = 14
		_shadow_mesh.rings = 1
	return _shadow_mesh

static func _get_shadow_mat() -> StandardMaterial3D:
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.albedo_color = Color(0.05, 0.05, 0.07, 0.28)
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _shadow_mat
