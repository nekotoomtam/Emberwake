extends Control
## A compact view of the seeded room graph, redrawn when progress changes.

const EDGE := Color("#60777e")
const ROOM := Color("#263942")
const UNEXPLORED := Color("#10161e")
const UNKNOWN_EDGE := Color("#40515e")
const CLEARED := Color("#84d3b2")
const CURRENT := Color("#f0c88b")
const START_MARK := Color("#8fd3f3")

var _dungeon
var _seed: int
var _current: Vector2i
var _cleared := -1

func refresh(dungeon) -> void:
	if dungeon == _dungeon and dungeon.seed_value == _seed and dungeon.current == _current and dungeon.cleared == _cleared:
		return
	_dungeon = dungeon
	_seed = dungeon.seed_value
	_current = dungeon.current
	_cleared = dungeon.cleared
	queue_redraw()

func _draw() -> void:
	if _dungeon == null: return
	var known: Dictionary = _dungeon.map_rooms()
	if known.is_empty(): return
	var rooms: Dictionary = _dungeon.rooms
	var first: Vector2i = known.keys()[0]
	var low := first
	var high := first
	for at: Vector2i in known:
		low = low.min(at)
		high = high.max(at)
	var span := Vector2(high - low + Vector2i.ONE)
	var spacing := minf(30.0, minf(size.x / span.x, size.y / span.y))
	var origin := (size - Vector2(high - low) * spacing) * .5
	var side := spacing * .65
	for at: Vector2i in known:
		var center := origin + Vector2(at - low) * spacing
		if not known[at]: continue
		for direction: Vector2i in rooms[at].links:
			var neighbor: Vector2i = rooms[at].links[direction]
			if known[neighbor] and direction in [Vector2i.LEFT, Vector2i.UP]: continue
			draw_line(center, center + Vector2(direction) * spacing, EDGE if known[neighbor] else UNKNOWN_EDGE, 2.0)
	for at: Vector2i in known:
		var center := origin + Vector2(at - low) * spacing
		var bounds := Rect2(center - Vector2.ONE * side * .5, Vector2.ONE * side)
		if not known[at]:
			draw_rect(bounds, UNEXPLORED)
			draw_rect(bounds, UNKNOWN_EDGE, false)
			continue
		var done: bool = rooms[at].cleared
		draw_rect(bounds, Color("#244d48") if done else ROOM)
		draw_rect(bounds, CURRENT if at == _current else EDGE, false, 2.0 if at == _current else 1.0)
		if at == _dungeon.start:
			draw_circle(center, side * .19, START_MARK, true, -1.0, true)
		elif done:
			var check_mark := PackedVector2Array([
				center + Vector2(-.26, .0) * side,
				center + Vector2(-.07, .19) * side,
				center + Vector2(.27, -.22) * side,
			])
			draw_polyline(check_mark, CLEARED, 2.0, true)
		elif at == _current:
			draw_circle(center, side * .14, CURRENT, true, -1.0, true)
