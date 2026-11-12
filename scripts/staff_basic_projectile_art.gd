extends RefCounted

const SHEET = preload("res://assets/combat/staff_basic_projectile_frames.png")
const CELL := Vector2i(362, 362)
const ROWS := {"fire": 0, "ice": 1, "lightning": 2}
const PIVOTS := [
	[Vector2(241, 203), Vector2(242, 202), Vector2(242, 203), Vector2(242, 203)],
	[Vector2(270, 177), Vector2(270, 177), Vector2(270, 177), Vector2(270, 178)],
	[Vector2(269, 179), Vector2(270, 178), Vector2(270, 179), Vector2(270, 179)],
]

static var _frames: Dictionary = {}

static func frame(element: String, index: int) -> AtlasTexture:
	var cell := Vector2i(index, ROWS[element])
	if not _frames.has(cell):
		var texture := AtlasTexture.new()
		texture.atlas = SHEET
		texture.region = Rect2i(cell * CELL, CELL)
		texture.filter_clip = true
		_frames[cell] = texture
	return _frames[cell]

static func offset_3d(element: String, index: int) -> Vector2:
	var pivot: Vector2 = PIVOTS[ROWS[element]][index]
	return (Vector2(CELL) * .5 - pivot) * Vector2(1.0, -1.0)
