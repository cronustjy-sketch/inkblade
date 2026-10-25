extends Node3D

# 3D Boss Raid mode: a round toon arena, a third-person hero and a ladder of boss fights.
# Flow per fight: 3-2-1 countdown -> fight (timer runs) -> victory (time, best time, Next Boss) or defeat (Retry).
# `training = true` (set before adding to the tree) replaces the ladder with a training dummy; used by tests.

const Arena := preload("res://scripts/raid_arena.gd")
const HeroScript := preload("res://scripts/raid_hero.gd")
const CameraScript := preload("res://scripts/raid_camera.gd")
const HudScript := preload("res://scripts/raid_hud.gd")
const DummyScript := preload("res://scripts/raid_dummy.gd")
const BossScript := preload("res://scripts/raid_boss.gd")
const RaidData := preload("res://data/raid.gd")
const MENU_SCENE: String = "res://scenes/menu.tscn"
const SKILL_KEYS: Dictionary = {KEY_Q: "slash", KEY_E: "dash", KEY_R: "rally", KEY_F: "rain"}
const START_POS := Vector3(0, 0.05, 11)
const BOSS_POS := Vector3(0, 0.0, -13)

enum State { COUNTDOWN, FIGHT, OVER }

var training: bool = false
var arena: Node3D
var hero: CharacterBody3D
var rig: Node3D
var hud: CanvasLayer
var dummy: Node3D
var boss: CharacterBody3D
var boss_index: int = 0
var state: State = State.OVER
var fight_time: float = 0.0
var over: bool = false # the fight has ended (won or lost): fight controls are off
var _run_id: int = 0 # bumped on every (re)start so stale countdowns stop

func _ready() -> void:
	_environment()
	arena = Node3D.new()
	arena.set_script(Arena)
	add_child(arena)
	arena.build()

	hero = CharacterBody3D.new()
	hero.set_script(HeroScript)
	hero.position = START_POS
	add_child(hero)

	rig = Node3D.new()
	rig.set_script(CameraScript)
	rig.add_to_group("raid_camera")
	add_child(rig)
	rig.target = hero
	rig.global_position = hero.position + Vector3(0, 1.5, 0)
	rig.camera.make_current()

	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	add_child(hud)
	hud.attack_pressed.connect(func() -> void: _fight_input(hero.attack))
	hud.dodge_pressed.connect(func() -> void: _fight_input(hero.dodge))
	hud.skill_pressed.connect(func(id: String) -> void: hero.cast(id))
	hud.menu_pressed.connect(_leave)
	hud.retry_pressed.connect(_retry)
	hud.next_pressed.connect(_next)
	hero.damaged.connect(_on_hero_damaged)
	hero.died.connect(_on_hero_died)
	hud.set_hero_hp(hero.hp, hero.max_hp)
	hud.show_touch(DisplayServer.is_touchscreen_available())

	if OS.get_environment("RAID_TRAIN") != "" and OS.is_debug_build():
		training = true
	var shot: String = OS.get_environment("RAID_SHOT")
	if training:
		dummy = Node3D.new()
		dummy.set_script(DummyScript)
		add_child(dummy)
		dummy.position = Vector3(0, 0, -8)
		dummy.hero = hero
		hero.position = Vector3(0, 0.05, 9)
		state = State.FIGHT
	else:
		var start: int = 0
		if OS.get_environment("RAID_BOSS") != "" and OS.is_debug_build():
			start = clampi(int(OS.get_environment("RAID_BOSS")) - 1, 0, RaidData.BOSSES.size() - 1)
		_start_fight(start)
	if shot != "" and OS.is_debug_build():
		_screenshot_later(shot)

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("2f8fe8")
	mat.sky_horizon_color = Color("bfe9ff")
	mat.ground_horizon_color = Color("bfe9ff")
	mat.ground_bottom_color = Color("78cc58")
	mat.sun_angle_max = 25.0
	mat.sun_curve = 0.15
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

# ---------- fight flow ----------

func _start_fight(index: int) -> void:
	_run_id += 1
	var run: int = _run_id
	boss_index = index
	over = false
	state = State.COUNTDOWN
	fight_time = 0.0
	hud.clear_result()
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	for node: Node in get_children():
		if node is Node3D and node.has_method("_hero_inside"):
			node.queue_free() # leftover telegraphs
	hero.revive()
	hero.global_position = START_POS
	hero.rotation.y = 0.0
	hero.controls_enabled = false
	rig.yaw = 0.0
	rig.pitch = deg_to_rad(13.0) if RaidData.BOSSES[index]["flying"] else deg_to_rad(22.0)
	rig.distance = 12.0 if RaidData.BOSSES[index]["flying"] else 10.5
	hud.set_hero_hp(hero.hp, hero.max_hp)
	hud.set_time(0.0)

	var cfg: Dictionary = RaidData.BOSSES[index]
	boss = CharacterBody3D.new()
	boss.set_script(BossScript)
	boss.setup(cfg, hero)
	boss.position = BOSS_POS
	boss.rotation.y = PI # facing the hero
	add_child(boss)
	boss.hp_changed.connect(hud.set_boss_hp)
	boss.defeated.connect(_on_boss_defeated)
	hud.show_boss(cfg["cn"], cfg["en"], boss.hp, boss.max_hp)
	hud.set_best(RaidData.best_time(cfg["id"]))

	for n in [3, 2, 1]:
		hud.set_center(str(n))
		await get_tree().create_timer(1.0).timeout
		if run != _run_id:
			return
	hud.set_center("开战！ FIGHT!", 72)
	hero.controls_enabled = true
	boss.active = true
	state = State.FIGHT
	await get_tree().create_timer(0.8).timeout
	if run == _run_id:
		hud.set_center("")

