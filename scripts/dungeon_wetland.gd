extends RefCounted
## Seeded stream and mud footprints. Their combined area is capped per clearing.
const MAX_COVERAGE := .40


static func plan(outline: PackedVector2Array, seed_: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var zones: Array[Dictionary] = []
	var interior := Geometry2D.offset_polygon(outline, -1.65, Geometry2D.JOIN_ROUND)
	if interior.is_empty(): return zones
	var bounds := _bounds(outline)
	var room_area := area(outline)
	var budget := room_area * MAX_COVERAGE
	var mixed := rng.randf() < .32
	var first := "water" if rng.randf() < .5 else "mud"
	var kinds := [first, "mud" if first == "water" else "water"] if mixed else [first]
	var reserved: Array[PackedVector2Array] = []
	for kind: String in kinds:
		var fraction := rng.randf_range(.10, .19) if mixed else rng.randf_range(.14, .39)
		var patch := _place_patch(kind, minf(budget, room_area * fraction), bounds, interior, reserved, rng)
		if patch.is_empty(): continue
		var size := area(patch)
		if size > budget: continue
		budget -= size
		zones.append({"kind": kind, "outline": patch, "bounds": _bounds(patch)})
		reserved.append_array(Geometry2D.offset_polygon(patch, 2.1, Geometry2D.JOIN_ROUND))
	return zones


static func _place_patch(kind: String, target: float, bounds: Rect2, interior: Array[PackedVector2Array],
		reserved: Array[PackedVector2Array], rng: RandomNumberGenerator) -> PackedVector2Array:
	var shell := _shore_shape(kind, rng)
	var scale := sqrt(target / area(shell))
	for attempt in 54:
		var center := Vector2(rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y))
		var rotation := rng.randf_range(-PI, PI)
		var clearing := PackedVector2Array()
		for region in interior:
			if Geometry2D.is_point_in_polygon(center, region):
				clearing = region
				break
		if clearing.is_empty(): continue
		# Reduce the footprint on later attempts, especially in tighter clearings.
		var radius := scale * lerpf(1.0, .43, smoothstep(0.12, 1.0, attempt / 53.0))
		var patch := _transform_patch(shell, center, rotation, radius)
		if not Geometry2D.clip_polygons(patch, clearing).is_empty(): continue
		if reserved.any(func(bank: PackedVector2Array) -> bool: return not Geometry2D.intersect_polygons(patch, bank).is_empty()):
			continue
		return patch
	if not reserved.is_empty(): return PackedVector2Array()

	# A narrow clearing still gets one patch. Pick a point with room on all sides.
	var best_center := Vector2.ZERO
	var best_clearance := 0.0
	for region in interior:
		var triangles := Geometry2D.triangulate_polygon(region)
		for index in range(0, triangles.size(), 3):
			var center := (region[triangles[index]] + region[triangles[index + 1]] + region[triangles[index + 2]]) / 3.0
			var clearance := INF
			for edge in region.size():
				var nearest := Geometry2D.get_closest_point_to_segment(center, region[edge], region[(edge + 1) % region.size()])
				clearance = minf(clearance, center.distance_to(nearest))
			if clearance > best_clearance:
				best_center = center
				best_clearance = clearance
	if best_clearance == 0.0: return PackedVector2Array()
	var reach := 0.0
	for point in shell:
		reach = maxf(reach, point.length())
	return _transform_patch(shell, best_center, rng.randf_range(-PI, PI), minf(scale, best_clearance * .96 / reach))


static func _transform_patch(shell: PackedVector2Array, center: Vector2, rotation: float, scale: float) -> PackedVector2Array:
	var patch := PackedVector2Array()
	for point in shell:
		patch.append(center + point.rotated(rotation) * scale)
	return patch


static func _shore_shape(kind: String, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var phase := rng.randf_range(0, TAU)
	var aspect := rng.randf_range(2.7, 4.0) if kind == "water" else rng.randf_range(1.05, 1.65)
	for index in 24:
		var angle := TAU * index / 24.0
		var ripple := 1.0 + .12 * sin(angle * 3.0 + phase) + .07 * cos(angle * 5.0 - phase)
		var point := Vector2(cos(angle) * aspect, sin(angle)) * ripple
		if kind == "water": point.y += .59 * sin(point.x / aspect * 2.6 + phase)
		points.append(point)
	return points


static func area(outline: PackedVector2Array) -> float:
	var total := 0.0
	for index in outline.size():
		total += outline[index].cross(outline[(index + 1) % outline.size()])
	return absf(total) * .5


static func _bounds(outline: PackedVector2Array) -> Rect2:
	var result := Rect2(outline[0], Vector2.ZERO)
	for point in outline: result = result.expand(point)
	return result
