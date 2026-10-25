extends SceneTree

# Converts the raw Codex backdrop paintings in art_src/raw_bg/<theme>_<layer>.png (ink on white paper)
# into compact JPGs in backgrounds/ for the game (white = transparent via multiply blending).
#
# Run:  godot --headless --path . --script res://tools/bake_backdrops.gd
# then: godot --headless --path . --import

const RAW_DIR: String = "res://art_src/raw_bg/"
const OUT_DIR: String = "res://backgrounds/"
const OUT_WIDTH: int = 1280
const QUALITY: float = 0.88

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var dir := DirAccess.open(RAW_DIR)
	for file_name in dir.get_files():
		if not file_name.ends_with(".png"):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(RAW_DIR + file_name))
		img.convert(Image.FORMAT_RGB8)
		var scale_f: float = float(OUT_WIDTH) / img.get_width()
		img.resize(OUT_WIDTH, roundi(img.get_height() * scale_f), Image.INTERPOLATE_LANCZOS)
		var out: String = ProjectSettings.globalize_path(OUT_DIR + file_name.get_basename() + ".jpg")
		img.save_jpg(out, QUALITY)
		print("baked %s -> %dx%d" % [file_name, img.get_width(), img.get_height()])
	quit()
