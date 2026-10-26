extends Node

const Levels := preload("res://data/levels.gd")
const BossData := preload("res://data/bosses.gd")

var battle: Node3D
var level: int = 1
var enabled: bool = true
var _timer: float = 0.0
var _boss_timer: float = -1.0

func setup(p_battle: Node3D, p_level: int) -> void:
	battle = p_battle
	level = p_level
	_timer = Levels.enemy_spawn_interval(level)
	if BossData.has_boss(level):
		_boss_timer = BossData.SPAWN_DELAY

func _process(delta: float) -> void:
	if _boss_timer >= 0.0:
		_boss_timer -= delta
		if _boss_timer < 0.0:
			battle.spawn_boss()
	if not enabled:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = Levels.enemy_spawn_interval(level)
	if get_tree().get_nodes_in_group("team_1").size() >= Levels.enemy_cap(level):
		return
	var pool: Array[String] = Levels.enemy_pool(level)
	battle.spawn_unit(1, pool.pick_random(), Levels.enemy_stat_mult(level))
