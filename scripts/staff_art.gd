extends RefCounted
## Elemental crystal in a silver cage, painted in four-pixel clusters.

static var _texture_cache := {}
const CRYSTALS := {
	"unattuned": [Color("54586d"), Color("a0aec9"), Color("e3eaf4")],
	"fire": [Color("963c38"), Color("ff9349"), Color("ffe1a7")],
	"ice": [Color("326c94"), Color("73dcff"), Color("d9faff")],
	"lightning": [Color("6545a1"), Color("ba9aff"), Color("eee3ff")],
	"neutral": [Color("252033"), Color("554168"), Color("a285c4")],
}

static func texture(baked_hand: bool = true, element: String = "unattuned") -> ImageTexture:
	if not CRYSTALS.has(element): element = "unattuned"
	var key := [baked_hand, element]
	if _texture_cache.has(key): return _texture_cache[key]
	var image := Image.create(96, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var gem: Array = CRYSTALS[element]
	var palette := {
		"o": Color("272633"),
		"w": Color("5b4851"),
		"m": Color("596879"),
		"s": Color("b4c5d2"),
		"d": gem[0],
		"c": gem[1],
		"h": gem[2],
		"k": Color("ffd4ad"),
	}
	image.fill_rect(Rect2i(4, 16, 64, 12), palette.o)
	var shaft := "mwkwwwwwwmwwswwm" if baked_hand else "mwwwwwwwwmwwswwm"
	for x in shaft.length():
		image.fill_rect(Rect2i(4 + x * 4, 20, 4, 4), palette[shaft.substr(x, 1)])
	var crown := ["...m...", "..sms..", ".sdcds.", "mschcsm", "mschcsm", ".sdcds.", "..sms..", "...m..."]
	for y in crown.size():
		for x in crown[y].length():
			var part: String = crown[y].substr(x, 1)
			if palette.has(part):
				image.fill_rect(Rect2i(64 + x * 4, 4 + y * 4, 4, 4), palette[part])
	_texture_cache[key] = ImageTexture.create_from_image(image)
	return _texture_cache[key]

static func geometry() -> Dictionary:
	return {"pivot": Vector2(12, 20), "tip": Vector2(92, 20)}
