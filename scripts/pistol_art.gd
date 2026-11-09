extends RefCounted
## Original compact brass/blue-steel pistol in the heroine's four-pixel clusters.
## The sole tiny hand is part of the rigid gun; its center is the spin pivot.

static var _texture_cache: ImageTexture

static func texture() -> ImageTexture:
	if _texture_cache != null:
		return _texture_cache
	var image := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var outline := Color("263141")
	var leather := Color("67505b")
	var brass := Color("c3a069")
	var steel := Color("8ca6b6")
	var light := Color("e5f6f7")
	# Receiver and short hammer meet a slender, flat-ended steel barrel.
	image.fill_rect(Rect2i(4, 12, 28, 12), outline)
	image.fill_rect(Rect2i(12, 8, 20, 4), outline)
	image.fill_rect(Rect2i(28, 12, 32, 12), outline)
	image.fill_rect(Rect2i(16, 12, 12, 8), brass)
	image.fill_rect(Rect2i(28, 16, 28, 4), steel)
	image.fill_rect(Rect2i(32, 12, 24, 4), light)
	image.fill_rect(Rect2i(52, 8, 4, 4), outline)
	# A small L-shaped grip and open trigger guard make this read as a gun.
	image.fill_rect(Rect2i(8, 20, 12, 12), outline)
	image.fill_rect(Rect2i(12, 24, 4, 4), leather)
	image.fill_rect(Rect2i(20, 24, 12, 4), outline)
	image.fill_rect(Rect2i(28, 20, 4, 4), brass)
	image.fill_rect(Rect2i(24, 20, 4, 4), Color.TRANSPARENT)
	image.fill_rect(Rect2i(8, 16, 4, 4), Color("ffd4ad"))
	_texture_cache = ImageTexture.create_from_image(image)
	return _texture_cache

static func geometry() -> Dictionary:
	return {"pivot": Vector2(10, 18), "tip": Vector2(58, 18)}
