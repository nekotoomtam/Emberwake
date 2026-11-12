extends RefCounted

const SHEET = preload("res://assets/combat/staff_charged_fire_frames.png")
const CELL := Vector2i(362, 362)
const CHARGE := 0
const FLIGHT := 1
const IMPACT := 2
const FRAME_COUNT := 4
const PIVOTS := [
	[Vector2(190, 194), Vector2(185, 193), Vector2(181, 194), Vector2(180, 192)],
	[Vector2(270, 191), Vector2(274, 189), Vector2(280, 190), Vector2(282, 190)],
	[Vector2(181, 236), Vector2(176, 232), Vector2(180, 233), Vector2(180, 232)],
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
	# Sprite3D offsets use positive Y upward, while atlas pivots use image Y.
	return offset(row, index) * Vector2(1.0, -1.0)
