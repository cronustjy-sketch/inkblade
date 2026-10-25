extends Node3D

const UnitData := preload("res://data/units.gd")
const PLAYER_COLOR := Color("e8b44a")
const ENEMY_COLOR := Color("de4b3f")
const CASTLE_HALF_WIDTH: float = 3.2

var team: int = 0
var key: String = "soldier"
var hp: float = 60.0
var max_hp: float = 60.0
var atk: float = 10.0
var attack_range: float = 0.8
var speed: float = 1.5
var cooldown: float = 0.9
var pop: int = 1

var enemy_castle: Node3D
var _cd_left: float = 0.0
var _dir: float = 1.0
var _fill: MeshInstance3D

# stat_mult scales hp and atk (enemy level scaling).
func setup(p_team: int, p_key: String, p_enemy_castle: Node3D, stat_mult: float = 1.0) -> void:
	team = p_team
	key = p_key
	enemy_castle = p_enemy_castle
	var d: Dictionary = UnitData.UNITS[key]
	max_hp = d["hp"] * stat_mult
	hp = max_hp
	atk = d["atk"] * stat_mult
	attack_range = d["range"] / UnitData.PX_PER_M
	speed = d["speed"] / UnitData.PX_PER_M
	cooldown = d["cooldown"]
	pop = d["pop"]
	_dir = 1.0 if team == 0 else -1.0

func _ready() -> void:
	add_to_group("units")
	add_to_group("team_%d" % team)
	var color: Color = PLAYER_COLOR if team == 0 else ENEMY_COLOR

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	body.mesh = capsule
	body.position.y = 0.8
	body.material_override = _unshaded(color)
	add_child(body)

	_fill = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.1)
	_fill.mesh = quad
	_fill.position.y = 1.9
	var bar_mat := _unshaded(Color("3ddc6a"))
	bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar_mat.billboard_keep_scale = true
	_fill.material_override = bar_mat
	add_child(_fill)

func _process(delta: float) -> void:
	_cd_left -= delta
	var target: Node3D = _nearest_enemy()
	if target != null and _x_gap(target.global_position.x) <= attack_range:
		_try_attack(target)
	elif enemy_castle != null and _castle_gap() <= attack_range:
		_try_attack(enemy_castle)
	else:
		global_position.x += _dir * speed * delta

func take_damage(amount: float) -> void:
	hp -= amount
	_fill.scale.x = maxf(hp / max_hp, 0.001)
	if hp <= 0.0:
		queue_free()

func _try_attack(target: Node3D) -> void:
	if _cd_left > 0.0:
		return
	_cd_left = cooldown
	target.take_damage(atk)

func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_gap: float = INF
	for u: Node3D in get_tree().get_nodes_in_group("team_%d" % (1 - team)):
		if u.is_queued_for_deletion():
			continue
		var gap: float = _x_gap(u.global_position.x)
		if gap < best_gap:
			best_gap = gap
			best = u
	return best

func _x_gap(other_x: float) -> float:
	return absf(other_x - global_position.x)

func _castle_gap() -> float:
	return _x_gap(enemy_castle.global_position.x) - CASTLE_HALF_WIDTH

func _unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat
