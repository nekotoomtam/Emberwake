extends RefCounted

static var _textures: Dictionary = {}
static var _bolt: Texture2D

static func geometry() -> Dictionary:
	return {"pivot": Vector2(10, 14), "tip": Vector2(40, 14)}

static func texture(loaded: bool = false) -> Texture2D:
	if _textures.has(loaded): return _textures[loaded]
	var image := Image.create_empty(48, 29, false, Image.FORMAT_RGBA8)
	var outline := Color("#33272c")
	image.fill_rect(Rect2i(2, 10, 37, 9), outline)
	image.fill_rect(Rect2i(4, 11, 34, 5), Color("#9a6045"))
	image.fill_rect(Rect2i(5, 11, 32, 2), Color("#d39a62"))
	image.fill_rect(Rect2i(9, 16, 6, 6), outline)
	image.fill_rect(Rect2i(10, 16, 4, 4), Color("#8d614d"))
	for y in range(3, 26):
		var x := 36 - floori(absf(y - 14) * 0.65)
		image.fill_rect(Rect2i(x - 1, y, 5, 1), outline)
		image.fill_rect(Rect2i(x, y, 3, 1), Color("#c09b74"))
		var string_x := lerpf(17 if loaded else 29, 29, absf(y - 14) / 11.0)
		image.set_pixel(roundi(string_x), y, Color("#e2d1a6"))
	image.fill_rect(Rect2i(27, 12, 4, 5), Color("#505661"))
	if loaded:
		image.fill_rect(Rect2i(15, 13, 27, 1), Color("#f3cf95"))
		image.fill_rect(Rect2i(39, 12, 4, 3), Color("#bfcad1"))
		image.set_pixel(43, 13, Color("#e9f0e8"))
	_textures[loaded] = ImageTexture.create_from_image(image)
	return _textures[loaded]

static func bolt_texture() -> Texture2D:
	if _bolt != null: return _bolt
	var image := Image.create_empty(18, 7, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(1, 3, 16, 2), Color("#4c312c"))
	image.fill_rect(Rect2i(2, 3, 13, 1), Color("#f2bf85"))
	image.fill_rect(Rect2i(12, 2, 4, 3), Color("#a9bac6"))
	image.fill_rect(Rect2i(15, 3, 3, 1), Color("#e7eeeb"))
	image.fill_rect(Rect2i(0, 2, 3, 3), Color("#b4695b"))
	_bolt = ImageTexture.create_from_image(image)
	return _bolt
