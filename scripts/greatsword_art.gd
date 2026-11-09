extends RefCounted
## Long, broad +X blade with a compact two-hand hilt and fine pixel outlines.
## The hilt occupies one fifth of the silhouette; its hands are native clusters.

static var _texture_cache: Texture2D

static func texture() -> Texture2D:
	if _texture_cache != null:
		return _texture_cache
	var image := Image.create(150, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var outline := Color("263141")
	var leather := Color("67505b")
	var gold := Color("c3a069")
	var steel := Color("8ca6b6")
	var light := Color("e5f6f7")
	# A close pommel and short, continuous grip support two small skin clusters.
	image.fill_rect(Rect2i(2, 16, 6, 8), outline)
	image.fill_rect(Rect2i(3, 18, 3, 4), gold)
	image.fill_rect(Rect2i(6, 16, 26, 8), outline)
	image.fill_rect(Rect2i(6, 18, 24, 4), leather)
	image.fill_rect(Rect2i(16, 18, 2, 4), gold)
	# The broad parallel blade retains its weight across most of the length,
	# then closes into a deliberate stepped spear point.
	var spans := [[34, 4, 8], [38, 78, 10], [116, 10, 8], [126, 8, 6], [134, 6, 4], [140, 4, 2], [144, 2, 1]]
	for span in spans:
		var x: int = span[0]
		var width: int = span[1]
		var half_height: int = span[2]
		image.fill_rect(Rect2i(x, 20 - half_height, width, half_height * 2), outline)
		if half_height > 2:
			image.fill_rect(Rect2i(x, 22 - half_height, width, half_height * 2 - 4), steel)
	image.fill_rect(Rect2i(40, 12, 74, 6), Color("b9d0d8"))
	image.fill_rect(Rect2i(40, 19, 94, 2), light)
	image.fill_rect(Rect2i(134, 19, 10, 2), steel)
	# Short gold quillons frame the blade shoulder without a tall gold cross.
	image.fill_rect(Rect2i(30, 8, 4, 24), outline)
	image.fill_rect(Rect2i(28, 8, 4, 4), outline)
	image.fill_rect(Rect2i(32, 28, 4, 4), outline)
	image.fill_rect(Rect2i(31, 10, 2, 20), gold)
	image.fill_rect(Rect2i(29, 9, 2, 2), gold)
	image.fill_rect(Rect2i(33, 29, 2, 2), gold)
	image.fill_rect(Rect2i(10, 18, 4, 4), Color("ffd4ad"))
	image.fill_rect(Rect2i(20, 18, 4, 4), Color("ffd4ad"))
	_texture_cache = ImageTexture.create_from_image(image)
	return _texture_cache

static func geometry() -> Dictionary:
	return {"pivot": Vector2(12, 20), "tip": Vector2(146, 20)}
