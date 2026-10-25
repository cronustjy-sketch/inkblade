extends Node

const Levels := preload("res://data/levels.gd")

var battle: Node3D
var level: int = 1
var _timer: float = 0.0

func setup(p_battle: Node3D, p_level: int) -> void:
	battle = p_battle
	level = p_level
	_timer = Levels.enemy_spawn_interval(level)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = Levels.enemy_spawn_interval(level)
	if get_tree().get_nodes_in_group("team_1").size() >= Levels.enemy_cap(level):
		return
	var pool: Array[String] = Levels.enemy_pool(level)
	battle.spawn_unit(1, pool.pick_random(), Levels.enemy_stat_mult(level))
