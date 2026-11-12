extends RefCounted
## Fine-shafted one-hand flanged mace at the heroine's native world pixel size.
## Its small hand, grip, steel neck and compact head remain one rigid +X body.

static var _texture_cache := {}

static func texture(baked_hand: bool = true) -> Texture2D:
	if _texture_cache.has(baked_hand):
		return _texture_cache[baked_hand]
	var image := Image.create(122, 44, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var outline := Color("263141")
	var leather := Color("67505b")
	var bronze := Color("b68a58")
	var steel := Color("8ca6b6")
	var dark_steel := Color("506776")
	var light := Color("e5f6f7")
	# The grip has a small end cap; the slender steel shaft reads as a lever.
	image.fill_rect(Rect2i(4, 18, 6, 8), outline)
	image.fill_rect(Rect2i(5, 20, 3, 4), bronze)
	image.fill_rect(Rect2i(8, 18, 36, 8), outline)
	image.fill_rect(Rect2i(8, 20, 34, 4), leather)
	for x in [20, 30, 40]:
		image.fill_rect(Rect2i(x, 20, 2, 4), bronze)
	image.fill_rect(Rect2i(44, 18, 44, 8), outline)
	image.fill_rect(Rect2i(44, 20, 44, 2), steel)
	image.fill_rect(Rect2i(44, 22, 44, 2), dark_steel)
	image.fill_rect(Rect2i(80, 16, 8, 12), outline)
	image.fill_rect(Rect2i(82, 18, 4, 8), bronze)
	# Three stepped flanges surround a narrower steel core, with crown notches.
	image.fill_rect(Rect2i(88, 8, 26, 28), outline)
	image.fill_rect(Rect2i(88, 10, 26, 24), dark_steel)
	image.fill_rect(Rect2i(92, 12, 18, 20), steel)
	image.fill_rect(Rect2i(94, 14, 14, 4), light)
	for x in [86, 110]:
		image.fill_rect(Rect2i(x, 6, 6, 32), outline)
		image.fill_rect(Rect2i(x + 2, 8, 2, 28), bronze)
	image.fill_rect(Rect2i(98, 4, 6, 36), outline)
	image.fill_rect(Rect2i(100, 6, 2, 32), steel)
	image.fill_rect(Rect2i(100, 10, 2, 20), light)
	# A narrow striking face gives the head a blunt end instead of a blade tip.
	image.fill_rect(Rect2i(114, 12, 4, 20), outline)
	image.fill_rect(Rect2i(114, 14, 2, 16), steel)
	if baked_hand:
		image.fill_rect(Rect2i(10, 20, 4, 4), Color("ffd4ad"))
	_texture_cache[baked_hand] = ImageTexture.create_from_image(image)
	return _texture_cache[baked_hand]

static func geometry() -> Dictionary:
	return {"pivot": Vector2(12, 22), "tip": Vector2(118, 22)}
