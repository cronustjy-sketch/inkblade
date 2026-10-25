extends Node

# Developer smoke test: run scenes/dev_smoke.tscn to drive the battle from code and print PASS/FAIL lines.
# Not part of the game; used to check gameplay logic without keyboard input.

const Levels := preload("res://data/levels.gd")
const BATTLE: PackedScene = preload("res://scenes/battle.tscn")

var battle: Node3D
var failures: int = 0

func _ready() -> void:
	Levels.current_level = 1
	battle = BATTLE.instantiate()
	add_child(battle)
	await get_tree().create_timer(0.5).timeout
	await _step5()
	await _step7()
	await _step8()
	print("SMOKE DONE failures=%d" % failures)
	get_tree().quit()

func check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _step5() -> void:
	var hero: Node3D = battle.hero
	var x0: float = hero.position.x
	hero.move(1.0, 0.5)
	check("hero moves right with input", hero.position.x > x0)
	hero.position.x = 20.0
	battle.spawn_unit(1, "soldier")
	var foe: Node3D = get_tree().get_nodes_in_group("team_1")[0]
	foe.position = Vector3(24.0, 0.0, 0.0)
	var foe_hp: float = foe.hp
	check("slash cast succeeds", hero.cast("slash"))
	check("slash damages enemy in front", not is_instance_valid(foe) or foe.hp < foe_hp)
	check("slash goes on cooldown", not hero.can_cast("slash"))
	check("second cast refused during cooldown", not hero.cast("slash"))
	await wait(0.2)
	hero.take_damage(9999.0)
	check("hero dies at 0 hp", hero.is_dead())
	await wait(5.3)
	check("hero respawns", not hero.is_dead() and hero.hp == hero.max_hp)

# ---------- helpers for unit tests ----------

func clear_units() -> void:
	for u: Node in get_tree().get_nodes_in_group("units"):
		u.queue_free()
	await get_tree().process_frame

# Spawns a frozen unit at x so the test controls who fights whom.
func spawn(team: int, key: String, x: float, frozen: bool = true) -> Node3D:
	var u: Node3D = battle.spawn_unit(team, key)
	u.position = Vector3(x, 0.0, 0.0)
	if frozen:
		u.speed = 0.0
	return u

func _setup_arena() -> void:
	battle.spawner.enabled = false
	battle.hero.remove_from_group("team_0")
	battle.hero.position.x = 3.9
	battle.hero.set_process(false)
	battle.energy = 0.0

func _step7() -> void:
	_setup_arena()

	await clear_units()
	var shield: Node3D = spawn(0, "shield", 10.0)
	shield.take_damage(100.0)
	check("shield armor cuts damage by 35%% (hp %.0f)" % shield.hp, is_equal_approx(shield.hp, 240.0 - 65.0))

	await clear_units()
	var spear: Node3D = spawn(0, "spear", 10.0)
	var giant: Node3D = spawn(1, "giant", 10.8)
	await wait(0.2)
	check("spear deals x2 vs big unit (giant lost %.0f)" % (giant.max_hp - giant.hp), is_equal_approx(giant.max_hp - giant.hp, 24.0))

	await clear_units()
	spawn(0, "archer", 10.0)
	var target: Node3D = spawn(1, "soldier", 14.0)
	await wait(1.5)
	check("archer arrow hits at range", target.hp < target.max_hp)

	await clear_units()
	var foe_archer: Node3D = spawn(1, "archer", 19.0)
	var shield2: Node3D = spawn(0, "shield", 16.5)
	var behind: Node3D = spawn(0, "soldier", 14.0)
	await wait(1.3)
	check("shield blocks arrows for the unit behind it", shield2.hp < shield2.max_hp and behind.hp == behind.max_hp)
	foe_archer.queue_free()

	await clear_units()
	spawn(0, "witch", 10.0)
	var a: Node3D = spawn(1, "soldier", 13.0)
	var b: Node3D = spawn(1, "soldier", 13.8)
	await wait(2.6)
	check("witch orb splashes both enemies", a.hp < a.max_hp and b.hp < b.max_hp)

	await clear_units()
	var assassin: Node3D = spawn(0, "assassin", 10.0)
	var dummy: Node3D = spawn(1, "soldier", 10.5)
	dummy.max_hp = 1.0e9
	var crits: int = 0
	for i in 300:
		dummy.hp = dummy.max_hp
		assassin._cd_left = 0.0
		assassin._try_attack(dummy)
		if is_equal_approx(dummy.max_hp - dummy.hp, 50.0):
			crits += 1
	check("assassin crits ~30%% of hits (%d/300 x2.5)" % crits, crits > 60 and crits < 120)

	await clear_units()
	spawn(0, "priest", 10.0)
	var hurt: Node3D = spawn(0, "soldier", 11.0)
	hurt.hp = 30.0
	await wait(0.3)
	check("priest heals wounded ally by 16 (hp %.0f)" % hurt.hp, is_equal_approx(hurt.hp, 46.0))

	await clear_units()
	spawn(0, "giant", 10.0)
	var g1: Node3D = spawn(1, "soldier", 10.8)
	var g2: Node3D = spawn(1, "soldier", 11.5)
	await wait(0.3)
	check("giant hits everything nearby for 38 (hp %.0f / %.0f)" % [g1.hp, g2.hp], is_equal_approx(g1.hp, 22.0) and is_equal_approx(g2.hp, 22.0))
	check("giant knocks enemies back", g1.position.x > 10.9 and g2.position.x > 11.6)

	await clear_units()
	var cav: Node3D = spawn(0, "cavalry", 10.0)
	var victim: Node3D = spawn(1, "soldier", 10.5)
	victim.max_hp = 1000.0
	victim.hp = 1000.0
	await wait(0.2)
	check("cavalry first hit x2 (lost %.0f)" % (1000.0 - victim.hp), is_equal_approx(1000.0 - victim.hp, 40.0))
	check("cavalry first hit knocks back", victim.position.x > 10.7)
	cav.queue_free()

	await clear_units()
	spawn(0, "catapult", 33.0)
	var castle: Node3D = battle.enemy_castle
	var castle_before: float = castle.hp
	await wait(1.8)
	check("catapult does x2 to the castle (lost %.0f)" % (castle_before - castle.hp), is_equal_approx(castle_before - castle.hp, 100.0))

	await clear_units()
	var dragon: Node3D = spawn(1, "dragon", 10.0)
	var grunt: Node3D = spawn(0, "soldier", 10.5)
	await wait(2.0)
	check("ground melee can't hit a dragon", dragon.hp == dragon.max_hp)
	check("dragon attacks ground units", grunt.hp < grunt.max_hp or not is_instance_valid(grunt))
	var bow: Node3D = spawn(0, "archer", 7.0)
	await wait(1.6)
	check("archer can hit a flying dragon", dragon.hp < dragon.max_hp)
	bow.queue_free()
	await clear_units()

