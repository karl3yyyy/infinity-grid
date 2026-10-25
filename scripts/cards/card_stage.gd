class_name CardStage
extends Node3D

## The five match cards as 3D objects in front of the camera. The stage lives
## under the orthographic camera and is scaled so that one unit is one screen
## pixel; the HUD only reserves the places (anchors) where the cards rest.
## Rules stay elsewhere: the stage shows the placements it is given and reports
## which hand card was picked.

signal card_picked(team_id: int, slot: int)
signal deal_finished

enum DealOrigin { CENTER, LEFT_SLOT, RIGHT_SLOT }
enum State { HIDDEN, DEALING, READY }

## Length of the opening scene in seconds: materialise, shuffle, shoot out.
const DEAL_SECONDS: float = 4.0
const DEAL_ORIGIN: DealOrigin = DealOrigin.CENTER
const STAGE_DEPTH: float = 6.0
const STACK_SCALE: float = 0.9
const SELECT_LIFT: float = 22.0
const HOVER_LIFT: float = 9.0
const FLY_SECONDS: float = 0.6
## Cards lean back a little so the pillars rise from them.
const REST_TILT: float = 0.22

var state: State = State.HIDDEN
## Pixel size of the viewer's hand cards; the other sizes are scaled from it.
var base_size: Vector2 = Vector2.ZERO

var _placements: Array = []
var _pool: Array[Card3D] = []
var _by_card: Dictionary = {}
var _hovered: Card3D
var _previewed: Card3D
var _slot_bar: MeshInstance3D
var _time: float = 0.0


func _init() -> void:
	visible = false
	for index: int in range(5):
		var card := Card3D.new()
		card.name = "Card%d" % index
		card.visible = false
		add_child(card)
		_pool.append(card)
	_slot_bar = MeshInstance3D.new()
	var bar := QuadMesh.new()
	bar.size = Vector2(12.0, 200.0)
	_slot_bar.mesh = bar
	var bar_material := StandardMaterial3D.new()
	bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bar_material.no_depth_test = true
	bar_material.albedo_color = Color(0.4, 1.0, 0.55, 0.0)
	_slot_bar.material_override = bar_material
	_slot_bar.visible = false
	add_child(_slot_bar)


## `placements`: one Dictionary per card with card (MovementCard), anchor (Control),
## team (int, -1 for the pass card), slot (int), rotated, color, selected,
## dimmed, interactive and lift_direction.
func present(placements: Array) -> void:
	_placements = placements
	_bind_cards()
	for placement: Dictionary in placements:
		var card_node := _node_for(placement)
		var anchor: Control = placement["anchor"]
		var moved := card_node.anchor != null and card_node.anchor != anchor
		card_node.anchor = anchor
		if moved and state == State.READY and not card_node.animated:
			_fly_to_home(card_node)


## Applies a CardSkins entry to all five cards.
func set_skin(skin: Dictionary) -> void:
	for card_node: Card3D in _pool:
		card_node.apply_skin(skin)


## For flows that do not play the opening scene (e.g. resumed games).
func show_instantly() -> void:
	if state != State.HIDDEN:
		return
	state = State.READY
	visible = true
	_update_base_size()
	for card_node: Card3D in _used_nodes():
		card_node.visible = true
		card_node.set_appear(1.0)
		card_node.set_reveal(1.0)
		card_node.rotation = Vector3.ZERO
		_snap_to_home(card_node)


## True when a card is under the screen position; the board must not react then.
func is_over_card(screen_position: Vector2) -> bool:
	return state != State.HIDDEN and _card_at(screen_position) != null


