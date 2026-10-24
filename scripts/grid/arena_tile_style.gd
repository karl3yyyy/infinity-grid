class_name ArenaTileStyle
extends RefCounted

## Cell markers on top of the arena model: the model is the skin, so a cell is
## invisible until hover, selection or a move lights it up.
## The frames sit on the exact logical cells, whatever the model's own tiles look like.

const SIZE: int = 64
const BORDER: int = 3
const FRAME_OPACITY: float = 0.0

static var _frame_texture: ImageTexture
static var _filled_texture: ImageTexture


static func make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.no_depth_test = false
	return material


## highlighted: hover / selected / move / attack / occupied; otherwise the plain frame.
static func paint(material: StandardMaterial3D, highlighted: bool, color: Color, opacity: float) -> void:
	material.albedo_texture = _texture(highlighted)
	var tint := color
	tint.a = opacity if highlighted else opacity * FRAME_OPACITY
	material.albedo_color = tint


static func _texture(filled: bool) -> ImageTexture:
	if _frame_texture == null:
		_frame_texture = _build(0.0)
		_filled_texture = _build(0.4)
	return _filled_texture if filled else _frame_texture


static func _build(fill_alpha: float) -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, fill_alpha))
	for index: int in range(SIZE):
		for edge: int in range(BORDER):
			for point: Vector2i in [Vector2i(index, edge), Vector2i(index, SIZE - 1 - edge), Vector2i(edge, index), Vector2i(SIZE - 1 - edge, index)]:
				image.set_pixelv(point, Color.WHITE)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Hover: just a bright frame, no fill, so the model underneath stays visible.
static func paint_hover(material: StandardMaterial3D, color: Color, opacity: float) -> void:
	material.albedo_texture = _texture(false)
	var tint := color
	tint.a = opacity
	material.albedo_color = tint
