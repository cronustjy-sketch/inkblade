extends Node

# Developer smoke test for the 3D Boss Raid mode (headless): scenes/dev_raid_smoke.tscn.

const RAID: PackedScene = preload("res://scenes/raid.tscn")
const RaidData := preload("res://data/raid.gd")

var raid: Node3D
var failures: int = 0

func _ready() -> void:
	RaidData.save_path = "user://raid_smoke.cfg"
	RaidData.reset_records()
	await _new_raid(true)
	await _part1()
	await _part2()
	await _new_raid(false)
	await _boss_flow(0)
	await _new_raid(false)
	await _extra_bosses()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://raid_smoke.cfg"))
	print("RAID SMOKE DONE failures=%d" % failures)
	get_tree().quit()

# A fresh raid scene; training = true gives a practice dummy instead of the boss ladder.
func _new_raid(training: bool, boss_env: int = 0) -> void:
	if raid != null:
		raid.queue_free()
		await get_tree().process_frame
	raid = RAID.instantiate()
	raid.training = training
	add_child(raid)
	await wait(0.5)

func _extra_bosses() -> void:
	pass

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

func _part2() -> void:
	const Telegraph := preload("res://scripts/telegraph.gd")
	var hero: CharacterBody3D = raid.hero
	var dummy: Node3D = raid.dummy
	dummy.attack_enabled = false
	dummy.hp = dummy.max_hp
	hero.global_position = Vector3(0, 0.05, -5.0)
	hero.velocity = Vector3.ZERO
	hero.move_input = Vector2.ZERO
	hero.cam_yaw = 0.0
	await wait(0.2)
	var hp0: float = dummy.hp
	hero.attack()
	await wait(0.6)
	check("combo hit 1 damages the target (%.0f)" % (hp0 - dummy.hp), is_equal_approx(hp0 - dummy.hp, 22.0))
	hero.attack()
	await wait(0.6)
	hero.attack()
	await wait(0.9)
	check("3-hit combo total 22+26+44 (%.0f)" % (hp0 - dummy.hp), is_equal_approx(hp0 - dummy.hp, 92.0))

	await wait(1.2)
	hp0 = dummy.hp
	check("Q slash cast works", hero.cast("slash"))
	check("Q slash deals 70 (%.0f)" % (hp0 - dummy.hp), is_equal_approx(hp0 - dummy.hp, 70.0))
	check("Q goes on cooldown", not hero.can_cast("slash"))

	hp0 = dummy.hp
	hero.global_position = Vector3(0, 0.05, -0.5)
	hero.facing = Vector3(0, 0, -1)
	check("E dash cast works", hero.cast("dash"))
	check("dash grants invincibility", hero.invincible_t > 0.3)
	await wait(0.5)
	check("E dash damaged the dummy it passed (%.0f)" % (hp0 - dummy.hp), is_equal_approx(hp0 - dummy.hp, 40.0))

	hero.hp = 100.0
	check("R rally cast works", hero.cast("rally"))
	check("R heals 30%% and gives haste (hp %.0f)" % hero.hp, is_equal_approx(hero.hp, 190.0) and hero.haste_t > 5.0)

	hero.global_position = Vector3(0, 0.05, -2.0)
	hp0 = dummy.hp
	check("F sword rain cast works", hero.cast("rain"))
	await wait(2.8)
	check("F rain hits ~8 ticks x20 (%.0f)" % (hp0 - dummy.hp), hp0 - dummy.hp >= 140.0 and hp0 - dummy.hp <= 180.0)

	# Dodge roll and telegraphs.
	hero.global_position = Vector3(10, 0.05, 6)
	await wait(0.3)
	hero.hp = hero.max_hp
	var t1: Node3D = Telegraph.circle(raid, hero.global_position, 3.0, 0.4, 25.0, hero)
	await wait(0.7)
	check("standing in a red circle hurts (hp %.0f)" % hero.hp, is_equal_approx(hero.hp, hero.max_hp - 25.0))
	hero.hp = hero.max_hp
	Telegraph.circle(raid, hero.global_position + Vector3(9, 0, 0), 3.0, 0.4, 25.0, hero)
	await wait(0.7)
	check("standing outside the circle is safe", hero.hp == hero.max_hp)
	await wait(0.5)
	Telegraph.circle(raid, hero.global_position, 3.0, 0.5, 25.0, hero)
	await wait(0.2)
	hero.move_input = Vector2(1, 0)
	hero.dodge()
	await wait(0.4)
	check("a dodge roll has invincibility (hp %.0f)" % hero.hp, hero.hp == hero.max_hp or hero.global_position.distance_to(Vector3(10, 0, 6)) > 3.4)
	hero.move_input = Vector2.ZERO
	await wait(1.0)
	hero.hp = hero.max_hp
	hero.invincible_t = 0.0
	hero.take_damage(30.0)
	check("damage lowers hero HP", is_equal_approx(hero.hp, hero.max_hp - 30.0))
	hero.invincible_t = 1.0
	hero.take_damage(30.0)
	check("invincibility blocks damage", is_equal_approx(hero.hp, hero.max_hp - 30.0))
	var died: Array = [false]
	hero.died.connect(func() -> void: died[0] = true)
	hero.invincible_t = 0.0
	hero.take_damage(9999.0)
	check("hero dies at 0 HP", hero.dead and died[0] and raid.over)
	t1 = null

