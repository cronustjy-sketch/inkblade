extends Node3D

const Levels := preload("res://data/levels.gd")
const Save := preload("res://scripts/save.gd")
const BossData := preload("res://data/bosses.gd")
const UnitData := preload("res://data/units.gd")
const Progress := preload("res://data/progress.gd")
const PLAYER_CASTLE_X: float = 0.0
const ENEMY_CASTLE_X: float = 40.0
const CAM_FOV: float = 24.0 # narrow lens + long distance = nearly flat side-on view
const CAM_HEIGHT: float = 6.0
const CAM_DISTANCE: float = 47.0
const CAM_FOLLOW: float = 5.0
const CAM_LOOK_Y: float = 5.6 # looking above the ground puts the lane in the bottom third of the screen
const CAM_MIN_X: float = 14.0
const CAM_MAX_X: float = 26.0
const ZOOM_MIN: float = 0.45 # hero close-up
const ZOOM_MAX: float = 1.7 # the whole lane
const ZOOM_STEP: float = 1.12
const TILT_MIN: float = -0.15
const TILT_MAX: float = 0.7
const TILT_SPEED: float = 0.004
const CASTLE_Z: float = 0.4 # the statue stands in front of the spawn point
const LANES: Array[float] = [-2.0, -0.7, 0.6, 1.9, 3.2] # units spread over several lanes so the army looks like a crowd
const CRUMBLE_DELAY: float = 1.8
const IMPLEMENTED_SKILLS: Array[String] = ["slash", "dash", "rally", "rain", "special"]
const Fx := preload("res://scripts/fx.gd")
const MAX_ENERGY: float = 200.0
const ENERGY_REGEN: float = 10.0
const MAX_POP: int = 50
const UNIT_SCENE: PackedScene = preload("res://scenes/unit.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/hud.tscn")
const SPAWNER_SCRIPT: GDScript = preload("res://scripts/spawner.gd")
const HERO_SCENE: PackedScene = preload("res://scenes/hero.tscn")
const BACKDROP_SCRIPT: GDScript = preload("res://scripts/backdrop.gd")
const AUTOSHOT_SCRIPT: GDScript = preload("res://scripts/autoshot.gd")
const MAP_SCENE: String = "res://scenes/map.tscn"

@export var start_level: int = 1

@onready var camera: Camera3D = $Camera3D
@onready var player_castle: Node3D = $PlayerCastle
@onready var enemy_castle: Node3D = $EnemyCastle

var level: int = 1
var cam_x: float = 6.0
var energy: float = 0.0
var mods: Dictionary = {} # permanent upgrades (data/progress.gd), read once per battle
var max_pop: int = MAX_POP
var rage_t: float = 0.0 # Rage spell: army attack +50%
var wall_t: float = 0.0 # knight skill: army takes less damage while this runs
var hud: CanvasLayer
var hero: Node3D
var spawner: Node
var order: int = UnitData.ORDER_ATTACK
var controlled: Node3D
var ink: float = 0.0
var rally_t: float = 0.0
var _shake_t: float = 0.0
var boss: Node3D
var _boss_alive: bool = false
var zoom: float = 1.0 # current camera zoom (smoothed)
var zoom_target: float = 1.0
var tilt: float = 0.0 # extra camera height as a fraction of the distance
var _tilt_drag: bool = false
var _touches: Dictionary = {}
var _over: bool = false

