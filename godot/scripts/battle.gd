extends Node3D

const Levels := preload("res://data/levels.gd")
const UnitData := preload("res://data/units.gd")
const PLAYER_CASTLE_X: float = 0.0
const ENEMY_CASTLE_X: float = 40.0
const CAM_HEIGHT: float = 10.0
const CAM_DISTANCE: float = 28.0
const CAM_FOLLOW: float = 5.0
const IMPLEMENTED_SKILLS: Array[String] = ["slash"]
const MAX_ENERGY: float = 200.0
const ENERGY_REGEN: float = 10.0
const MAX_POP: int = 50
const UNIT_SCENE: PackedScene = preload("res://scenes/unit.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/hud.tscn")
const SPAWNER_SCRIPT: GDScript = preload("res://scripts/spawner.gd")
const HERO_SCENE: PackedScene = preload("res://scenes/hero.tscn")
const DECOR_SCRIPT: GDScript = preload("res://scripts/decor.gd")

@export var start_level: int = 1

@onready var camera: Camera3D = $Camera3D
@onready var player_castle: Node3D = $PlayerCastle
@onready var enemy_castle: Node3D = $EnemyCastle

var level: int = 1
var cam_x: float = 6.0
var energy: float = 0.0
var hud: CanvasLayer
var hero: Node3D
var spawner: Node
var order: int = UnitData.ORDER_ATTACK
var controlled: Node3D
var _over: bool = false

func _ready() -> void:
	# Retry / Next level reload this scene, so the level lives in a static var.
	if Levels.current_level == 0:
		Levels.current_level = start_level
	level = Levels.current_level

	player_castle.position.x = PLAYER_CASTLE_X
	enemy_castle.position.x = ENEMY_CASTLE_X
	# Castles set hp from max_hp in their own _ready, which already ran.
	player_castle.max_hp = 500.0
	player_castle.hp = 500.0
	enemy_castle.max_hp = Levels.enemy_castle_hp(level)
	enemy_castle.hp = enemy_castle.max_hp
	player_castle.destroyed.connect(_on_castle_destroyed)
	enemy_castle.destroyed.connect(_on_castle_destroyed)

	var decor: Node3D = Node3D.new()
	decor.set_script(DECOR_SCRIPT)
	add_child(decor)
	decor.build($Ground, ENEMY_CASTLE_X)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(level, MAX_ENERGY, MAX_POP, _unlocked_skills())
	hud.skill_requested.connect(_on_skill_requested)
	hud.order_requested.connect(set_order)
	hud.show_orders()
	hud.set_order(order)
	hud.spawn_requested.connect(_on_spawn_requested)
	hud.retry_requested.connect(_on_retry)
	hud.next_level_requested.connect(_on_next_level)

	hero = HERO_SCENE.instantiate()
	hero.setup(self, level)
	hero.position = Vector3(6.0, 0.0, 0.0)
	add_child(hero)
	cam_x = hero.position.x

	spawner = SPAWNER_SCRIPT.new()
	add_child(spawner)
	spawner.setup(self, level)

func _process(delta: float) -> void:
	energy = minf(MAX_ENERGY, energy + ENERGY_REGEN * delta)
	hud.update_state(energy, player_pop())

	hud.update_skills(hero)
	_validate_control()
	hero.move(0.0 if controlled != null else move_axis(), delta)

	# Camera follows the hero, clamped between the castles.
	var follow: Node3D = controlled if controlled != null else hero
	var target_x: float = clampf(follow.position.x, PLAYER_CASTLE_X, ENEMY_CASTLE_X)
	cam_x = lerpf(cam_x, target_x, 1.0 - exp(-CAM_FOLLOW * delta))
	camera.position = Vector3(cam_x, CAM_HEIGHT, CAM_DISTANCE)
	camera.look_at(Vector3(cam_x, 1.5, 0.0), Vector3.UP)

# -1 / 0 / +1 from the arrow keys or A / D.
func move_axis() -> float:
	var axis: float = Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_D):
		axis += 1.0
	return clampf(axis, -1.0, 1.0)

func _unlocked_skills() -> Array[String]:
	var out: Array[String] = []
	for id: String in IMPLEMENTED_SKILLS:
		if UnitData.HERO_SKILLS[id]["unlock"] <= level:
			out.append(id)
	return out

func _on_skill_requested(id: String) -> void:
	hero.cast(id)

func player_pop() -> int:
	var total: int = 0
	for u: Node3D in get_tree().get_nodes_in_group("team_0"):
		if not u.is_queued_for_deletion():
			total += u.pop
	return total

