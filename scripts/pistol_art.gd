extends RefCounted
## Original compact brass/blue-steel pistol in the heroine's four-pixel clusters.
## The sole tiny hand is part of the rigid gun; its center is the spin pivot.

static var _texture_cache := {}
static var _end_views := {}
const OUTLINE := Color("263141")
const LEATHER := Color("67505b")
const BRASS := Color("c3a069")
const STEEL := Color("8ca6b6")
const LIGHT := Color("e5f6f7")

static func texture(baked_hand: bool = true) -> ImageTexture:
	if _texture_cache.has(baked_hand):
		return _texture_cache[baked_hand]
	var image := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# Receiver and short hammer meet a slender, flat-ended steel barrel.
	image.fill_rect(Rect2i(4, 12, 28, 12), OUTLINE)
	image.fill_rect(Rect2i(12, 8, 20, 4), OUTLINE)
	image.fill_rect(Rect2i(28, 12, 32, 12), OUTLINE)
	image.fill_rect(Rect2i(16, 12, 12, 8), BRASS)
	image.fill_rect(Rect2i(28, 16, 28, 4), STEEL)
	image.fill_rect(Rect2i(32, 12, 24, 4), LIGHT)
	image.fill_rect(Rect2i(52, 8, 4, 4), OUTLINE)
	# A small L-shaped grip and open trigger guard make this read as a gun.
	image.fill_rect(Rect2i(8, 20, 12, 12), OUTLINE)
	image.fill_rect(Rect2i(12, 24, 4, 4), LEATHER)
	image.fill_rect(Rect2i(20, 24, 12, 4), OUTLINE)
	image.fill_rect(Rect2i(28, 20, 4, 4), BRASS)
	image.fill_rect(Rect2i(24, 20, 4, 4), Color.TRANSPARENT)
	if baked_hand:
		image.fill_rect(Rect2i(8, 16, 4, 4), Color("ffd4ad"))
	_texture_cache[baked_hand] = ImageTexture.create_from_image(image)
	return _texture_cache[baked_hand]

static func geometry() -> Dictionary:
	return {"pivot": Vector2(10, 18), "tip": Vector2(58, 18)}

static func end_view(rear: bool) -> ImageTexture:
	if _end_views.has(rear): return _end_views[rear]
	var image := texture(false).get_image().duplicate() as Image
	# Repaint the exposed faces of the same slide and grip. Both views
	# retain the side sprite's contact points and brass receiver.
	image.fill_rect(Rect2i(28, 10, 28, 4), OUTLINE)
	image.fill_rect(Rect2i(32, 12, 22, 4), STEEL)
	image.fill_rect(Rect2i(32, 16, 22, 2), LIGHT)
	if rear:
		image.fill_rect(Rect2i(4, 12, 8, 12), OUTLINE)
		image.fill_rect(Rect2i(6, 14, 4, 7), STEEL)
		image.fill_rect(Rect2i(8, 22, 5, 7), LEATHER)
	else:
		image.fill_rect(Rect2i(50, 12, 10, 12), OUTLINE)
		image.fill_rect(Rect2i(52, 14, 8, 8), STEEL)
		image.fill_rect(Rect2i(56, 16, 4, 4), OUTLINE)
	_end_views[rear] = ImageTexture.create_from_image(image)
	return _end_views[rear]
