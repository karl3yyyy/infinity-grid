class_name FfaWorldHands
extends Node3D

## Finite Grid: each seat's two cards lie flat behind its side of the board.
## The active seat's shared third card sits inward from its hand.

const CARD_PIXELS := Vector2(160.0, 224.0)
const CARD_WORLD := Vector2(1.9, 2.66)
const CARD_GAP: float = 0.2
## Space between the edge of the board and the cards.
const EDGE_MARGIN: float = 0.45
## Board cells the camera adds on every side so the cards stay in view.
const FRAMING_MARGIN_CELLS: float = 2.7

var _holders: Array[Node3D] = []
var _views: Array = []
var _shared_views: Array[CardView] = []
var _shared_quads: Array[MeshInstance3D] = []
var _pass_view: CardView
var _pass_quad: MeshInstance3D


func _init() -> void:
	var edge := float(FfaRules.SIZE) * GridManager.CELL_SIZE * 0.5 + EDGE_MARGIN + CARD_WORLD.y * 0.5
	for seat: int in range(FfaRules.PLAYERS):
		var outward := _outward(seat)
		var forward := -outward
		var holder := Node3D.new()
		holder.name = "Hand%d" % seat
		holder.transform = Transform3D(Basis(Vector3(-forward.z, 0.0, forward.x), forward, Vector3.UP), outward * edge + Vector3(0.0, 0.03, 0.0))
		add_child(holder)
		_holders.append(holder)
		var views: Array[CardView] = []
		var quads: Array[MeshInstance3D] = []
		for slot: int in range(2):
			views.append(_make_card(holder, (float(slot) - 0.5) * (CARD_WORLD.x + CARD_GAP), quads))
		_views.append(views)
		var shared_view := _make_card(holder, 0.0, quads)
		quads[2].position = Vector3(0.0, CARD_WORLD.y + CARD_GAP, 0.0)
		quads[2].visible = false
		_shared_views.append(shared_view)
		_shared_quads.append(quads[2])
	_make_pass_card()


## Direction from the middle of the board to the side of a seat (0 bottom, 1 left, 2 top, 3 right).
static func _outward(seat: int) -> Vector3:
	return [Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0)][seat]


func _make_card(holder: Node3D, offset_x: float, quads: Array[MeshInstance3D]) -> CardView:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.size = Vector2i(CARD_PIXELS)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(viewport)
	var view := CardView.new()
	view.remove_from_group("interactive_ui")
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.size = CARD_PIXELS
	viewport.add_child(view)
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = CARD_WORLD
	quad.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = viewport.get_texture()
	quad.material_override = material
	quad.position = Vector3(offset_x, 0.0, 0.0)
	holder.add_child(quad)
	quads.append(quad)
	return view


func _make_pass_card() -> void:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.size = Vector2i(CARD_PIXELS)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	_pass_view = CardView.new()
	_pass_view.remove_from_group("interactive_ui")
	_pass_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pass_view.size = CARD_PIXELS
	viewport.add_child(_pass_view)
	var mesh := QuadMesh.new()
	mesh.size = CARD_WORLD
	_pass_quad = MeshInstance3D.new()
	_pass_quad.mesh = mesh
	_pass_quad.rotation.x = -PI / 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = viewport.get_texture()
	_pass_quad.material_override = material
	_pass_quad.visible = false
	add_child(_pass_quad)


func animate_pass(from_seat: int, to_seat: int, card: MovementCard) -> void:
	if card == null or from_seat == to_seat:
		return
	var color: Color = FfaFloor.SEAT_COLORS[from_seat]
	_pass_view.show_card(card, false, color, false)
	var edge := float(FfaRules.SIZE) * GridManager.CELL_SIZE * 0.5 + EDGE_MARGIN + CARD_WORLD.y * 0.5
	var start := _outward(from_seat) * edge + Vector3(0.0, 0.12, 0.0)
	var finish := _outward(to_seat) * edge + Vector3(0.0, 0.12, 0.0)
	_pass_quad.position = start
	_pass_quad.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_pass_quad, "position", Vector3(0.0, 1.4, 0.0), 0.32)
	tween.tween_property(_pass_quad, "position", finish, 0.32)
	await tween.finished
	_pass_quad.visible = false


## `view` is the seat the player looks from; that hand is not drawn here.
func show_seats(rules: FfaRules, view: int, active_seat: int) -> void:
	for seat: int in range(FfaRules.PLAYERS):
		_holders[seat].visible = seat != view and rules.alive[seat]
		var color: Color = FfaFloor.SEAT_COLORS[seat]
		for slot: int in range(2):
			var card_view: CardView = _views[seat][slot]
			card_view.dimmed = false
			card_view.show_card(rules.hands[seat][slot], false, color, false)
		_shared_quads[seat].visible = seat == active_seat and seat != view and rules.alive[seat]
		_shared_views[seat].show_card(rules.pass_card, false, color, false)
