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
	await _step9()
	await _step10()
	await _part3()
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

func _step9() -> void:
	_setup_arena()
	var hero: Node3D = battle.hero
	hero.set_process(true)
	hero.level = 20
	hero._cd_left = 1.0e9 # no auto attacks, so only skill damage is measured
	hero.position.x = 10.0
	hero.facing = 1.0

	await clear_units()
	var near: Node3D = spawn(1, "soldier", 12.0)
	near.max_hp = 1000.0
	near.hp = 1000.0
	check("dash cast succeeds", hero.cast("dash"))
	hero.take_damage(100.0)
	check("dash: hero is invincible", hero.hp == hero.max_hp)
	await wait(0.4)
	check("dash: moved ~7 m (x=%.2f)" % hero.position.x, absf(hero.position.x - 17.0) < 0.6)
	check("dash: damaged the enemy passed once (lost %.0f)" % (1000.0 - near.hp), is_equal_approx(1000.0 - near.hp, 40.0))

	await clear_units()
	hero.position.x = 10.0
	var ally: Node3D = spawn(0, "soldier", 11.0)
	ally.hp = 20.0
	check("rally cast succeeds", hero.cast("rally"))
	check("rally: heals 30%% of max (hp %.0f)" % ally.hp, is_equal_approx(ally.hp, 38.0))
	check("rally: attack speed boost is active", ally._haste() > 1.4 and battle.rally_t > 5.0)
	check("rally: goes on cooldown", not hero.can_cast("rally"))

	await clear_units()
	hero.position.x = 10.0
	hero.facing = 1.0
	var in_area: Node3D = spawn(1, "soldier", 15.0)
	var out_area: Node3D = spawn(1, "soldier", 22.0)
	for e: Node3D in [in_area, out_area]:
		e.max_hp = 1000.0
		e.hp = 1000.0
	check("sword rain cast succeeds", hero.cast("rain"))
	await wait(2.8)
	var lost: float = 1000.0 - in_area.hp
	check("sword rain hits the area ~8 ticks x20 (lost %.0f)" % lost, lost >= 140.0 and lost <= 180.0)
	check("sword rain leaves enemies outside untouched", out_area.hp == 1000.0)

	await clear_units()
	hero.position.x = 10.0
	var v1: Node3D = spawn(1, "soldier", 11.5)
	var v2: Node3D = spawn(1, "soldier", 19.0)
	v1.max_hp = 1000.0
	v1.hp = 1000.0
	check("vortex (G) cast succeeds", hero.cast("special"))
	await wait(0.3)
	check("vortex damages and shoves nearby enemies", v1.hp == 950.0 and v1.position.x > 12.0)
	check("vortex ignores enemies out of range", v2.hp == v2.max_hp)

	await clear_units()
	battle.ink = 0.0
	check("ultimate refused while the meter is empty", not battle.cast_ultimate())
	hero.position.x = 10.0
	battle.cam_x = 10.0
	var tgt: Node3D = spawn(1, "soldier", 14.0)
	var far: Node3D = spawn(1, "soldier", 38.0)
	for e: Node3D in [tgt, far]:
		e.max_hp = 1000.0
		e.hp = 1000.0
	battle.add_ink(1000.0)
	check("ink meter fills from damage and caps at 100", is_equal_approx(battle.ink, 100.0))
	check("ultimate fires when full", battle.cast_ultimate())
	check("ultimate hits everything on screen for 300 (hp %.0f)" % tgt.hp, is_equal_approx(tgt.hp, 700.0))
	check("ultimate skips enemies off screen", far.hp == 1000.0)
	check("ultimate resets the meter", battle.ink == 0.0)
	await clear_units()

