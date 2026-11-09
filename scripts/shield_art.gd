extends RefCounted

static var _texture: Texture2D

static func geometry() -> Dictionary:
	return {"pivot": Vector2(16, 18), "tip": Vector2(29, 18)}

static func texture() -> Texture2D:
	if _texture != null: return _texture
	var image := Image.create_empty(33, 39, false, Image.FORMAT_RGBA8)
	for y in range(2, 37):
		var inset := maxi(0, 5 - y) + maxi(0, (y - 19) * 4 / 5)
		var left := 2 + inset
		var right := 31 - inset
		image.fill_rect(Rect2i(left, y, right - left, 1), Color("#272733"))
		if y < 4 or y > 34 or right - left < 7: continue
		image.fill_rect(Rect2i(left + 1, y, right - left - 2, 1), Color("#aab3ba"))
		image.fill_rect(Rect2i(left + 3, y, right - left - 6, 1), Color("#426779"))
		if right - 3 > 17:
			image.fill_rect(Rect2i(17, y, right - 20, 1), Color("#2f4c62"))
	image.fill_rect(Rect2i(15, 7, 3, 21), Color("#ca9b60"))
	image.fill_rect(Rect2i(9, 13, 15, 3), Color("#ca9b60"))
	image.fill_rect(Rect2i(15, 12, 3, 5), Color("#e8be7c"))
	for rivet in [Vector2i(6, 6), Vector2i(26, 6), Vector2i(6, 19), Vector2i(26, 19)]:
		image.fill_rect(Rect2i(rivet, Vector2i(2, 2)), Color("#e8c383"))
	_texture = ImageTexture.create_from_image(image)
	return _texture
