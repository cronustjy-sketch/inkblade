extends Node3D

# 3D Boss Raid mode: a round toon arena, a third-person hero and a ladder of boss fights.
# Part 2 state: free practice against a training dummy (the boss ladder replaces it in part 3).

const Arena := preload("res://scripts/raid_arena.gd")
const HeroScript := preload("res://scripts/raid_hero.gd")
const CameraScript := preload("res://scripts/raid_camera.gd")
const HudScript := preload("res://scripts/raid_hud.gd")
const DummyScript := preload("res://scripts/raid_dummy.gd")
const MENU_SCENE: String = "res://scenes/menu.tscn"
const SKILL_KEYS: Dictionary = {KEY_Q: "slash", KEY_E: "dash", KEY_R: "rally", KEY_F: "rain"}
const START_POS := Vector3(0, 0.05, 9)

var arena: Node3D
var hero: CharacterBody3D
var rig: Node3D
var hud: CanvasLayer
var dummy: Node3D
var over: bool = false

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
	hud.attack_pressed.connect(hero.attack)
	hud.dodge_pressed.connect(hero.dodge)
	hud.skill_pressed.connect(func(id: String) -> void: hero.cast(id))
	hud.menu_pressed.connect(_leave)
	hud.retry_pressed.connect(_retry)
	hero.damaged.connect(_on_hero_damaged)
	hero.died.connect(_on_hero_died)
	hud.set_hero_hp(hero.hp, hero.max_hp)
	hud.show_touch(DisplayServer.is_touchscreen_available())

	dummy = Node3D.new()
	dummy.set_script(DummyScript)
	add_child(dummy)
	dummy.position = Vector3(0, 0, -8)
	dummy.hero = hero

	var shot: String = OS.get_environment("RAID_SHOT")
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

func _process(_delta: float) -> void:
	var move := Vector2.ZERO
	move.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	move.y = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	if hud.joystick.length() > 0.05:
		move = hud.joystick
	hero.move_input = move
	hero.cam_yaw = rig.yaw
	hud.update_skills(hero)

func _unhandled_input(event: InputEvent) -> void:
	if over:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			hero.attack()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_SPACE:
			hero.dodge()
		elif event.keycode == KEY_F10:
			hud.show_touch(not hud.is_touch_shown())
		elif SKILL_KEYS.has(event.keycode):
			hero.cast(SKILL_KEYS[event.keycode])

func _on_hero_damaged(amount: float) -> void:
	hud.set_hero_hp(hero.hp, hero.max_hp)
	if amount > 0.0:
		hud.flash_damage()
		rig.shake = 0.5

func _on_hero_died() -> void:
	over = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_result(false, 0.0, 0.0, false, "训练木桩 Training Dummy")

func _retry() -> void:
	get_tree().reload_current_scene()

func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)

# Dev helper: RAID_SHOT=<png> saves a screenshot after a moment and quits (debug builds only).
# RAID_ACT=attack|skills|telegraph stages something to look at first.
func _screenshot_later(path: String) -> void:
	var act: String = OS.get_environment("RAID_ACT")
	if act == "attack":
		hero.position = Vector3(0, 0.05, -5.5)
		rig.yaw = PI
		await get_tree().create_timer(1.0).timeout
		hero.attack()
		await get_tree().create_timer(0.3).timeout
	elif act == "skills":
		hero.position = Vector3(0, 0.05, -4.0)
		await get_tree().create_timer(0.8).timeout
		hero.cast("rain")
		await get_tree().create_timer(1.0).timeout
	elif act == "telegraph":
		dummy.attack_enabled = false
		const Telegraph := preload("res://scripts/telegraph.gd")
		Telegraph.circle(self, hero.global_position + Vector3(0, 0, -3), 4.0, 5.0, 30.0, hero)
		Telegraph.line(self, Vector3(-8, 0, -2), Vector3(1, 0, 0), 16.0, 2.5, 5.0, 30.0, hero)
		Telegraph.cone(self, Vector3(8, 0, 4), Vector3(-1, 0, -1), 80.0, 7.0, 5.0, 30.0, hero)
		await get_tree().create_timer(2.5).timeout
	else:
		await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