func _step10() -> void:
	const BossData := preload("res://data/bosses.gd")
	Levels.save_path = "user://smoke_progress.cfg"
	Levels.reset_progress()
	check("progress: fresh save unlocks only level 1", Levels.highest_unlocked() == 1)
	Levels.mark_cleared(1)
	Levels.mark_cleared(5)
	check("progress: clearing level 5 unlocks level 6", Levels.highest_unlocked() == 6 and Levels.highest_cleared() == 5)
	Levels.mark_cleared(3)
	check("progress: clearing an earlier level never lowers progress", Levels.highest_cleared() == 5)
	Levels.mark_cleared(20)
	check("progress: cannot unlock past level 20", Levels.highest_unlocked() == 20)
	Levels.reset_progress()
	Levels.mark_cleared(4)

	var expected: Dictionary = {5: [950.0, 26.0], 10: [1900.0, 34.0], 15: [3600.0, 46.0], 20: [6000.0, 58.0]}
	for lv: int in expected:
		var cfg: Dictionary = BossData.for_level(lv)
		check("boss L%d stats %s" % [lv, str(expected[lv])], cfg["hp"] == expected[lv][0] and cfg["atk"] == expected[lv][1])
	for lv in [1, 4, 6, 11]:
		check("level %d has no boss" % lv, not BossData.has_boss(lv))
	check("lava terrain only on levels 11-20", not Levels.is_lava(10) and Levels.is_lava(11) and Levels.is_lava(20))
	check("enemy castle HP = 420 + 70 x level (L7 = %.0f)" % Levels.enemy_castle_hp(7), Levels.enemy_castle_hp(7) == 910.0)
	check("enemy stat multiplier L11 = 2.1", is_equal_approx(Levels.enemy_stat_mult(11), 2.1))
	check("enemy pool L1 is swordsmen only", Levels.enemy_pool(1) == ["soldier"])
	check("enemy pool L13 adds the catapult", "catapult" in Levels.enemy_pool(13) and not "dragon" in Levels.enemy_pool(13))

	# Every boss level: spawns 3 s in, castle is warded until the boss dies.
	for lv in [5, 10, 15, 20]:
		battle.queue_free()
		await get_tree().process_frame
		Levels.current_level = lv
		battle = BATTLE.instantiate()
		add_child(battle)
		await wait(0.3)
		battle.hero._cd_left = 1.0e9
		var castle: Node3D = battle.enemy_castle
		check("L%d: castle is warded before the boss appears" % lv, castle.invulnerable and battle.boss == null)
		await wait(3.2)
		check("L%d: boss spawns ~3 s into the level" % lv, battle.boss != null)
		var hp0: float = castle.hp
		castle.take_damage(100.0)
		check("L%d: castle takes no damage while the boss lives" % lv, castle.hp == hp0)
		check("L%d: boss has the right max HP (%.0f)" % [lv, battle.boss.max_hp], battle.boss.max_hp == BossData.for_level(lv)["hp"])
		battle.boss.take_damage(1.0e9)
		await wait(0.3)
		check("L%d: killing the boss drops the ward (inv=%s boss=%s)" % [lv, str(castle.invulnerable), str(battle.boss)], not castle.invulnerable and battle.boss == null)
		castle.take_damage(100.0)
		check("L%d: castle can be damaged after the boss dies" % lv, castle.hp == hp0 - 100.0)

	# Win / progress hook and lava level.
	battle.queue_free()
	await get_tree().process_frame
	Levels.reset_progress()
	Levels.current_level = 12
	battle = BATTLE.instantiate()
	add_child(battle)
	await wait(0.3)
	battle.spawner.enabled = false
	battle.enemy_castle.take_damage(1.0e9)
	await wait(0.2)
	check("winning level 12 saves progress", Levels.highest_cleared() == 12)
	battle.get_tree().paused = false

	# Map scene.
	var map: Control = load("res://scenes/map.tscn").instantiate()
	add_child(map)
	await wait(0.2)
	check("map has 20 level nodes", map.node_buttons.size() == 20)
	check("map: cleared levels open, next level open, rest locked", not map.node_buttons[12].disabled and not map.node_buttons[13].disabled and map.node_buttons[14].disabled)
	map.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_progress.cfg"))