func _ready() -> void:
	mods = Progress.mods()
	for potion: String in Progress.drink_potions():
		match potion:
			"p_energy":
				mods["start_energy"] = float(mods["start_energy"]) + 80.0
			"p_hp":
				mods["base_hp"] = float(mods["base_hp"]) * 1.5
			"p_atk":
				mods["atk"] = float(mods["atk"]) * 1.25
			"p_speed":
				mods["spd"] = float(mods["spd"]) * 1.3
	max_pop = int(mods["cap"])
	energy = float(mods["start_energy"])
	# Retry / Next level reload this scene, so the level lives in a static var.
	var env_level: String = OS.get_environment("INK_LEVEL")
	if env_level != "" and OS.is_debug_build():
		Levels.current_level = clampi(int(env_level), 1, Levels.MAX_LEVEL)
	if Levels.current_level == 0:
		Levels.current_level = start_level
	level = Levels.current_level
	if OS.is_debug_build() and OS.get_environment("INK_ZOOM") != "":
		set_zoom(float(OS.get_environment("INK_ZOOM")))
		zoom = zoom_target
	tilt = float(OS.get_environment("INK_TILT")) if OS.is_debug_build() else 0.0

	player_castle.position = Vector3(PLAYER_CASTLE_X, 0.0, CASTLE_Z)
	enemy_castle.position = Vector3(ENEMY_CASTLE_X, 0.0, CASTLE_Z)
	# Castles set hp from max_hp in their own _ready, which already ran.
	player_castle.max_hp = mods["base_hp"]
	player_castle.hp = player_castle.max_hp
	enemy_castle.max_hp = Levels.enemy_castle_hp(level)
	enemy_castle.hp = enemy_castle.max_hp
	player_castle.destroyed.connect(_on_castle_destroyed)
	enemy_castle.destroyed.connect(_on_castle_destroyed)

	camera.fov = CAM_FOV
	camera.far = 900.0
	var backdrop: Node3D = Node3D.new()
	backdrop.set_script(BACKDROP_SCRIPT)
	add_child(backdrop)
	backdrop.build(level, camera, ENEMY_CASTLE_X * 0.5)
	backdrop.style_ground($Ground, level)
	if BossData.has_boss(level):
		enemy_castle.set_invulnerable(true)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(level, MAX_ENERGY, max_pop, _unlocked_skills())
	hud.skill_requested.connect(_on_skill_requested)
	hud.order_requested.connect(set_order)
	hud.ult_requested.connect(cast_ultimate)
	hud.show_orders()
	hud.set_order(order)
	hud.spawn_requested.connect(_on_spawn_requested)
	hud.retry_requested.connect(_on_retry)
	hud.next_level_requested.connect(_on_next_level)
	hud.growth_picked.connect(Progress.add_growth)
	hud.spell_requested.connect(cast_spell)
	hud.set_spells(_spell_counts())
	hud.map_requested.connect(_on_map)

	hero = HERO_SCENE.instantiate()
	hero.setup(self, level)
	hero.position = Vector3(6.0, 0.0, 0.0)
	add_child(hero)
	cam_x = hero.position.x

	spawner = SPAWNER_SCRIPT.new()
	add_child(spawner)
	spawner.setup(self, level)

	if OS.is_debug_build():
		var shot: Node = AUTOSHOT_SCRIPT.new()
		add_child(shot)
		shot.setup(self)

func _process(delta: float) -> void:
	energy = minf(MAX_ENERGY, energy + float(mods["regen"]) * delta)
	wall_t = maxf(0.0, wall_t - delta)
	rage_t = maxf(0.0, rage_t - delta)
	hud.update_state(energy, player_pop())

	hud.update_skills(hero)
	hud.update_castles(player_castle.hp, player_castle.max_hp, enemy_castle.hp, enemy_castle.max_hp)
	hud.update_ink(ink, UnitData.ULT_MAX)
	_track_boss()
	rally_t = maxf(0.0, rally_t - delta)
	_shake_t = maxf(0.0, _shake_t - delta)
	_validate_control()
	hero.move(0.0 if controlled != null else move_axis(), delta)

	# Camera follows the hero, clamped between the castles.
	var follow: Node3D = controlled if controlled != null else hero
	# Zoomed out, the camera settles on the middle of the lane instead of following into the castles.
	zoom = lerpf(zoom, zoom_target, 1.0 - exp(-10.0 * delta))
	var spread: float = clampf((zoom - 1.0) / 0.45, 0.0, 1.0)
	var mid_x: float = ENEMY_CASTLE_X * 0.5
	var extra: float = maxf(0.0, 1.0 - zoom) * 22.0 # zoomed in, the camera may follow the hero all the way to the statues
	var target_x: float = clampf(follow.position.x, lerpf(CAM_MIN_X, mid_x, spread) - extra, lerpf(CAM_MAX_X, mid_x, spread) + extra)
	cam_x = lerpf(cam_x, target_x, 1.0 - exp(-CAM_FOLLOW * delta))
	var dist: float = CAM_DISTANCE * zoom
	var cam_height: float = CAM_HEIGHT * pow(zoom, 0.6) + tilt * 8.0
	camera.position = Vector3(cam_x, cam_height, dist)
	if _shake_t > 0.0:
		camera.position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake_t * 0.5
	camera.look_at(Vector3(cam_x, CAM_LOOK_Y * pow(zoom, 0.6) + tilt * 4.0, 0.0), Vector3.UP)

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
		u.apply_mods(mods)
	if team == 0:
		u.battle = self
	add_child(u)
	var side: float = 1.0 if team == 0 else -1.0
	# Units come out from behind their statue (farther from the camera than the statue sprite).
	u.position = Vector3(own.position.x + side * 0.3, 0.0, -2.0)
	u.lane_z = LANES[randi() % LANES.size()] if UnitData.UNITS[key]["pop"] < 3 else randf_range(0.2, 1.0)
	return u

