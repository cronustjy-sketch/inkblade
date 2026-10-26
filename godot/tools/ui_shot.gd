extends SceneTree

# Dev tool: renders a UI scene (or a menu screen) to a PNG.  godot --path . --script res://tools/ui_shot.gd -- <scene> <out.png> [call] [wait]
# `call` is an optional method name to invoke on the scene root before the shot (e.g. _show_play, _play_intro).

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: Control = load(args[0]).instantiate()
	root.add_child(scene)
	if args.size() > 2 and args[2] != "":
		await create_timer(0.3).timeout
		if args[2].begins_with("chapter:"):
			var view: Control = load("res://scripts/chapter_story.gd").new()
			view.setup(int(args[2].substr(8)))
			scene.add_child(view)
		else:
			scene.call(args[2])
	var wait: float = float(args[3]) if args.size() > 3 else 1.2
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(args[1])
	quit()
