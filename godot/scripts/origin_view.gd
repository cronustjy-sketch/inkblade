extends Control

# Plays the Origin 起源 video (media/origin.ogv, converted from the web game's origin.mp4). Esc / Skip / click closes it.

signal finished

const Kit := preload("res://scripts/ui_kit.gd")
const VIDEO: String = "res://media/origin.ogv"

var _player: VideoStreamPlayer
var _done: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_player = VideoStreamPlayer.new()
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.expand = true
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(VIDEO):
		_player.stream = load(VIDEO)
	add_child(_player)
	_player.finished.connect(_close)
	var skip: Button = Kit.pill("跳过", "Skip", Kit.CREAM, Vector2(130, 46), _close, 18)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -20.0
	skip.offset_top = 18.0
	add_child(skip)
	if _player.stream == null:
		Kit.message_box(self, "起源", "Origin", "视频文件缺失。", "The video file is missing.")
	else:
		_player.play()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	if _done:
		return
	_done = true
	if _player != null:
		_player.stop()
	finished.emit()
	queue_free()
