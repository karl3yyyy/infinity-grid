extends SceneTree

## Writes Evlis with all his code-made animations (Idle, Smoke, Cool, Jog_Fwd ...)
## into blender_export/evlis_animations.glb so Blender can open and edit them.
## Run:
##   Godot_console.exe --headless --path . --script res://tools/export_evlis_animations.gd
## Method calls (cigarette_in_hand, show_puffs) cannot be exported; they stay in
## evlis_animations.gd.
const OUTPUT := "res://blender_export/evlis_animations.glb"


func _initialize() -> void:
	var root_node := Node3D.new()
	root_node.name = "Evlis"
	var body := (load("res://assets/characters/evlis/dog.glb") as PackedScene).instantiate() as Node3D
	body.name = "Body"
	root_node.add_child(body)
	var skeleton := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root_node.add_child(player)
	player.root_node = player.get_path_to(body)
	player.add_animation_library("", EvlisAnimations.library(skeleton, body.get_path_to(skeleton), player.get_path_to(root_node)))
	# Everything below the root must be owned by it, or the exporter skips it.
	_own(root_node, root_node)

	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var error := document.append_from_scene(root_node, state)
	if error != OK:
		push_error("Export failed: %s" % error_string(error))
		quit(1)
		return
	var folder := ProjectSettings.globalize_path("res://blender_export/")
	DirAccess.make_dir_recursive_absolute(folder)
	var gdignore := FileAccess.open(folder + ".gdignore", FileAccess.WRITE)
	if gdignore != null:
		gdignore.close()
	error = document.write_to_filesystem(state, ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Writing failed: %s" % error_string(error))
		quit(1)
		return
	print("Saved ", ProjectSettings.globalize_path(OUTPUT), " with ", player.get_animation_list().size(), " animations")
	quit()


func _own(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		if child.owner == null:
			child.owner = owner_node
		_own(child, owner_node)