## Opening scene: the cards materialise as a face-down stack, shuffle and are
## shot out to their places, turning face up on the way.
func deal() -> void:
	if state == State.DEALING:
		return
	_update_base_size()
	if base_size.x < 8.0 or _used_nodes().is_empty():
		show_instantly()
		return
	state = State.DEALING
	visible = true
	var nodes := _deal_order()
	var origin := _deal_origin_point()
	for index: int in range(nodes.size()):
		var card_node := nodes[index]
		card_node.visible = true
		card_node.animated = true
		card_node.set_appear(0.0)
		card_node.set_reveal(0.0)
		card_node.set_flash(1.0)
		card_node.position = _stack_position(origin, index)
		card_node.rotation = Vector3(0.0, PI, 0.0)
		card_node.scale = Vector3.ONE * 0.15
	_show_slot_bar(origin)

	# 1. Materialise.
	var appear_time := DEAL_SECONDS * 0.22
	var last: Tween
	for index: int in range(nodes.size()):
		var card_node := nodes[index]
		var delay := float(index) * appear_time * 0.2
		last = create_tween().set_parallel(true)
		last.tween_property(card_node, "scale", Vector3.ONE * STACK_SCALE, appear_time * 0.6).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last.tween_method(card_node.set_appear, 0.0, 1.0, appear_time * 0.4).set_delay(delay)
		last.tween_method(card_node.set_flash, 1.0, 0.0, appear_time * 0.9).set_delay(delay)
	await last.finished

	# 2. Shuffle: the stack swirls apart and comes back together.
	SoundBoard.play("glitch", -6.0)
	var shuffle := create_tween()
	shuffle.tween_method(_shuffle_step.bind(nodes, origin), 0.0, 1.0, DEAL_SECONDS * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await shuffle.finished

	# 3. Shoot out one after another.
	var flight := DEAL_SECONDS * 0.26
	var gap := DEAL_SECONDS * 0.055
	var final_tween: Tween
	for index: int in range(nodes.size()):
		var card_node := nodes[index]
		final_tween = _launch(card_node, flight, float(index) * gap, PI, true)
	await final_tween.finished
	state = State.READY
	if _slot_bar.visible:
		var fade := create_tween()
		fade.tween_property(_slot_bar.material_override, "albedo_color:a", 0.0, 0.3)
		fade.tween_callback(func() -> void: _slot_bar.visible = false)
	deal_finished.emit()


func _process(delta: float) -> void:
	_time += delta
	var camera := get_parent() as Camera3D
	if camera == null or state == State.HIDDEN:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return
	position = camera.to_local(camera.project_position(viewport_size * 0.5, STAGE_DEPTH))
	scale = Vector3.ONE * camera.size / viewport_size.y
	_update_base_size()
	var mouse := get_viewport().get_mouse_position()
	var hover_node := _card_at(mouse) if state == State.READY else null
	if hover_node != _hovered:
		_hovered = hover_node
		_update_hover_states()
	if state == State.READY:
		_follow_homes(delta, mouse)


func _unhandled_input(event: InputEvent) -> void:
	if state != State.READY:
		return
	var screen_position := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		screen_position = event.position
	elif event is InputEventScreenTouch and event.pressed:
		screen_position = event.position
	else:
		return
	var card_node := _card_at(screen_position)
	if card_node == null:
		return
	get_viewport().set_input_as_handled()
	if card_node.interactive and card_node.team_id >= 0:
		_previewed = null
		_update_hover_states()
		card_picked.emit(card_node.team_id, card_node.slot)
	else:
		_toggle_preview(card_node)


func _toggle_preview(card_node: Card3D) -> void:
	_previewed = null if _previewed == card_node else card_node
	_update_hover_states()


func _update_hover_states() -> void:
	for card_node: Card3D in _pool:
		card_node.set_hovered(card_node == _hovered or card_node == _previewed)


# --- placement bookkeeping -------------------------------------------------

## Keeps every MovementCard on the same Card3D for the whole match, so a used
## card flies to the pass place instead of being redrawn there.
func _bind_cards() -> void:
	var wanted: Dictionary = {}
	for placement: Dictionary in _placements:
		wanted[placement["card"]] = true
	var kept: Dictionary = {}
	var free: Array[Card3D] = []
	for card: Variant in _by_card.keys():
		if wanted.has(card):
			kept[card] = _by_card[card]
	for card_node: Card3D in _pool:
		if not kept.values().has(card_node):
			free.append(card_node)
	for placement: Dictionary in _placements:
		var card: MovementCard = placement["card"]
		if not kept.has(card) and not free.is_empty():
			var fresh: Card3D = free.pop_back()
			fresh.anchor = null
			kept[card] = fresh
	_by_card = kept
	for placement: Dictionary in _placements:
		var card_node := _node_for(placement)
		card_node.team_id = int(placement["team"])
		card_node.slot = int(placement["slot"])
		card_node.interactive = bool(placement["interactive"])
		card_node.lift_direction = float(placement["lift_direction"])
		card_node.set_selected(bool(placement["selected"]))
		card_node.set_dimmed(bool(placement["dimmed"]))
		var key := "%s|%s|%s" % [(placement["card"] as MovementCard).card_name, placement["rotated"], placement["color"]]
		if key != card_node.face_key:
			card_node.face_key = key
			card_node.show_card(placement["card"], placement["rotated"], placement["color"])
	if _previewed != null and (_previewed.interactive or not _used_nodes().has(_previewed)):
		_previewed = null
		_update_hover_states()


func _node_for(placement: Dictionary) -> Card3D:
	return _by_card[placement["card"]]


func _used_nodes() -> Array[Card3D]:
	var nodes: Array[Card3D] = []
	for placement: Dictionary in _placements:
		if _by_card.has(placement["card"]):
			nodes.append(_node_for(placement))
	return nodes


## Order of the shoot-out: own hand, opponent hand, the pass card last.
func _deal_order() -> Array[Card3D]:
	var nodes: Array[Card3D] = []
	var pass_nodes: Array[Card3D] = []
	for placement: Dictionary in _placements:
		if int(placement["team"]) < 0:
			pass_nodes.append(_node_for(placement))
		else:
			nodes.append(_node_for(placement))
	nodes.append_array(pass_nodes)
	return nodes


func _update_base_size() -> void:
	var reference := _first_anchor()
	if reference != null and reference.size.x >= 8.0:
		base_size = reference.size
	if base_size.x < 8.0:
		return
	for card_node: Card3D in _pool:
		card_node.set_face_size(base_size)


func _first_anchor() -> Control:
	var best: Control
	for placement: Dictionary in _placements:
		var anchor: Control = placement["anchor"]
		if int(placement["team"]) >= 0 and float(placement["lift_direction"]) > 0.0:
			return anchor
		best = anchor
	return best


## Home pose of a card in stage pixels: the centre of its anchor.
func _home_of(card_node: Card3D) -> Dictionary:
	var anchor := card_node.anchor
	var viewport_size := get_viewport().get_visible_rect().size
	if anchor == null or base_size.x < 8.0:
		return {"position": Vector3.ZERO, "scale": 1.0}
	var rect := anchor.get_global_rect()
	var center := rect.get_center() - viewport_size * 0.5
	return {
		"position": Vector3(center.x, -center.y, 0.0),
		"scale": rect.size.x / base_size.x,
	}


func _snap_to_home(card_node: Card3D) -> void:
	var home := _home_of(card_node)
	card_node.position = home["position"]
	card_node.scale = Vector3.ONE * float(home["scale"])
	card_node.rest_scale = float(home["scale"])


func _follow_homes(delta: float, mouse: Vector2) -> void:
	var weight := 1.0 - exp(-delta * 14.0)
	var viewport_size := get_viewport().get_visible_rect().size
	for card_node: Card3D in _used_nodes():
		if card_node.animated:
			continue
		var home := _home_of(card_node)
		var home_scale: float = home["scale"]
		var target: Vector3 = home["position"]
		var lift := 0.0
		var grow := 1.0
		if card_node.is_selected():
			lift = SELECT_LIFT
			grow = 1.08
		elif card_node == _previewed:
			lift = HOVER_LIFT * 1.5
			grow = 1.14
		elif card_node == _hovered:
			lift = HOVER_LIFT
			grow = 1.06
		var bob := sin(_time * 1.6 + float(card_node.get_index()) * 1.3) * 2.5
		target.y += (lift * card_node.lift_direction + bob) * home_scale
		card_node.position = card_node.position.lerp(target, weight)
		card_node.rest_scale = lerpf(card_node.rest_scale, home_scale * grow, weight)
		card_node.scale = Vector3.ONE * card_node.rest_scale
		# Tilt towards the pointer for the picked and hovered card.
		var tilt_target := Vector2.ZERO
		if card_node.is_selected() or card_node == _hovered or card_node == _previewed:
			var offset := (mouse - viewport_size * 0.5) - Vector2(target.x, -target.y)
			tilt_target = Vector2(clampf(offset.y / 300.0, -1.0, 1.0) * 0.14, clampf(offset.x / 300.0, -1.0, 1.0) * 0.2)
		tilt_target.x += -REST_TILT * card_node.lift_direction + sin(_time * 1.1 + float(card_node.get_index())) * 0.025
		card_node.tilt = card_node.tilt.lerp(tilt_target, weight)
		card_node.rotation = Vector3(card_node.tilt.x, card_node.tilt.y, 0.0)


# --- picking ---------------------------------------------------------------

## Ray against the card planes (the cards may be tilted); the nearest hit wins.
func _card_at(screen_position: Vector2) -> Card3D:
	var camera := get_parent() as Camera3D
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var best: Card3D
	var best_distance := INF
	for card_node: Card3D in _used_nodes():
		if not card_node.visible or card_node.face_size.x < 8.0:
			continue
		var inverse := card_node.global_transform.affine_inverse()
		var local_origin := inverse * origin
		var local_direction := inverse.basis * direction
		if absf(local_direction.z) < 0.00001:
			continue
		var distance := -local_origin.z / local_direction.z
		var hit := local_origin + local_direction * distance
		var extent := card_node.face_half_extent()
		if absf(hit.x) <= extent.x and absf(hit.y) <= extent.y and distance < best_distance:
			best = card_node
			best_distance = distance
	return best


# --- animation -------------------------------------------------------------

func _deal_origin_point() -> Vector2:
	var half_width := get_viewport().get_visible_rect().size.x * 0.5
	match DEAL_ORIGIN:
		DealOrigin.LEFT_SLOT:
			return Vector2(-half_width + 10.0, 40.0)
		DealOrigin.RIGHT_SLOT:
			return Vector2(half_width - 10.0, 40.0)
	return Vector2.ZERO


func _stack_position(origin: Vector2, index: int) -> Vector3:
	return Vector3(origin.x + float(index) * 2.0, origin.y - float(index) * 2.5, float(index) * 3.0)


func _show_slot_bar(origin: Vector2) -> void:
	if DEAL_ORIGIN == DealOrigin.CENTER:
		return
	_slot_bar.visible = true
	_slot_bar.position = Vector3(origin.x, origin.y, -5.0)
	var material := _slot_bar.material_override as StandardMaterial3D
	material.albedo_color = Color(0.4, 1.0, 0.55, 0.0)
	var pulse := create_tween()
	pulse.tween_property(material, "albedo_color:a", 0.95, 0.25)


func _shuffle_step(progress: float, nodes: Array[Card3D], origin: Vector2) -> void:
	var swing := sin(progress * PI)
	for index: int in range(nodes.size()):
		var angle := progress * TAU * 1.5 + float(index) * TAU / 5.0
		var stacked := _stack_position(origin, index)
		var card_node := nodes[index]
		card_node.position = stacked + Vector3(cos(angle) * 120.0 * swing, sin(angle) * 70.0 * swing, sin(angle) * 20.0 * swing)
		card_node.rotation = Vector3(0.0, PI + sin(angle + 1.0) * 0.4 * swing, sin(angle) * 0.5 * swing)


## Arc flight to the card's home with a spin; `reveal` scans the face in.
func _launch(card_node: Card3D, duration: float, delay: float, start_yaw: float, reveal: bool) -> Tween:
	var start := card_node.position
	var start_scale := card_node.scale.x
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: SoundBoard.play("zap", -10.0))
	tween.tween_method(_flight_step.bind(card_node, start, start_scale, start_yaw, reveal), 0.0, 1.0, duration)
	tween.tween_callback(_land.bind(card_node))
	return tween


