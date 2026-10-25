extends Node3D

# Third-person camera behind the hero: mouse (or touch drag) rotates, scroll (or pinch) zooms.

const MIN_DIST: float = 3.5
const MAX_DIST: float = 16.0
const MIN_PITCH: float = -8.0
const MAX_PITCH: float = 70.0
const MOUSE_SENS: float = 0.0035
const TOUCH_SENS: float = 0.006
const FOLLOW: float = 12.0

var target: Node3D
var yaw: float = 0.0
var pitch: float = deg_to_rad(22.0)
var distance: float = 8.5
var camera: Camera3D
var shake: float = 0.0
var _touches: Dictionary = {}

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.2
	camera.far = 400.0
	add_child(camera)

func flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

func _process(delta: float) -> void:
	if target != null:
		global_position = global_position.lerp(target.global_position + Vector3(0, 1.5, 0), 1.0 - exp(-FOLLOW * delta))
	shake = maxf(0.0, shake - delta * 2.5)
	rotation = Vector3(-pitch, yaw, 0.0)
	camera.position = Vector3(0, 0, _clear_distance())
	if shake > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.35

func zoom(factor: float) -> void:
	distance = clampf(distance * factor, MIN_DIST, MAX_DIST)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch + event.relative.y * MOUSE_SENS, deg_to_rad(MIN_PITCH), deg_to_rad(MAX_PITCH))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.1)
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
			yaw -= event.relative.x * TOUCH_SENS
			pitch = clampf(pitch + event.relative.y * TOUCH_SENS, deg_to_rad(MIN_PITCH), deg_to_rad(MAX_PITCH))

# Pulls the camera in when a pillar would block the view of the hero.
func _clear_distance() -> float:
	var space := get_world_3d().direct_space_state
	var from: Vector3 = global_position
	var to: Vector3 = global_transform * Vector3(0, 0, distance)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return distance
	return maxf(1.2, from.distance_to(hit["position"]) - 0.4)
