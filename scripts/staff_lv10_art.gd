extends RefCounted

const LIGHTNING = preload("res://assets/combat/staff_chain_lightning_frames.png")
const FIRE_BREATH = preload("res://assets/combat/staff_fire_breath_frames.png")
const CELL := Vector2i(362, 362)
const BREATH_CELL := Vector2i(543, 724)
const CHARGE := 0
const FLIGHT := 1
const IMPACT := 2
const FRAME_COUNT := 4
const PIVOTS := [
	[Vector2(212, 199), Vector2(189, 201), Vector2(172, 199), Vector2(153, 196)],
	[Vector2(312, 178), Vector2(304, 175), Vector2(284, 176), Vector2(271, 176)],
	[Vector2(211, 158), Vector2(190, 157), Vector2(166, 157), Vector2(154, 157)],
]
const BREATH_PIVOTS := [Vector2(76, 361), Vector2(75, 361), Vector2(78, 360), Vector2(76, 361)]
const BREATH_LENGTH := 424.0
const BREATH_WIDTH := 285.0

static var _frames: Dictionary = {}

static func frame(row: int, index: int) -> AtlasTexture:
	return _frame(LIGHTNING, Vector2i(index, row), CELL)

static func breath_frame(index: int) -> AtlasTexture:
	return _frame(FIRE_BREATH, Vector2i(index, 0), BREATH_CELL)

static func _frame(sheet: Texture2D, cell: Vector2i, size: Vector2i) -> AtlasTexture:
	var key := Vector3i(cell.x, cell.y, size.x)
	if not _frames.has(key):
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2i(cell * size, size)
		texture.filter_clip = true
		_frames[key] = texture
	return _frames[key]

static func offset(row: int, index: int) -> Vector2:
	return Vector2(CELL) * .5 - PIVOTS[row][index]

static func offset_3d(row: int, index: int) -> Vector2:
	return offset(row, index) * Vector2(1, -1)

static func breath_offset(index: int) -> Vector2:
	return (Vector2(BREATH_CELL) * .5 - BREATH_PIVOTS[index]) * Vector2(1, -1)