func spawn_unit(team: int, key: String, stat_mult: float = 1.0) -> Node3D:
	var u: Node3D = UNIT_SCENE.instantiate()
	var own: Node3D = player_castle if team == 0 else enemy_castle
	var foe: Node3D = enemy_castle if team == 0 else player_castle
	u.setup(team, key, foe, stat_mult)
	if team == 0:
		u.battle = self
	add_child(u)
	var side: float = 1.0 if team == 0 else -1.0
	var z_spread: float = 0.4 if UnitData.UNITS[key]["pop"] >= 3 else 1.0
	u.position = Vector3(own.position.x + side * 4.2, 0.0, randf_range(-z_spread, z_spread))
	return u

func _on_spawn_requested(key: String) -> void:
	var d: Dictionary = UnitData.UNITS[key]
	if energy < d["cost"] or player_pop() + int(d["pop"]) > MAX_POP:
		return
	energy -= d["cost"]
	spawn_unit(0, key)

func _on_castle_destroyed(team: int) -> void:
	if _over:
		return
	_over = true
	var won: bool = team == 1
	get_tree().paused = true
	hud.show_result(won, level, level < Levels.MAX_LEVEL)

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_next_level() -> void:
	Levels.current_level = level + 1
	get_tree().paused = false
	get_tree().reload_current_scene()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	for id: String in IMPLEMENTED_SKILLS:
		if event.keycode == OS.find_keycode_from_string(UnitData.HERO_SKILLS[id]["key"]):
			hero.cast(id)
			return
	match event.keycode:
		KEY_TAB:
			cycle_control()
			get_viewport().set_input_as_handled()
		KEY_H:
			release_control()
		KEY_1:
			set_order(UnitData.ORDER_ATTACK)
		KEY_2:
			set_order(UnitData.ORDER_DEFEND)
		KEY_3:
			set_order(UnitData.ORDER_RETREAT)
		_:
			_debug_key(event.keycode)

# Debug only: F1 wins the level, F2 loses it, F3 / F4 preview hero animations.
func _debug_key(keycode: Key) -> void:
	if not OS.is_debug_build():
		return
	if keycode == KEY_F1:
		enemy_castle.take_damage(enemy_castle.hp)
	elif keycode == KEY_F2:
		player_castle.take_damage(player_castle.hp)
	elif keycode == KEY_F3:
		hero.play("run")
	elif keycode == KEY_F4:
		hero.play("slash1", 0.5)

# ---------- orders and take-control ----------

func set_order(new_order: int) -> void:
	order = new_order
	hud.set_order(order)

func control(unit: Node3D) -> void:
	if controlled != null and is_instance_valid(controlled):
		controlled.set_controlled(false)
	controlled = unit
	unit.set_controlled(true)
	var d: Dictionary = unit.data
	hud.set_control_text("控制中 Controlling: %s %s   (Tab 切换 / H 英雄 Hero)" % [d["name_cn"], d["name_en"]])

func release_control() -> void:
	if controlled != null and is_instance_valid(controlled):
		controlled.set_controlled(false)
	controlled = null
	hud.set_control_text("")

func _validate_control() -> void:
	if controlled != null and (not is_instance_valid(controlled) or controlled.is_queued_for_deletion() or controlled.inside):
		release_control()

# Player soldiers (not the hero) that can be controlled, left to right.
func controllable_units() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for u: Node3D in get_tree().get_nodes_in_group("units"):
		if u.team == 0 and not u.is_queued_for_deletion() and not u.inside:
			out.append(u)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.x < b.position.x)
	return out

func cycle_control() -> void:
	var list: Array[Node3D] = controllable_units()
	if list.is_empty():
		release_control()
		return
	var idx: int = list.find(controlled)
	control(list[(idx + 1) % list.size()])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_unit_at(event.position)

# Picks the soldier whose on-screen body is nearest to the click.
func _pick_unit_at(screen_pos: Vector2) -> void:
	var best: Node3D = null
	var best_dist: float = 48.0
	for u: Node3D in controllable_units():
		var p: Vector2 = camera.unproject_position(u.global_position + Vector3(0, 0.9, 0))
		var d: float = p.distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best = u
	if best != null:
		control(best)
	else:
		var hp: Vector2 = camera.unproject_position(hero.global_position + Vector3(0, 1.0, 0))
		if hp.distance_to(screen_pos) < best_dist:
			release_control()
