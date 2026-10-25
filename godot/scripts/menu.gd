extends Control

# Main menu: the 2D campaign or the 3D Boss Raid.

const MAP_SCENE: String = "res://scenes/map.tscn"
const RAID_SCENE: String = "res://scenes/raid.tscn"
const OUTLINE := Color("0d0d12")
const GOLD := Color("f2b632")
const SKY := Color("9fd8ff")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color("3d9be9"), Color("c4ecff")])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var scenery := Control.new()
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scenery.draw.connect(_draw_scenery.bind(scenery))
	scenery.resized.connect(scenery.queue_redraw)
	add_child(scenery)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var title: Label = _outlined("墨刃纪元", 88, Color.WHITE, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle: Label = _outlined("Ink Blade Era", 32, GOLD, 8)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	box.add_child(gap)
	box.add_child(_button("战役  Campaign", GOLD, _on_campaign))
	box.add_child(_button("3D 首领突袭  Boss Raid", SKY, _on_raid))

	var credit: Label = _outlined("作者 Junyuan  ·  by Junyuan", 16, Color.WHITE, 5)
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credit.offset_left = 18.0
	credit.offset_bottom = -12.0
	add_child(credit)

func _on_campaign() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)

func _on_raid() -> void:
	get_tree().change_scene_to_file(RAID_SCENE)

func _draw_scenery(canvas: Control) -> void:
	var canvas_size: Vector2 = canvas.size
	canvas.draw_circle(Vector2(canvas_size.x * 0.78, canvas_size.y * 0.24), canvas_size.y * 0.13, Color("fff2a8"))
	var layers: Array = [[Color("9bd6b0"), 0.62, 0.10, 3.0], [Color("6cbf74"), 0.72, 0.09, 4.5], [Color("49a25a"), 0.84, 0.07, 6.0]]
	for i in layers.size():
		var layer: Array = layers[i]
		var pts := PackedVector2Array()
		var steps: int = 60
		for s in steps + 1:
			var x: float = canvas_size.x * s / steps
			var y: float = canvas_size.y * (layer[1] - layer[2] * (0.5 + 0.5 * sin(x / canvas_size.x * layer[3] * TAU * 0.5 + i * 1.7)))
			pts.append(Vector2(x, y))
		var poly := PackedVector2Array(pts)
		poly.append(Vector2(canvas_size.x, canvas_size.y))
		poly.append(Vector2(0.0, canvas_size.y))
		canvas.draw_colored_polygon(poly, layer[0])
		canvas.draw_polyline(pts, Color("1b3a2a"), 4.0, true)

func _button(text: String, fill: Color, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(380, 66)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", OUTLINE)
	b.add_theme_color_override("font_hover_color", OUTLINE)
	b.add_theme_stylebox_override("normal", _flat(fill))
	b.add_theme_stylebox_override("hover", _flat(fill.lightened(0.25)))
	b.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.15)))
	b.pressed.connect(action)
	return b

func _flat(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = OUTLINE
	s.set_border_width_all(5)
	s.set_corner_radius_all(33)
	s.anti_aliasing = true
	return s

func _outlined(text: String, font_size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	return l
