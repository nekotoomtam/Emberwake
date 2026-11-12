extends RefCounted
## Slim one-hand blade drawn at the heroine's native world pixel size.
## The single hand, compact guard and blade form one rigid +X sprite.

static var _texture_cache := {}

static func texture(baked_hand: bool = true) -> Texture2D:
	if _texture_cache.has(baked_hand):
		return _texture_cache[baked_hand]
	var image := Image.create(120, 28, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var outline := Color("263141")
	var leather := Color("67505b")
	var gold := Color("c3a069")
	var steel := Color("8ca6b6")
	var light := Color("e5f6f7")
	# A small pommel and narrow wrapped grip stop close behind the hand.
	image.fill_rect(Rect2i(2, 10, 6, 8), outline)
	image.fill_rect(Rect2i(3, 12, 3, 4), gold)
	image.fill_rect(Rect2i(6, 10, 16, 8), outline)
	image.fill_rect(Rect2i(6, 12, 14, 4), leather)
	image.fill_rect(Rect2i(14, 12, 2, 4), gold)
	# The straight blade loses width in small steps toward a long, fine point.
	var spans := [[24, 20, 7], [44, 28, 6], [72, 18, 5], [90, 12, 4], [102, 6, 3], [108, 4, 2], [112, 4, 1]]
	for span in spans:
		var x: int = span[0]
		var width: int = span[1]
		var half_height: int = span[2]
		image.fill_rect(Rect2i(x, 14 - half_height, width, half_height * 2), outline)
		if half_height > 2:
			image.fill_rect(Rect2i(x, 16 - half_height, width, half_height * 2 - 4), steel)
	image.fill_rect(Rect2i(26, 10, 44, 3), Color("b9d0d8"))
	image.fill_rect(Rect2i(26, 13, 76, 2), light)
	image.fill_rect(Rect2i(102, 13, 10, 2), steel)
	# Short quillons leave the small hand visible and never dominate the blade.
	image.fill_rect(Rect2i(20, 4, 4, 20), outline)
	image.fill_rect(Rect2i(18, 4, 4, 4), outline)
	image.fill_rect(Rect2i(22, 20, 4, 4), outline)
	image.fill_rect(Rect2i(21, 6, 2, 16), gold)
	image.fill_rect(Rect2i(19, 5, 2, 2), gold)
	image.fill_rect(Rect2i(23, 21, 2, 2), gold)
	# Four native pixels match one of the heroine's logical skin clusters.
	if baked_hand:
		image.fill_rect(Rect2i(8, 12, 4, 4), Color("ffd4ad"))
	_texture_cache[baked_hand] = ImageTexture.create_from_image(image)
	return _texture_cache[baked_hand]

static func geometry() -> Dictionary:
	return {"pivot": Vector2(10, 14), "tip": Vector2(116, 14)}
