extends RefCounted
## Original wood-stocked brass/blue-steel long rifle in four-pixel clusters.
## The only tiny hand, receiver and muzzle share one rigid +X sprite.

static var _texture_cache: ImageTexture

static func texture() -> ImageTexture:
	if _texture_cache != null:
		return _texture_cache
	var image := Image.create(128, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var outline := Color("263141")
	var wood := Color("83523e")
	var wood_light := Color("b77b4c")
	var brass := Color("c3a069")
	var steel := Color("8ca6b6")
	var light := Color("e5f6f7")
	# A stepped shoulder stock and long wood forearm distinguish the rifle
	# from the compact pistol without making the attached hand any larger.
	image.fill_rect(Rect2i(4, 20, 28, 12), outline)
	image.fill_rect(Rect2i(8, 16, 20, 4), outline)
	image.fill_rect(Rect2i(4, 28, 8, 8), outline)
	image.fill_rect(Rect2i(8, 20, 16, 8), wood)
	image.fill_rect(Rect2i(8, 20, 12, 4), wood_light)
	image.fill_rect(Rect2i(12, 28, 12, 4), wood)
	image.fill_rect(Rect2i(28, 20, 56, 8), outline)
	image.fill_rect(Rect2i(32, 20, 48, 4), wood)
	image.fill_rect(Rect2i(64, 24, 16, 4), wood_light)
	# Brass action, short hammer and open trigger guard remain behind the
	# slender steel tube. The dark flat muzzle has no fire or glow baked in.
	image.fill_rect(Rect2i(28, 12, 32, 12), outline)
	image.fill_rect(Rect2i(32, 16, 24, 8), brass)
	image.fill_rect(Rect2i(32, 8, 8, 4), outline)
	image.fill_rect(Rect2i(36, 12, 4, 4), brass)
	image.fill_rect(Rect2i(56, 16, 68, 8), outline)
	image.fill_rect(Rect2i(60, 20, 60, 4), steel)
	image.fill_rect(Rect2i(64, 16, 56, 4), light)
	image.fill_rect(Rect2i(116, 12, 4, 4), outline)
	image.fill_rect(Rect2i(28, 28, 20, 4), outline)
	image.fill_rect(Rect2i(44, 24, 4, 4), outline)
	image.fill_rect(Rect2i(32, 28, 12, 4), brass)
	image.fill_rect(Rect2i(32, 24, 8, 4), Color.TRANSPARENT)
	image.fill_rect(Rect2i(24, 20, 4, 4), Color("ffd4ad"))
	_texture_cache = ImageTexture.create_from_image(image)
	return _texture_cache

static func geometry() -> Dictionary:
	return {"pivot": Vector2(26, 22), "tip": Vector2(122, 22)}
