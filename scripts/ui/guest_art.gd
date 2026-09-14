extends RefCounted
## Regions use imported dimensions, so import downscaling never changes indexing.
const PORTRAITS = [preload("res://assets/ui/mobile/cats-01.png"), preload("res://assets/ui/mobile/cats-02.png"), preload("res://assets/ui/mobile/cats-03.png")]
const TOYS = preload("res://assets/ui/mobile/care-toys.png")
static var regions: Dictionary = {}
static func region(texture: Texture2D, cell: int, key: String) -> AtlasTexture:
	if not regions.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		var cell_size := texture.get_size() / Vector2(3, 2)
		atlas.region = Rect2(Vector2(cell % 3, cell / 3) * cell_size, cell_size)
		atlas.filter_clip = true
		regions[key] = atlas
	return regions[key]
static func portrait(index: int) -> AtlasTexture:
	return region(PORTRAITS[index / 6], index % 6, "cat_" + str(index))
static func toy(index: int) -> TextureRect:
	var art := TextureRect.new()
	art.texture = region(TOYS, index, "toy_" + str(index))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art
