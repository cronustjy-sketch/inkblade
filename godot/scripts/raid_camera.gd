extends Node3D

# Third-person camera behind the hero: mouse (or touch drag) rotates, scroll (or pinch) zooms.
# Lock-on (Tab / middle mouse) swings the camera behind the hero toward the boss and pulls back so both stay in frame.
# Walls and pillars between the camera and the hero fade out (arena.fade_items).

const MIN_DIST: float = 4.0
const MAX_DIST: float = 26.0
const MIN_PITCH: float = -8.0
const MAX_PITCH: float = 70.0
const MOUSE_SENS: float = 0.0035
const TOUCH_SENS: float = 0.006
const FOLLOW: float = 12.0
const DEFAULT_PITCH_DEG: float = 25.0
const DEFAULT_DISTANCE: float = 14.0
const FADED_ALPHA: float = 0.12
const FADE_SPEED: float = 9.0

var target: Node3D
var lock_target: Node3D
var arena: Node3D
var locked: bool = false
var yaw: float = 0.0
var pitch: float = deg_to_rad(DEFAULT_PITCH_DEG)
var distance: float = DEFAULT_DISTANCE
var camera: Camera3D
var shake: float = 0.0
var _touches: Dictionary = {}
var _focus: Vector3 = Vector3.ZERO
var _extra_dist: float = 0.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.2
	camera.far = 500.0
	add_child(camera)

func flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

func toggle_lock() -> void:
	locked = not locked

func reset_view() -> void:
	locked = false
	pitch = deg_to_rad(DEFAULT_PITCH_DEG)
	distance = DEFAULT_DISTANCE

func _process(delta: float) -> void:
	var follow_point := Vector3.ZERO
	var extra: float = 0.0
	if target != null:
		follow_point = target.global_position + Vector3(0, 1.5, 0)
	if locked and lock_target != null and is_instance_valid(lock_target) and "alive" in lock_target and lock_target.alive:
		var rel := Vector3(lock_target.global_position.x - target.global_position.x, 0.0, lock_target.global_position.z - target.global_position.z)
		var sep: float = rel.length()
		if sep > 0.5:
			yaw = lerp_angle(yaw, atan2(-rel.x, -rel.z), 1.0 - exp(-6.0 * delta))
		# Aim between the two fighters, leaning toward the hero, and back off as they move apart.
		follow_point += rel * 0.38
		follow_point.y += lock_target.global_position.y * 0.6 # a flying boss lifts the frame
		extra = clampf(sep * 0.55, 0.0, 14.0)
	else:
		locked = false
	_extra_dist = lerpf(_extra_dist, extra, 1.0 - exp(-4.0 * delta))
	_focus = _focus.lerp(follow_point, 1.0 - exp(-FOLLOW * delta))
	global_position = _focus
	shake = maxf(0.0, shake - delta * 2.5)
	rotation = Vector3(-pitch, yaw, 0.0)
	camera.position = Vector3(0, 0, distance + _extra_dist)
	if shake > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.35
	_fade_occluders(delta)

# Anything big that sits between the camera and the hero becomes see-through.
func _fade_occluders(delta: float) -> void:
	if arena == null or target == null:
		return
	var from: Vector3 = camera.global_position
	var to: Vector3 = target.global_position + Vector3(0, 1.2, 0)
	var seg: Vector3 = to - from
	var seg_len2: float = maxf(seg.length_squared(), 0.001)
	for item: Dictionary in arena.fade_items:
		var p: Vector3 = item["pos"]
		var t: float = clampf((p - from).dot(seg) / seg_len2, 0.0, 1.0)
		var closest: Vector3 = from + seg * t
		var blocking: bool = t < 0.97 and closest.distance_to(p) < float(item["radius"])
		var want: float = FADED_ALPHA if blocking else 1.0
		var alpha: float = move_toward(float(item["alpha"]), want, FADE_SPEED * delta)
		if not is_equal_approx(alpha, float(item["alpha"])):
			item["alpha"] = alpha
			for m: ShaderMaterial in item["mats"]:
				_set_alpha(m, alpha)

func _set_alpha(m: ShaderMaterial, value: float) -> void:
	m.set_shader_parameter("alpha", value)
	if m.next_pass is ShaderMaterial:
		(m.next_pass as ShaderMaterial).set_shader_parameter("alpha", value)

func zoom(factor: float) -> void:
	distance = clampf(distance * factor, MIN_DIST, MAX_DIST)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not locked:
			yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch + event.relative.y * MOUSE_SENS, deg_to_rad(MIN_PITCH), deg_to_rad(MAX_PITCH))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.1)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			toggle_lock()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			toggle_lock()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C:
			reset_view()
	elif event is InputEventMagnifyGesture:
		zoom(1.0 / event.factor)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag and _touches.has(event.index):
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var before: float = (pts[0] as Vector2).distance_to(pts[1])
			_touches[event.index] = event.position
			pts = _touches.values()
			var after: float = (pts[0] as Vector2).distance_to(pts[1])
			if before > 1.0:
				zoom(before / maxf(after, 1.0))
		else:
			_touches[event.index] = event.position
			if not locked:
				yaw -= event.relative.x * TOUCH_SENS
			pitch = clampf(pitch + event.relative.y * TOUCH_SENS, deg_to_rad(MIN_PITCH), deg_to_rad(MAX_PITCH))