func _on_spawn_requested(key: String) -> void:
	var d: Dictionary = UnitData.UNITS[key]
	if energy < d["cost"] or player_pop() + int(d["pop"]) > max_pop:
		return
	energy -= d["cost"]
	spawn_unit(0, key)

func _on_castle_destroyed(team: int) -> void:
	if _over:
		return
	_over = true
	var won: bool = team == 1
	var first: bool = won and level > Levels.highest_cleared()
	var reward: int = 10
	if won:
		var frac: float = player_castle.hp / player_castle.max_hp
		var stars: int = 3 if frac > 0.7 else (2 if frac > 0.35 else 1)
		reward = Progress.win_reward(level, first, stars, BossData.has_boss(level))
		Levels.mark_cleared(level)
	Progress.add_coins(reward)
	# Let the statue crumble on screen before the result panel pauses the game.
	await get_tree().create_timer(CRUMBLE_DELAY).timeout
	if not is_inside_tree():
		return
	get_tree().paused = true
	hud.show_result(won, level, level < Levels.MAX_LEVEL, reward, first)

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
		KEY_SPACE:
			cast_ultimate()
		KEY_H:
			release_control()
		KEY_C:
			reset_camera()
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
	if OS.is_debug_build() and OS.get_environment("INK_AUTOSHOT") != "":
		return # screenshot runs ignore stray mouse input
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_pick_unit_at(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom_target / ZOOM_STEP)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom_target * ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_tilt_drag = event.pressed
	elif event is InputEventMouseMotion and _tilt_drag:
		tilt = clampf(tilt + event.relative.y * TILT_SPEED, TILT_MIN, TILT_MAX)
	elif event is InputEventMagnifyGesture:
		set_zoom(zoom_target / event.factor)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		_pinch(event)

func set_zoom(value: float) -> void:
	zoom_target = clampf(value, ZOOM_MIN, ZOOM_MAX)

func reset_camera() -> void:
	zoom_target = 1.0
	tilt = 0.0

# Two-finger pinch on a touch screen: spreading the fingers zooms in.
func _pinch(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var before: float = 0.0
	if _touches.size() == 2:
		var pts: Array = _touches.values()
		before = (pts[0] as Vector2).distance_to(pts[1])
	_touches[event.index] = event.position
	if _touches.size() == 2 and before > 1.0:
		var pts: Array = _touches.values()
		var after: float = (pts[0] as Vector2).distance_to(pts[1])
		set_zoom(zoom_target * before / maxf(after, 1.0))

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

# ---------- ink meter and the ultimate (墨刃·终) ----------

func add_ink(amount: float, from_hero: bool = true) -> void:
	var rate: float = UnitData.INK_PER_DAMAGE_HERO if from_hero else UnitData.INK_PER_DAMAGE_ARMY
	ink = minf(UnitData.ULT_MAX, ink + amount * rate * float(mods["ink"]))

# Screen-wide strike: everything in view takes heavy damage.
func cast_ultimate() -> bool:
	if ink < UnitData.ULT_MAX or hero.is_dead() or _over:
		return false
	ink = 0.0
	var half: float = UnitData.ULT_VIEW_HALF_WIDTH
	for u: Node3D in get_tree().get_nodes_in_group("team_1"):
		if u.is_queued_for_deletion() or u.inside or absf(u.global_position.x - cam_x) > half:
			continue
		u.take_damage(UnitData.ULT_DAMAGE)
		Fx.slash_wave(self, u.global_position + Vector3(-1.5, 0.0, 0.0), 1.0, 3.0)
	if absf(enemy_castle.global_position.x - cam_x) <= half + 3.2:
		enemy_castle.take_damage(UnitData.ULT_CASTLE_DAMAGE)
	Fx.slash_wave(self, Vector3(cam_x - half, 2.0, 0.0), 1.0, half * 2.0)
	hud.flash()
	shake_camera(0.5)
	return true

# ---------- boss ----------

func spawn_boss() -> void:
	if _boss_alive or not BossData.has_boss(level):
		return
	_boss_alive = true
	boss = UNIT_SCENE.instantiate()
	boss.setup_boss(level, player_castle)
	add_child(boss)
	boss.position = Vector3(enemy_castle.position.x - 0.5, 0.0, -1.5)
	var b: Dictionary = BossData.for_level(level)
	hud.show_boss(b["name_cn"], b["name_en"], b["hp"])
	hud.show_boss_banner(b["name_cn"], b["name_en"], b.get("taunt", ""), b.get("taunt_en", ""))
	shake_camera(0.5)

# Keeps the boss bar in sync and drops the castle ward when the boss dies.
func _track_boss() -> void:
	if not _boss_alive:
		return
	if is_instance_valid(boss) and not boss.is_queued_for_deletion():
		hud.update_boss(boss.hp)
		return
	_boss_alive = false
	boss = null
	hud.hide_boss()
	enemy_castle.set_invulnerable(false)

func _on_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAP_SCENE)

