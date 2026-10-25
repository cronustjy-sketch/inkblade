extends Node3D

signal destroyed(team: int)

enum Team { PLAYER, ENEMY }

const Ink := preload("res://scripts/ink.gd")
const BAR_WIDTH: float = 5.0
const COLOR_PLAYER := Color("e8b44a")
const COLOR_ENEMY := Color("de4b3f")
const PARCHMENT := Color("efe6cf")
const DOOR := Color("2b2118")
const SPRITE_WIDTH: float = 8.6 # width of the Codex castle illustration in meters
const SPRITE_HEIGHT: float = 5.3 # 8.6 m wide x 944/1526 aspect

@export var team: Team = Team.PLAYER
@export var max_hp: float = 500.0

var hp: float = 500.0
var _fill: MeshInstance3D
var invulnerable: bool = false
var _ward: MeshInstance3D

func _ready() -> void:
	hp = max_hp
	var color: Color = COLOR_PLAYER if team == Team.PLAYER else COLOR_ENEMY
	var toward_enemy: float = 1.0 if team == Team.PLAYER else -1.0
	var sprite_path: String = "res://sprites/prop_castle_%s.png" % ("gold" if team == Team.PLAYER else "red")
	var has_sprite: bool = ResourceLoader.exists(sprite_path)
	if has_sprite:
		_build_sprite(sprite_path)
	else:
		_build_castle(color, toward_enemy)

	var bar_root := Node3D.new()
	bar_root.position = Vector3(0, SPRITE_HEIGHT + 0.6 if has_sprite else 11.0, 0)
	add_child(bar_root)
	# The HUD shows castle HP at the top of the screen; the floating bar is only for the primitive fallback castle.
	bar_root.visible = not has_sprite
	bar_root.add_child(_bar_quad(Vector2(BAR_WIDTH + 0.2, 0.7), Ink.INK, 0.0))
	bar_root.add_child(_bar_quad(Vector2(BAR_WIDTH, 0.5), Color("3a3f48"), 0.01))
	_fill = _bar_quad(Vector2(BAR_WIDTH, 0.5), color, 0.02)
	bar_root.add_child(_fill)

	var label := Label3D.new()
	label.text = "我方城堡\nYour Castle" if team == Team.PLAYER else "敌方城堡\nEnemy Castle"
	label.position = Vector3(0, 1.1, 0)
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	bar_root.add_child(label)

# About 6.4 m wide (x) and 6 m deep (z); the front faces the camera at +z.
func _build_castle(color: Color, toward_enemy: float) -> void:
	# Main wall.
	Ink.box(self, Vector3(4.4, 5.0, 6.0), Vector3(0, 2.5, 0), PARCHMENT)
	# Crenellations along the front and back edges.
	for i in 5:
		var x: float = -1.8 + 0.9 * i
		for z: float in [2.7, -2.7]:
			Ink.box(self, Vector3(0.55, 0.6, 0.55), Vector3(x, 5.3, z), PARCHMENT, Vector3.ZERO, 0.08)
	# Two round towers at the front corners, with cone roofs in the team colour.
	for side: float in [-1.0, 1.0]:
		var tx: float = 2.2 * side
		Ink.cyl(self, 0.95, 0.95, 7.0, Vector3(tx, 3.5, 3.0), PARCHMENT)
		Ink.cyl(self, 0.0, 1.35, 2.2, Vector3(tx, 8.1, 3.0), color)
	# Gate: dark door with an arched top, set into the front face.
	Ink.box(self, Vector3(1.5, 2.0, 0.2), Vector3(0, 1.0, 3.05), DOOR)
	Ink.cyl(self, 0.75, 0.75, 0.2, Vector3(0, 2.0, 3.05), DOOR, Vector3(90, 0, 0))
	# Flag on a pole above the wall, streaming toward the enemy.
	Ink.cyl(self, 0.06, 0.06, 3.0, Vector3(0, 6.9, 0), Ink.INK, Vector3.ZERO, 0.03)
	Ink.box(self, Vector3(1.5, 0.9, 0.06), Vector3(0.78 * toward_enemy, 7.9, 0), color, Vector3.ZERO, 0.06)

func is_castle() -> bool:
	return true

func take_damage(amount: float) -> void:
	if hp <= 0.0 or invulnerable:
		return
	hp = maxf(0.0, hp - amount)
	_update_bar()
	if hp <= 0.0:
		destroyed.emit(team)

func _update_bar() -> void:
	var ratio: float = hp / max_hp
	_fill.scale.x = maxf(ratio, 0.001)
	_fill.position.x = -BAR_WIDTH * (1.0 - ratio) * 0.5

func _bar_quad(size: Vector2, color: Color, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.position.z = z
	var mat := Ink.fill_mat(color)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mi.material_override = mat
	return mi

# While a level boss is alive the castle can't be damaged; a translucent ink ward shows it.
func set_invulnerable(value: bool) -> void:
	invulnerable = value
	if value and _ward == null:
		_ward = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 6.0
		sphere.height = 12.0
		sphere.radial_segments = 16
		sphere.rings = 8
		_ward.mesh = sphere
		var mat := Ink.fill_mat(Color(0.48, 0.29, 0.84, 0.18))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ward.material_override = mat
		_ward.position.y = 3.5
		add_child(_ward)
	if _ward != null:
		_ward.visible = value

# Castle drawn as an ink illustration (generated art, baked by tools/bake_sprites.gd): an upright sprite on the lane.
func _build_sprite(path: String) -> void:
	var tex: Texture2D = load(path)
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.pixel_size = SPRITE_WIDTH / float(tex.get_width())
	sprite.offset = Vector2(0.0, tex.get_height() * 0.5)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.5
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
