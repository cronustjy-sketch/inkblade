extends Node3D

# 3D Boss Raid mode: a round toon arena, a third-person hero and a ladder of boss fights.

const Arena := preload("res://scripts/raid_arena.gd")
const HeroScript := preload("res://scripts/raid_hero.gd")
const CameraScript := preload("res://scripts/raid_camera.gd")
const MENU_SCENE: String = "res://scenes/menu.tscn"

var arena: Node3D
var hero: CharacterBody3D
var rig: Node3D
var hud: CanvasLayer

func _ready() -> void:
	_environment()
	arena = Node3D.new()
	arena.set_script(Arena)
	add_child(arena)
	arena.build()

	hero = CharacterBody3D.new()
	hero.set_script(HeroScript)
	hero.position = Vector3(0, 0.05, 8)
	add_child(hero)

	rig = Node3D.new()
	rig.set_script(CameraScript)
	add_child(rig)
	rig.target = hero
	rig.global_position = hero.position + Vector3(0, 1.5, 0)
	rig.yaw = 0.0
	rig.camera.make_current()

	_hud()
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

func _hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var hint := Label.new()
	hint.text = "WASD 移动 Move · 鼠标 视角 Look · 滚轮 缩放 Zoom · Esc 释放鼠标 Release mouse"
	hint.position = Vector2(16, 12)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 5)
	hud.add_child(hint)
	var back := Button.new()
	back.text = "返回 Back"
	back.focus_mode = Control.FOCUS_NONE
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	back.offset_right = -12.0
	back.offset_top = 10.0
	back.pressed.connect(_leave)
	hud.add_child(back)

func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)

func _process(_delta: float) -> void:
	var move := Vector2.ZERO
	move.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	move.y = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	hero.move_input = move
	hero.cam_yaw = rig.yaw

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# Dev helper: RAID_SHOT=<png> saves a screenshot after a moment and quits (debug builds only).
func _screenshot_later(path: String) -> void:
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