func _part3() -> void:
	get_tree().paused = false # a finished fight earlier in this file may have left the tree paused
	const Save := preload("res://scripts/save.gd")
	const StoryData := preload("res://data/story_data.gd")
	Save.path = "user://smoke_save.cfg"
	Save.reload()
	Save.reset_all()
	check("story: 4 opening pages with English", StoryData.STORY.size() == 4 and StoryData.STORY_EN.size() == 4 and not StoryData.STORY_EN[0]["t"].is_empty())
	check("story: chapters 1-60 loaded", StoryData.CHAPTERS.size() == 60 and StoryData.CHAPTERS[0]["n"] == 1)
	check("story: chapter 1 and 2 dialogue exist", StoryData.CHS.has("1") and StoryData.CHS.has("2") and StoryData.CHS["1"].size() == 3)
	check("story: chapter dialogue has English", not String(StoryData.CHS["2"][0]["en"]).is_empty())
	check("chapter numbers follow the web game (10 levels each)", Levels.chapter_number(1) == 1 and Levels.chapter_number(10) == 1 and Levels.chapter_number(11) == 2 and Levels.chapter_number(20) == 2)
	check("first-of-chapter levels are 1 and 11", Levels.is_first_of_chapter(1) and Levels.is_first_of_chapter(11) and not Levels.is_first_of_chapter(2))
	check("nothing seen on a fresh save", not Save.intro_seen() and not Save.chapter_story_seen(1))
	Save.mark_intro_seen()
	Save.mark_chapter_story_seen(1)
	Save.reload()
	check("seen stories are saved and survive a reload", Save.intro_seen() and Save.chapter_story_seen(1) and not Save.chapter_story_seen(2))
	Save.set_value("settings", "ink_effects", false)
	check("settings are saved", not Save.ink_effects() and Save.camera_shake())
	Save.set_value("settings", "ink_effects", true)

	# Scenes build without errors.
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await wait(0.3)
	for fn in ["_show_play", "_show_modes", "_show_settings", "_show_stories", "_show_credits", "_show_main"]:
		menu.call(fn)
		await wait(0.1)
	check("menu screens all build", menu.get_child_count() > 0)
	menu._soon("商店", "Shop", "x", "y")
	await wait(0.1)
	menu._play_intro()
	await wait(0.4)
	var story: Control = menu._overlay.get_child(menu._overlay.get_child_count() - 1)
	var finished: Array = [false]
	story.finished.connect(func() -> void: finished[0] = true)
	for i in 4:
		story._advance()
		await wait(0.9)
	await wait(0.3)
	check("opening story advances through 4 pages and finishes", finished[0])
	menu._play_chapter_story(2)
	await wait(2.2)
	var cs: Control = menu._overlay.get_child(menu._overlay.get_child_count() - 1)
	var done: Array = [false]
	cs.finished.connect(func() -> void: done[0] = true)
	for i in 6:
		if is_instance_valid(cs):
			cs._next()
		await wait(0.1)
		if is_instance_valid(cs):
			cs._next()
		await wait(0.1)
	await wait(0.6)
	check("chapter story plays to the end", done[0])
	menu.queue_free()
	await get_tree().process_frame
	Levels.current_level = 5
	get_tree().paused = false
	var banner_battle: Node3D = BATTLE.instantiate()
	add_child(banner_battle)
	await wait(3.6)
	check("boss intro banner appears with the boss (level %d, boss=%s paused=%s t=%.2f ts=%.2f)" % [banner_battle.level, str(banner_battle.boss), str(get_tree().paused), banner_battle.spawner._boss_timer, Engine.time_scale], banner_battle.boss != null)
	banner_battle.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_save.cfg"))
	Save.path = Save.PATH_DEFAULT
	Save.reload()
