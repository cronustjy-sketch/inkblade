extends Node

# Developer smoke test for the 3D Boss Raid mode (headless): scenes/dev_raid_smoke.tscn.

const RAID: PackedScene = preload("res://scenes/raid.tscn")

var raid: Node3D
var failures: int = 0

func _ready() -> void:
	raid = RAID.instantiate()
	add_child(raid)
	await wait(0.5)
	await _part1()
	print("RAID SMOKE DONE failures=%d" % failures)
	get_tree().quit()

func check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _part1() -> void:
	var hero: CharacterBody3D = raid.hero
	check("hero stands on the arena floor", hero.is_on_floor() and hero.global_position.y > -0.2)
	var z0: float = hero.global_position.z
	raid.set_process(false)
	hero.cam_yaw = 0.0
	hero.move_input = Vector2(0, 1)
	await wait(0.6)
	check("W moves the hero away from the camera (dz=%.2f)" % (hero.global_position.z - z0), hero.global_position.z < z0 - 1.5)
	hero.move_input = Vector2(0, 0)
	await wait(0.3)
	hero.move_input = Vector2(1, 0)
	var x0: float = hero.global_position.x
	await wait(0.5)
	check("D strafes right", hero.global_position.x > x0 + 1.0)
	hero.move_input = Vector2(1, 1)
	await wait(6.0)
	check("the hero is kept inside the arena (r=%.1f)" % Vector2(hero.global_position.x, hero.global_position.z).length(), Vector2(hero.global_position.x, hero.global_position.z).length() <= 28.6)
	raid.rig.yaw = 1.0
	await wait(0.3)
	check("camera yaw can rotate", is_equal_approx(raid.rig.yaw, 1.0))
	raid.rig.zoom(0.5)
	check("camera zoom is clamped", raid.rig.distance >= 3.5 and raid.rig.distance < 8.5)
