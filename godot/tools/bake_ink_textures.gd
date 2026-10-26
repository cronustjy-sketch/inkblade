extends SceneTree

# Paints the ink splash / brush-stroke textures once and saves them to ui/fx/ so the game loads them instead of
# painting them (about 0.8 s) on the first hit. Run: godot --headless --path . --script res://tools/bake_ink_textures.gd

func _init() -> void:
	var InkFx = load("res://scripts/inkfx.gd")
	var splats: Array = InkFx.call("_splat_textures")
	for i in splats.size():
		(splats[i] as Texture2D).get_image().save_png(ProjectSettings.globalize_path("res://ui/fx/ink_splat_%d.png" % i))
	(InkFx.call("_stroke_texture") as Texture2D).get_image().save_png(ProjectSettings.globalize_path("res://ui/fx/ink_stroke.png"))
	print("baked ink textures")
	quit()
