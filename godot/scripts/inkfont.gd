extends RefCounted

# The ink-brush title font from the web game (ZCOOL QingKe HuangYou, SIL Open Font License), used for big titles.

static var _font: FontFile

static func title() -> FontFile:
	if _font == null:
		_font = load("res://ui/fonts/ZCOOLQingKeHuangYou.ttf")
	return _font

# Applies the title font to a label (or button) and returns it for chaining.
static func apply(control: Control) -> Control:
	control.add_theme_font_override("font", title())
	return control
