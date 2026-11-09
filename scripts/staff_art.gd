extends RefCounted
## Original wooden fire staff in the accepted heroine's four-pixel clusters.
## One tiny grip hand, shaft and bronze fire crown form a single rigid +X body.

static var _texture_cache: ImageTexture

static func texture() -> ImageTexture:
	if _texture_cache != null:
		return _texture_cache
	var image := Image.create(96, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var palette := {
		"o": Color("302533"),
		"w": Color("83523e"),
		"b": Color("c38c4f"),
		"e": Color("b94332"),
		"r": Color("ef7d32"),
		"f": Color("ffd77c"),
		"k": Color("ffd4ad"),
	}
	# A narrow wood shaft and bronze ferrules stay physically joined to the
	# tiny hand. The grip never becomes a separate enlarged body part.
	image.fill_rect(Rect2i(4, 16, 64, 12), palette.o)
	var shaft := "bwkwwwwwwwwwbwww"
	for x in shaft.length():
		image.fill_rect(Rect2i(4 + x * 4, 20, 4, 4), palette[shaft.substr(x, 1)])
	# Stepped bronze prongs encircle a red-orange crystal with a pale hot core.
	# The crown is a compact round fire gem, distinct from all three blades.
	var crown := [".b...b.", "bob.ob.", "bororro", "boeffro", "boeffro", "bororro", "bob.ob.", ".b...b."]
	for y in crown.size():
		for x in crown[y].length():
			var key: String = crown[y].substr(x, 1)
			if palette.has(key):
				image.fill_rect(Rect2i(64 + x * 4, 4 + y * 4, 4, 4), palette[key])
	_texture_cache = ImageTexture.create_from_image(image)
	return _texture_cache

static func geometry() -> Dictionary:
	return {"pivot": Vector2(12, 20), "tip": Vector2(92, 20)}
