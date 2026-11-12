extends RefCounted

const METEOR = preload("res://assets/combat/staff_meteor_frames.png")
const FOCUS = preload("res://assets/combat/staff_focus_frames.png")
const FLIGHT := 0
const IMPACT := 1
const FOCUS_ORB := 2
const FOCUS_FLASH := 3
const FRAME_COUNT := 4
const PIVOTS := [
	[Vector2(333, 303), Vector2(333, 303), Vector2(333, 303), Vector2(333, 303)],
	[Vector2(228, 337), Vector2(218, 337), Vector2(218, 337), Vector2(218, 337)],
	[Vector2(226, 220), Vector2(222, 220), Vector2(222, 220), Vector2(219, 218)],
	[Vector2(223, 222), Vector2(222, 221), Vector2(219, 218), Vector2(222, 220)],
]

static var _frames: Dictionary = {}

static func frame(row: int, index: int) -> AtlasTexture:
	var key := Vector2i(index, row)
	if not _frames.has(key):
		var texture := AtlasTexture.new()
		texture.atlas = METEOR if row < FOCUS_ORB else FOCUS
		var top := floori(float(row % 2) * 443.5)
		var left := floori(float(index) * 443.5)
		texture.region = Rect2i(left, top, floori((index + 1) * 443.5) - left, floori((row % 2 + 1) * 443.5) - top)
		texture.filter_clip = true
		_frames[key] = texture
	return _frames[key]

static func offset(row: int, index: int) -> Vector2:
	return frame(row, index).region.size * .5 - PIVOTS[row][index]

static func offset_3d(row: int, index: int) -> Vector2:
	return offset(row, index) * Vector2(1, -1)
