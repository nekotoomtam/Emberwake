extends RefCounted
## World-space buckets narrow the candidates for short-range separation.
## The caller keeps this index current in the same order as enemy updates.
var actors: Array = []
var buckets: Dictionary = {}
var cells: Array[Vector2i] = []


func rebuild(snapshot: Array) -> void:
	actors = snapshot
	buckets.clear()
	cells.resize(actors.size())
	for index in actors.size():
		var actor = actors[index]
		if not is_instance_valid(actor) or actor.dead:
			continue
		var cell := cell_at(actor.global_position)
		cells[index] = cell
		insert(cell, index)


func refresh(index: int) -> void:
	var actor = actors[index]
	if not is_instance_valid(actor) or actor.dead:
		return
	var cell := cell_at(actor.global_position)
	var before := cells[index]
	if before == cell:
		return
	var previous: Array = buckets[before]
	previous.erase(index)
	if previous.is_empty():
		buckets.erase(before)
	cells[index] = cell
	insert(cell, index)


func nearby(at: Vector3, radius: float) -> Array:
	var low := cell_at(at - Vector3(radius, 0, radius))
	var high := cell_at(at + Vector3(radius, 0, radius))
	var indices: Array[int] = []
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			var cell := Vector2i(x, z)
			if buckets.has(cell):
				indices.append_array(buckets[cell])
	# Preserve the original sum order when multiple neighbors push at once.
	indices.sort()
	var found: Array = []
	for index in indices:
		found.append(actors[index])
	return found


func insert(cell: Vector2i, index: int) -> void:
	if not buckets.has(cell):
		buckets[cell] = []
	buckets[cell].append(index)


func cell_at(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x), floori(at.z))
