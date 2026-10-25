extends Node3D

signal destroyed(team: int)

enum Team { PLAYER, ENEMY }

const BAR_WIDTH: float = 5.0
const COLOR_PLAYER := Color("e8b44a")
const COLOR_ENEMY := Color("de4b3f")

@export var team: Team = Team.PLAYER
@export var max_hp: float = 500.0

var hp: float = 500.0
var _fill: MeshInstance3D

func _ready() -> void:
	hp = max_hp
	var color: Color = COLOR_PLAYER if team == Team.PLAYER else COLOR_ENEMY

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(5, 7, 7)
	body.mesh = box
	body.position.y = 3.5
	body.material_override = _unshaded(color)
	add_child(body)

	var bar_root := Node3D.new()
	bar_root.position = Vector3(0, 8.5, 0)
	add_child(bar_root)
	bar_root.add_child(_bar_quad(Vector2(BAR_WIDTH, 0.5), Color("13161b"), 0.0))
	_fill = _bar_quad(Vector2(BAR_WIDTH, 0.5), color, 0.01)
	bar_root.add_child(_fill)

	var label := Label3D.new()
	label.text = "我方城堡\nYour Castle" if team == Team.PLAYER else "敌方城堡\nEnemy Castle"
	label.position = Vector3(0, 1.0, 0)
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	bar_root.add_child(label)

func take_damage(amount: float) -> void:
	if hp <= 0.0:
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
	var mat := _unshaded(color)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mi.material_override = mat
	return mi

func _unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat
