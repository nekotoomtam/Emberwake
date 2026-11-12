extends RefCounted
## Original wood-stocked brass/blue-steel long rifle in four-pixel clusters.
## The only tiny hand, receiver and muzzle share one rigid +X sprite.

static var _texture_cache := {}
static var _end_views := {}
const OUTLINE := Color("263141")
const WOOD := Color("83523e")
const WOOD_LIGHT := Color("b77b4c")
const WOOD_SHADOW := Color("56372f")
const BRASS := Color("c3a069")
const STEEL := Color("8ca6b6")
const DARK_STEEL := Color("506776")
const BUTT_PLATE := Color("536170")
const BARREL_BAND := Rect2i(84, 16, 4, 12)

static func texture(baked_hand: bool = true) -> ImageTexture:
	if _texture_cache.has(baked_hand):
		return _texture_cache[baked_hand]
	var image := Image.create(128, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# The wide heel steps into the narrow wrist of the wooden stock.
	image.fill_rect(Rect2i(4, 12, 20, 24), OUTLINE)
	image.fill_rect(Rect2i(24, 16, 12, 16), OUTLINE)
	image.fill_rect(Rect2i(8, 16, 16, 16), WOOD)
	image.fill_rect(Rect2i(8, 16, 12, 4), WOOD_LIGHT)
	image.fill_rect(Rect2i(8, 28, 16, 4), WOOD_SHADOW)
	image.fill_rect(Rect2i(20, 20, 12, 8), WOOD)
	image.fill_rect(Rect2i(4, 16, 4, 16), BUTT_PLATE)
	# Low wooden fore-end under a dark barrel, with a square band and muzzle.
	image.fill_rect(Rect2i(52, 20, 40, 12), OUTLINE)
	image.fill_rect(Rect2i(56, 24, 32, 4), WOOD_LIGHT)
	image.fill_rect(Rect2i(56, 28, 28, 4), WOOD_SHADOW)
	image.fill_rect(Rect2i(52, 16, 72, 8), OUTLINE)
	image.fill_rect(Rect2i(56, 16, 60, 4), STEEL)
	image.fill_rect(Rect2i(56, 20, 60, 4), DARK_STEEL)
	image.fill_rect(BARREL_BAND, BRASS)
	image.fill_rect(Rect2i(116, 16, 8, 8), OUTLINE)
	image.fill_rect(Rect2i(120, 16, 4, 4), STEEL)
	image.fill_rect(Rect2i(116, 12, 4, 4), OUTLINE)
	# A raised receiver and open trigger guard break the straight barrel line.
	image.fill_rect(Rect2i(32, 12, 28, 16), OUTLINE)
	image.fill_rect(Rect2i(36, 16, 20, 8), BRASS)
	image.fill_rect(Rect2i(48, 16, 8, 4), Color("e8c184"))
	image.fill_rect(Rect2i(40, 20, 12, 4), Color("806044"))
	image.fill_rect(Rect2i(28, 28, 24, 8), OUTLINE)
	image.fill_rect(Rect2i(32, 28, 12, 4), Color.TRANSPARENT)
	image.fill_rect(Rect2i(36, 28, 4, 4), BRASS)
	if baked_hand:
		image.fill_rect(Rect2i(24, 20, 4, 4), Color("ffd4ad"))
	_texture_cache[baked_hand] = ImageTexture.create_from_image(image)
	return _texture_cache[baked_hand]

static func geometry() -> Dictionary:
	return {"pivot": Vector2(26, 22), "tip": Vector2(122, 22)}

static func end_view(rear: bool) -> Texture2D:
	if _end_views.has(rear): return _end_views[rear]
	var image := texture(false).get_image().duplicate() as Image
	# Keep the side profile's stock, action and barrel band at their original
	# stations. Repaint only the faces exposed by the end-on angle.
	image.fill_rect(Rect2i(28, 28, 24, 8), Color.TRANSPARENT)
	image.fill_rect(Rect2i(32, 12, 28, 16), OUTLINE)
	image.fill_rect(Rect2i(36, 16, 20, 8), BRASS)
	image.fill_rect(Rect2i(44, 18, 8, 6), DARK_STEEL)
	image.fill_rect(Rect2i(52, 26, 36, 4), WOOD)
	image.fill_rect(Rect2i(60, 27, 20, 3), WOOD_LIGHT)
	image.fill_rect(Rect2i(56, 18, 60, 6), OUTLINE)
	image.fill_rect(Rect2i(60, 19, 56, 4), STEEL)
	image.fill_rect(BARREL_BAND, BRASS)
	if rear:
		image.fill_rect(Rect2i(4, 12, 8, 24), OUTLINE)
		image.fill_rect(Rect2i(6, 15, 4, 18), BUTT_PLATE)
		image.fill_rect(Rect2i(8, 16, 2, 12), STEEL)
		image.fill_rect(Rect2i(116, 18, 8, 6), OUTLINE)
	else:
		image.fill_rect(Rect2i(8, 16, 12, 4), WOOD)
		image.fill_rect(Rect2i(114, 16, 10, 12), OUTLINE)
		image.fill_rect(Rect2i(116, 18, 8, 8), STEEL)
		image.fill_rect(Rect2i(120, 20, 4, 4), Color("151d28"))
	_end_views[rear] = ImageTexture.create_from_image(image)
	return _end_views[rear]
