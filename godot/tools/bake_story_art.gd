extends SceneTree

# Converts art_src/story/storyN.png (Codex illustrations) into ui/story/storyN.jpg (1280 wide).
# Run: godot --headless --path . --script res://tools/bake_story_art.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui/story"))
	for n in range(1, 9):
		var src: String = ProjectSettings.globalize_path("res://art_src/story/story%d.png" % n)
		if not FileAccess.file_exists(src):
			continue
		var img := Image.load_from_file(src)
		img.convert(Image.FORMAT_RGB8)
		img.resize(1280, roundi(img.get_height() * 1280.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
		img.save_jpg(ProjectSettings.globalize_path("res://ui/story/story%d.jpg" % n), 0.88)
		print("baked story", n, " ", img.get_size())
	quit()
