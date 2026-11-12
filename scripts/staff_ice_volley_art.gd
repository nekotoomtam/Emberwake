extends RefCounted

const SHEET = preload("res://assets/combat/staff_ice_volley_frames.png")
const CELL := Vector2i(362, 362)
const CHARGE := 0
const FLIGHT := 1
const IMPACT := 2
const FRAME_COUNT := 4
const PIVOTS := [
	[Vector2(219, 206), Vector2(198, 206), Vector2(160, 196), Vector2(133, 180)],
	[Vector2(276, 178), Vector2(267, 176), Vector2(248, 177), Vector2(217, 176)],
	[Vector2(216, 156), Vector2(190, 152), Vector2(162, 156), Vector2(123, 156)],
]

static var _frames: Dictionary = {}

static func frame(row: int, index: int) -> AtlasTexture:
	var cell := Vector2i(index, row)
	if not _frames.has(cell):
		var texture := AtlasTexture.new()
		texture.atlas = SHEET
		texture.region = Rect2i(cell * CELL, CELL)
		texture.filter_clip = true
		_frames[cell] = texture
	return _frames[cell]

static func offset(row: int, index: int) -> Vector2:
	return Vector2(CELL) * .5 - PIVOTS[row][index]

static func offset_3d(row: int, index: int) -> Vector2:
	return offset(row, index) * Vector2(1, -1)
