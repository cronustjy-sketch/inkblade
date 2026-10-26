extends Control

# The opening story (STORY from the web game): four illustrated pages with Next / Skip, Chinese with English
# underneath. Emits `finished` when the player reaches the end or skips. Save.intro_seen is set by the caller.

signal finished

const Kit := preload("res://scripts/ui_kit.gd")
const StoryData := preload("res://data/story_data.gd")
const IMAGE_DIR: String = "res://ui/story/story%d.jpg"

var _page: int = 0
var _image: TextureRect
var _fade: ColorRect
var _title_cn: Label
var _title_en: Label
var _sub_cn: Label
var _sub_en: Label
var _dots: HBoxContainer
var _next: Button
var _busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("0b0d14")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_image = TextureRect.new()
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)

	# Bottom shade + text.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.03, 0.04, 0.08, 0.0), Color(0.03, 0.04, 0.08, 0.92)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -330.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var text_box := VBoxContainer.new()
	text_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	text_box.offset_left = 70.0
	text_box.offset_right = -70.0
	text_box.offset_top = -280.0
	text_box.offset_bottom = -96.0
	text_box.add_theme_constant_override("separation", 4)
	text_box.alignment = BoxContainer.ALIGNMENT_END
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text_box)
	_title_cn = Kit.label("", 36, Color.WHITE, 8, true)
	_title_cn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_box.add_child(_title_cn)
	_title_en = Kit.label("", 19, Kit.GOLD, 5)
	_title_en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_box.add_child(_title_en)
	_sub_cn = Kit.label("", 18, Color("e8ecf6"), 4)
	_sub_cn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_box.add_child(_sub_cn)
	_sub_en = Kit.label("", 14, Color("b8c3da"), 3)
	_sub_en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_box.add_child(_sub_en)

	# Bottom bar: dots, Skip, Next.
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 40.0
	bar.offset_right = -40.0
	bar.offset_top = -84.0
	bar.offset_bottom = -22.0
	bar.add_theme_constant_override("separation", 14)
	add_child(bar)
	var skip: Button = Kit.pill("跳过", "Skip", Kit.CREAM, Vector2(150, 54), _finish, 20)
	bar.add_child(skip)
	_dots = HBoxContainer.new()
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	bar.add_child(_dots)
	_next = Kit.pill("继续", "Next", Kit.GOLD, Vector2(190, 54), _advance, 22)
	bar.add_child(_next)

	_fade = ColorRect.new()
	_fade.color = Color("0b0d14")
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_show_page(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_RIGHT]:
			_advance()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_finish()
			get_viewport().set_input_as_handled()

func _show_page(animate: bool) -> void:
	var p: Dictionary = StoryData.STORY[_page]
	var en: Dictionary = StoryData.STORY_EN[_page]
	var swap := func() -> void:
		var path: String = IMAGE_DIR % (_page + 1)
		_image.texture = load(path) if ResourceLoader.exists(path) else null
		_title_cn.text = p["t"]
		_title_en.text = en["t"]
		_sub_cn.text = p["s"]
		_sub_en.text = en["s"]
		for c in _dots.get_children():
			c.queue_free()
		for i in StoryData.STORY.size():
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(16, 16)
			dot.add_theme_stylebox_override("panel", Kit.flat(Kit.GOLD if i == _page else Color(1, 1, 1, 0.25), Kit.OUTLINE, 3, 8))
			_dots.add_child(dot)
		(_next.get_child(0).get_child(0) as Label).text = "继续" if _page < StoryData.STORY.size() - 1 else "拿起墨刃"
		(_next.get_child(0).get_child(1) as Label).text = "Next" if _page < StoryData.STORY.size() - 1 else "Take up the Ink Blade"
	if not animate:
		swap.call()
		var tw0: Tween = create_tween()
		tw0.tween_property(_fade, "color:a", 0.0, 0.6)
		return
	_busy = true
	var tw: Tween = create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	tw.tween_callback(swap)
	tw.tween_property(_fade, "color:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: _busy = false)

func _advance() -> void:
	if _busy:
		return
	if _page < StoryData.STORY.size() - 1:
		_page += 1
		_show_page(true)
	else:
		_finish()

func _finish() -> void:
	finished.emit()
	queue_free()