func _step8() -> void:
	_setup_arena()
	const ATTACK := 0
	const DEFEND := 1
	const RETREAT := 2

	await clear_units()
	battle.set_order(DEFEND)
	var d: Node3D = spawn(0, "soldier", 10.0, false)
	await wait(3.0)
	check("defend: unit holds the line ~7 m out (x=%.2f)" % d.position.x, absf(d.position.x - 7.0) < 0.4)

	await clear_units()
	battle.set_order(RETREAT)
	var r: Node3D = spawn(0, "soldier", 5.0, false)
	await wait(2.2)
	check("retreat: unit goes inside the castle", r.inside and not r._rig.visible)
	r.hp = 30.0
	await wait(1.0)
	check("retreat: heals while inside (hp %.1f)" % r.hp, r.hp > 33.0)
	var foe: Node3D = spawn(1, "soldier", 3.6, false)
	var hp_before: float = r.hp
	await wait(1.2)
	check("retreat: units inside can't be attacked", r.hp >= hp_before)
	foe.queue_free()
	battle.set_order(ATTACK)
	await wait(0.1)
	check("attack order: unit comes back out", not r.inside and r._rig.visible)

	await clear_units()
	battle.set_order(ATTACK)
	var c: Node3D = spawn(0, "soldier", 10.0, false)
	var c2: Node3D = spawn(0, "archer", 12.0)
	battle.control(c)
	check("control: unit is marked controlled", c.controlled and battle.controlled == c)
	var x0: float = c.position.x
	Input.action_press("ui_right")
	await wait(0.5)
	Input.action_release("ui_right")
	check("control: arrow keys move the controlled unit (dx=%.2f)" % (c.position.x - x0), c.position.x - x0 > 0.5)
	await wait(0.1)
	var x1: float = c2.position.x
	check("control: other units are not moved by the keys", is_equal_approx(c2.position.x, x1))
	battle.cycle_control()
	check("control: Tab cycles to the next soldier", battle.controlled == c2)
	battle.cycle_control()
	check("control: Tab wraps around", battle.controlled == c)
	battle.release_control()
	check("control: H returns to the hero", battle.controlled == null and not c.controlled)

	await clear_units()
	var boosted: Node3D = spawn(0, "soldier", 10.0)
	var dummy: Node3D = spawn(1, "soldier", 10.5)
	dummy.max_hp = 1000.0
	dummy.hp = 1000.0
	battle.control(boosted)
	await wait(0.2)
	check("control: +40%% damage (lost %.1f)" % (1000.0 - dummy.hp), is_equal_approx(1000.0 - dummy.hp, 14.0))
	boosted.take_damage(9999.0)
	await wait(0.1)
	check("control: released when the unit dies", battle.controlled == null)
	await clear_units()