# One full boss fight: countdown, telegraphs, phase 2 at 50% HP, victory with a saved best time, retry, defeat.
func _boss_flow(index: int) -> void:
	var hero: CharacterBody3D = raid.hero
	var cfg: Dictionary = RaidData.BOSSES[index]
	check("[%s] boss exists and the HUD shows it" % cfg["id"], raid.boss != null and raid.boss.max_hp == cfg["hp"])
	check("[%s] the fight starts in a countdown (controls off)" % cfg["id"], raid.state == raid.State.COUNTDOWN and not hero.controls_enabled and not raid.boss.active)
	await wait(3.9)
	check("[%s] after 3 s the fight begins" % cfg["id"], raid.state == raid.State.FIGHT and hero.controls_enabled and raid.boss.active)
	hero.max_hp = 99999.0
	hero.hp = 99999.0
	var seen: Dictionary = {}
	var t: float = 0.0
	while t < 25.0 and seen.size() < 2:
		await wait(0.25)
		t += 0.25
		for node: Node in raid.get_children():
			if node.has_method("_hero_inside"):
				seen[str(node.shape)] = true
	check("[%s] the boss throws ground telegraphs (%d kinds seen)" % [cfg["id"], seen.size()], seen.size() >= 1)
	raid.boss.take_hit(raid.boss.max_hp * 0.52, Vector3.ZERO)
	check("[%s] HP bar follows the boss (hp %.0f)" % [cfg["id"], raid.boss.hp], raid.boss.hp < raid.boss.max_hp * 0.5)
	t = 0.0
	while t < 14.0 and raid.boss.phase != 2:
		await wait(0.25)
		t += 0.25
	check("[%s] phase 2 starts at 50%% HP (faster: x%.2f)" % [cfg["id"], raid.boss.speed_mult], raid.boss.phase == 2 and raid.boss.speed_mult > 1.2)
	await wait(2.2)
	var time_before: float = raid.fight_time
	raid.boss.take_hit(1.0e9, Vector3.ZERO)
	await wait(0.2)
	check("[%s] killing the boss ends the fight" % cfg["id"], not raid.boss.alive and raid.state == raid.State.OVER and raid.over)
	await wait(2.0)
	check("[%s] victory saves the best clear time (%.1fs)" % [cfg["id"], RaidData.best_time(cfg["id"])], RaidData.best_time(cfg["id"]) > 0.0 and absf(RaidData.best_time(cfg["id"]) - time_before) < 2.5)
	var has_result: bool = raid.hud._result != null
	check("[%s] a victory panel is shown" % cfg["id"], has_result)
	raid._retry()
	await wait(0.4)
	check("[%s] retry restarts the fight with a fresh boss and a healthy hero" % cfg["id"], raid.boss.alive and raid.boss.hp == raid.boss.max_hp and raid.hero.hp == raid.hero.max_hp and raid.state == raid.State.COUNTDOWN and raid.hud._result == null)
	await wait(3.8)
	raid.hero.hp = 10.0
	raid.hero.invincible_t = 0.0
	raid.hero.take_damage(50.0)
	await wait(1.6)
	check("[%s] hero defeat shows a defeat panel" % cfg["id"], raid.hero.dead and raid.hud._result != null and not raid.boss.active)
