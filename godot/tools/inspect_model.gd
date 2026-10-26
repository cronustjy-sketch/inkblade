extends SceneTree

# Dev tool: prints the skeleton bones, animations and mesh bounds of the .glb files given in INSPECT (comma separated).
func _init() -> void:
	for path: String in OS.get_environment("INSPECT").split(","):
		var inst: Node = (load(path) as PackedScene).instantiate()
		print("== ", path)
		for sk: Node in inst.find_children("*", "Skeleton3D", true, false):
			var skel: Skeleton3D = sk as Skeleton3D
			var names: PackedStringArray = []
			for i in skel.get_bone_count():
				names.append(skel.get_bone_name(i))
			print("bones(", names.size(), "): ", ", ".join(names))
		for ap: Node in inst.find_children("*", "AnimationPlayer", true, false):
			print("anims: ", (ap as AnimationPlayer).get_animation_list())
		for mi: Node in inst.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			print("mesh ", m.name, " aabb ", m.get_aabb(), " xf scale ", m.global_transform.basis.get_scale())
		inst.free()
	quit()
