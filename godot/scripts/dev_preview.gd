extends Node

# Developer preview: every unit type lined up (gold = player, red row behind), on a lava boss level.
# Run scenes/dev_preview.tscn from the editor (F6) to inspect the models and animations.

const Levels := preload("res://data/levels.gd")
const UnitData := preload("res://data/units.gd")
const BATTLE: PackedScene = preload("res://scenes/battle.tscn")

@export var preview_level: int = 15

func _ready() -> void:
	Levels.current_level = preview_level
	var battle: Node3D = BATTLE.instantiate()
	add_child(battle)
	await get_tree().process_frame
	battle.spawner.enabled = false
	battle.hero.position.x = 20.0
	battle.cam_x = 20.0
	var keys: Array = UnitData.UNITS.keys()
	for i in keys.size():
		for team in 2:
			var u: Node3D = battle.spawn_unit(team, keys[i])
			u.position = Vector3(10.0 + i * 1.9, 0.0, 1.6 if team == 0 else -1.6)
			u.speed = 0.0
			u._cd_left = 1.0e9
	battle.spawn_boss()
	if battle.boss != null:
		battle.boss.position.x = 33.0
		battle.boss.speed = 0.0
	# Optional: INK_SHOT=<png path> saves a screenshot of the viewport and quits (used for visual checks).
	var shot: String = OS.get_environment("INK_SHOT")
	if shot != "":
		await get_tree().create_timer(2.0).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()
