extends RefCounted

static var _bows: Dictionary = {}
static var _arrow: Texture2D

static func geometry() -> Dictionary:
	return {"pivot": Vector2(22, 18), "tip": Vector2(30, 18)}

static func string_point(tier: int) -> Vector2:
	return Vector2(13 - maxi(0, tier - 1) * 3, 18)

static func texture(tier: int = 0) -> Texture2D:
	if _bows.has(tier): return _bows[tier]
	var image := Image.create_empty(34, 37, false, Image.FORMAT_RGBA8)
	var tips := [Vector2i(13, 3), Vector2i(13, 33)]
	var nock := Vector2i(string_point(tier))
	for tip in tips:
		_line(image, tip, nock, Color("#e9d9ba"), 1)
	var limbs := [tips[0], Vector2i(20, 5), Vector2i(23, 10), Vector2i(22, 18), Vector2i(23, 26), Vector2i(20, 31), tips[1]]
	for index in limbs.size() - 1:
		_line(image, limbs[index], limbs[index + 1], Color("#342328"), 4)
		_line(image, limbs[index], limbs[index + 1], Color("#d8995a"), 2)
	_line(image, Vector2i(22, 15), Vector2i(22, 21), Color("#72463a"), 3)
	if tier > 0:
		_line(image, nock, Vector2i(30, 18), Color("#f3c58a"), 1)
		_line(image, Vector2i(27, 17), Vector2i(30, 18), Color("#f4f1de"), 1)
		_line(image, Vector2i(27, 19), Vector2i(30, 18), Color("#f4f1de"), 1)
	_bows[tier] = ImageTexture.create_from_image(image)
	return _bows[tier]

static func arrow_texture() -> Texture2D:
	if _arrow != null: return _arrow
	var image := Image.create_empty(18, 7, false, Image.FORMAT_RGBA8)
	_line(image, Vector2i(0, 3), Vector2i(16, 3), Color("#442b2b"), 2)
	_line(image, Vector2i(0, 3), Vector2i(17, 3), Color("#f3c58a"), 1)
	_line(image, Vector2i(12, 1), Vector2i(17, 3), Color("#f4f1de"), 1)
	_line(image, Vector2i(12, 5), Vector2i(17, 3), Color("#f4f1de"), 1)
	_line(image, Vector2i(1, 1), Vector2i(4, 3), Color("#b8e8de"), 1)
	_line(image, Vector2i(1, 5), Vector2i(4, 3), Color("#b8e8de"), 1)
	_arrow = ImageTexture.create_from_image(image)
	return _arrow

static func _line(image: Image, start: Vector2i, end: Vector2i, color: Color, width: int) -> void:
	var steps := maxi(absi(end.x - start.x), absi(end.y - start.y))
	for step in steps + 1:
		var point := Vector2i(Vector2(start).lerp(Vector2(end), float(step) / maxi(steps, 1)).round())
		image.fill_rect(Rect2i(point - Vector2i.ONE * (width / 2), Vector2i.ONE * width), color)