func _flight_step(progress: float, card_node: Card3D, start: Vector3, start_scale: float, start_yaw: float, reveal: bool) -> void:
	var home := _home_of(card_node)
	var end: Vector3 = home["position"]
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var middle := (Vector2(start.x, start.y) + Vector2(end.x, end.y)) * 0.5
	var travel := Vector2(end.x - start.x, end.y - start.y)
	var control := middle + Vector2(-travel.y, travel.x).normalized() * minf(travel.length() * 0.3, 160.0)
	var point := _quadratic(Vector2(start.x, start.y), control, Vector2(end.x, end.y), eased)
	var arc := sin(progress * PI)
	card_node.position = Vector3(point.x, point.y, lerpf(start.z, 0.0, eased) + arc * 40.0)
	card_node.rotation = Vector3(0.0, lerpf(start_yaw, -TAU, eased), arc * 0.35)
	card_node.scale = Vector3.ONE * lerpf(start_scale, float(home["scale"]), eased) * (1.0 + 0.22 * arc)
	if reveal:
		card_node.set_reveal(smoothstep(0.3, 0.85, progress))


func _quadratic(from: Vector2, control: Vector2, to: Vector2, weight: float) -> Vector2:
	return from.lerp(control, weight).lerp(control.lerp(to, weight), weight)


func _land(card_node: Card3D) -> void:
	card_node.rotation = Vector3.ZERO
	card_node.set_reveal(1.0)
	card_node.set_appear(1.0)
	_snap_to_home(card_node)
	card_node.tilt = Vector2.ZERO
	card_node.animated = false
	SoundBoard.play("select", -6.0)
	var punch := create_tween()
	punch.tween_method(card_node.set_flash, 1.0, 0.0, 0.4)


func _fly_to_home(card_node: Card3D) -> void:
	card_node.animated = true
	_launch(card_node, FLY_SECONDS, 0.0, 0.0, false)
