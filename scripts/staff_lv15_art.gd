extends RefCounted

const ICE = preload("res://assets/combat/staff_ground_ice_frames.png")
const MANA_RING = preload("res://assets/combat/staff_mana_ring_frames.png")
const CELL := Vector2i(543, 724)
const IMPACT := 0
const FRAME_COUNT := 4
const ICE_PIVOTS := [Vector2(270, 528), Vector2(275, 526), Vector2(269, 529), Vector2(266, 531)]
const RING_PIVOTS := [Vector2(270, 350), Vector2(268, 350), Vector2(272, 355), Vector2(266, 349)]
const RING_DIAMETER := 410.0

static var _frames: Dictionary = {}

static func frame(_row: int, index: int) -> AtlasTexture:
	return _frame(ICE, index)

static func ring_frame(index: int) -> AtlasTexture:
	return _frame(MANA_RING, index)

static func _frame(sheet: Texture2D, index: int) -> AtlasTexture:
	var key := [sheet, index]
	if not _frames.has(key):
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2i(Vector2i(index * CELL.x, 0), CELL)
		texture.filter_clip = true
		_frames[key] = texture
	return _frames[key]

static func offset_3d(_row: int, index: int) -> Vector2:
	return (Vector2(CELL) * .5 - ICE_PIVOTS[index]) * Vector2(1, -1)

static func ring_offset(index: int) -> Vector2:
	return (Vector2(CELL) * .5 - RING_PIVOTS[index]) * Vector2(1, -1)