func _on_boss_defeated() -> void:
	if state != State.FIGHT:
		return
	state = State.OVER
	over = true
	hero.controls_enabled = false
	var cfg: Dictionary = RaidData.BOSSES[boss_index]
	var seconds: float = fight_time
	RaidData.record(cfg["id"], seconds)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(1.6).timeout
	hud.show_result(true, seconds, RaidData.best_time(cfg["id"]), boss_index + 1 < RaidData.BOSSES.size(), "%s  %s" % [cfg["cn"], cfg["en"]])

func _on_hero_died() -> void:
	if training:
		over = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_result(false, 0.0, 0.0, false, "训练木桩 Training Dummy")
		return
	if state == State.OVER:
		return
	state = State.OVER
	over = true
	if boss != null and is_instance_valid(boss):
		boss.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cfg: Dictionary = RaidData.BOSSES[boss_index]
	await get_tree().create_timer(1.2).timeout
	hud.show_result(false, fight_time, 0.0, false, "%s  %s" % [cfg["cn"], cfg["en"]])

func _retry() -> void:
	if training:
		get_tree().reload_current_scene()
		return
	_start_fight(boss_index)

func _next() -> void:
	_start_fight(mini(boss_index + 1, RaidData.BOSSES.size() - 1))

func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)

func _fight_input(action: Callable) -> void:
	if not over:
		action.call()

# ---------- per-frame and input ----------

func _process(delta: float) -> void:
	if state == State.FIGHT and not training:
		fight_time += delta
		hud.set_time(fight_time)
	var move := Vector2.ZERO
	move.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	move.y = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	if hud.joystick.length() > 0.05:
		move = hud.joystick
	hero.move_input = move
	hero.cam_yaw = rig.yaw
	hud.update_skills(hero)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not over:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_fight_input(hero.attack)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_SPACE:
			_fight_input(hero.dodge)
		elif event.keycode == KEY_F10:
			hud.show_touch(not hud.is_touch_shown())
		elif SKILL_KEYS.has(event.keycode):
			if not over:
				hero.cast(SKILL_KEYS[event.keycode])
		elif OS.is_debug_build() and event.keycode >= KEY_1 and event.keycode <= KEY_5 and not training:
			_start_fight(clampi(event.keycode - KEY_1, 0, RaidData.BOSSES.size() - 1)) # debug: jump to a boss

func _on_hero_damaged(amount: float) -> void:
	hud.set_hero_hp(hero.hp, hero.max_hp)
	if amount > 0.0:
		hud.flash_damage()
		rig.shake = 0.5

# Dev helper: RAID_SHOT=<png> saves a screenshot after a moment and quits (debug builds only).
# RAID_ACT=attack|skills|telegraph (training mode) or RAID_BOSS=<n> (boss n) pick what to look at;
# RAID_WAIT=<seconds> waits longer before the shot; RAID_BOT=1 makes the hero auto-fight so boss moves show up.
func _screenshot_later(path: String) -> void:
	var act: String = OS.get_environment("RAID_ACT")
	if OS.get_environment("RAID_LOOK") == "boss" and boss != null:
		rig.target = boss
		rig.distance = 10.0
		rig.pitch = 0.1
		rig.yaw = float(OS.get_environment("RAID_YAW")) if OS.get_environment("RAID_YAW") != "" else 0.0
	if training and act == "attack":
		hero.position = Vector3(0, 0.05, -5.5)
		rig.yaw = PI
		await get_tree().create_timer(1.0).timeout
		hero.attack()
		await get_tree().create_timer(0.3).timeout
	elif training and act == "skills":
		hero.position = Vector3(0, 0.05, -4.0)
		await get_tree().create_timer(0.8).timeout
		hero.cast("rain")
		await get_tree().create_timer(1.0).timeout
	elif training and act == "telegraph":
		dummy.attack_enabled = false
		const Telegraph := preload("res://scripts/telegraph.gd")
		Telegraph.circle(self, hero.global_position + Vector3(0, 0, -3), 4.0, 5.0, 30.0, hero)
		Telegraph.line(self, Vector3(-8, 0, -2), Vector3(1, 0, 0), 16.0, 2.5, 5.0, 30.0, hero)
		Telegraph.cone(self, Vector3(8, 0, 4), Vector3(-1, 0, -1), 80.0, 7.0, 5.0, 30.0, hero)
		await get_tree().create_timer(2.5).timeout
	else:
		var wait: float = float(OS.get_environment("RAID_WAIT")) if OS.get_environment("RAID_WAIT") != "" else 5.5
		var elapsed: float = 0.0
		var bot: bool = OS.get_environment("RAID_BOT") != ""
		while elapsed < wait:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
			if bot and state == State.FIGHT and boss != null and is_instance_valid(boss):
				_bot_step()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

# A tiny auto-player for screenshots: walks at the boss and swings when close, never dodges.
func _bot_step() -> void:
	var rel: Vector3 = boss.global_position - hero.global_position
	rel.y = 0.0
	rig.yaw = atan2(-rel.x, -rel.z)
	if rel.length() > 4.5:
		hero.move_input = Vector2(0, 1)
	else:
		hero.move_input = Vector2.ZERO
		hero.attack()
