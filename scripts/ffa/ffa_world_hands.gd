class_name FfaWorldHands
extends Node3D

## Finite Grid: the two cards of every other player lie flat on the floor behind
## that player's side of the board, turned like on a real table. Their diagrams
## then point the same way as the figures move, so you read where an opponent
## can go straight off the board. The viewer's own hand stays on the HUD.

const CARD_PIXELS := Vector2(160.0, 224.0)
const CARD_WORLD := Vector2(1.9, 2.66)
const CARD_GAP: float = 0.2
## Space between the edge of the board and the cards.
const EDGE_MARGIN: float = 0.45
## Board cells the camera adds on every side so the cards stay in view.
const FRAMING_MARGIN_CELLS: float = 2.7

var _holders: Array[Node3D] = []
var _views: Array = []


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
		for slot: int in range(2):
			views.append(_make_card(holder, (float(slot) - 0.5) * (CARD_WORLD.x + CARD_GAP)))
		_views.append(views)


## Direction from the middle of the board to the side of a seat (0 bottom, 1 left, 2 top, 3 right).
static func _outward(seat: int) -> Vector3:
	return [Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0)][seat]


func _make_card(holder: Node3D, offset_x: float) -> CardView:
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
	return view


## `view` is the seat the player looks from; that hand is not drawn here.
func show_seats(rules: FfaRules, view: int) -> void:
	for seat: int in range(FfaRules.PLAYERS):
		_holders[seat].visible = seat != view and rules.alive[seat]
		var color: Color = FfaFloor.SEAT_COLORS[seat]
		for slot: int in range(2):
			var card_view: CardView = _views[seat][slot]
			card_view.dimmed = false
			card_view.show_card(rules.hands[seat][slot], false, color, false)