# Screen shake, unless the player turned it off in Settings.
func shake_camera(amount: float) -> void:
	if Save.camera_shake():
		_shake_t = maxf(_shake_t, amount)

# ---------- shop spells (bought in 商店, one use each) ----------

func _spell_counts() -> Dictionary:
	var out: Dictionary = {}
	for id: String in Progress.SPELL_ORDER:
		out[id] = Progress.spells(id)
	return out

func _enemy_units() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for u: Node3D in get_tree().get_nodes_in_group("team_1"):
		if not u.is_queued_for_deletion() and not u.inside:
			out.append(u)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	return out

func cast_spell(id: String) -> bool:
	if _over or not Progress.use_spell(id):
		return false
	var front: float = ENEMY_CASTLE_X - 4.0
	var foes: Array[Node3D] = _enemy_units()
	if foes.size() > 0:
		front = foes[0].global_position.x
	var power: float = float(mods["skill_atk"])
	match id:
		"bolt":
			for i in mini(4, foes.size()):
				foes[i].take_damage(224.0 * power * (0.6 if foes[i].key == "boss" else 1.0))
				Fx.ring(self, foes[i].global_position, 1.5, Color("ffe95a"), 0.4)
			shake_camera(0.5)
		"volley":
			for i in 12:
				get_tree().create_timer(0.25 * i).timeout.connect(_area_hit.bind(front - 1.0, front + 6.0, 14.0 * power, Color("9ad0ff")))
		"rage":
			rage_t = 8.0
			rally_t = maxf(rally_t, 8.0)
		"aegis":
			wall_t = maxf(wall_t, 6.0)
		"frost":
			for u: Node3D in foes:
				if not u.flying:
					u.stun_t = 1.2 if u.key == "boss" else 3.0
		"surge":
			energy = minf(MAX_ENERGY, energy + 100.0)
		"plague":
			for i in 10:
				get_tree().create_timer(0.5 * i).timeout.connect(_area_hit.bind(front - 1.0, front + 5.0, 20.0 * power, Color("9be37a")))
		"reinf":
			for i in 5:
				spawn_unit(0, "soldier")
			spawn_unit(0, "giant")
		"meteor":
			for i in 12:
				get_tree().create_timer(0.12 * i + 0.3).timeout.connect(_meteor_at.bind(front + randf_range(-1.0, 9.0), 60.0 * power))
	hud.set_spells(_spell_counts())
	return true

func _area_hit(lo: float, hi: float, dmg: float, color: Color) -> void:
	for u: Node3D in _enemy_units():
		if u.global_position.x >= lo and u.global_position.x <= hi:
			u.take_damage(dmg)
	Fx.ring(self, Vector3((lo + hi) * 0.5, 0.0, 0.0), (hi - lo) * 0.5, color, 0.25)

func _meteor_at(x: float, dmg: float) -> void:
	for u: Node3D in _enemy_units():
		if absf(u.global_position.x - x) <= 2.5 and not u.flying:
			u.take_damage(dmg)
	Fx.ring(self, Vector3(x, 0.0, 0.0), 2.5, Color("ff5a3a"), 0.4)
