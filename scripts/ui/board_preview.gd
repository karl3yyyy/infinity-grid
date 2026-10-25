class_name BoardPreview
extends RefCounted

## Sammlung > SPIELFELD: a picture of the real platform model of a board skin,
## rendered once in its own small 3D world.

const SIZE := Vector2i(480, 240)


## Returns the picture; the viewport lives under `parent` as long as the page does.
static func make(parent: Node, skin_id: String) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("05070a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa6b8")
	environment.ambient_light_energy = 0.9
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	light.light_energy = 1.3
	viewport.add_child(light)

	var half := ArenaHalf.new()
	viewport.add_child(half)
	half.show_skin(skin_id, false)

	var camera := Camera3D.new()
	camera.fov = 40.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 4.6, 5.6), Vector3(0.0, -0.3, 0.0))
	camera.current = true
	return viewport.get_texture()
