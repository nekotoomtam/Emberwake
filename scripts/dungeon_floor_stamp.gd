extends RefCounted

static func append(builder: SurfaceTool, outline: PackedVector2Array, center: Vector2,
		size: Vector2, rotation: float, height: float) -> bool:
	var corners := PackedVector2Array()
	for corner in [Vector2(-.5, -.5), Vector2(.5, -.5), Vector2(.5, .5), Vector2(-.5, .5)]:
		corners.append(center + (corner * size).rotated(rotation))
	var has_geometry := false
	var patches: Array[PackedVector2Array] = []
	if outline.is_empty():
		patches.append(corners)
	else:
		patches = Geometry2D.intersect_polygons(outline, corners)
	for clipped in patches:
		for index in Geometry2D.triangulate_polygon(clipped):
			var point := clipped[index]
			builder.set_normal(Vector3.UP)
			builder.set_uv((point - center).rotated(-rotation) / size + Vector2.ONE * .5)
			builder.add_vertex(Vector3(point.x, height, point.y))
			has_geometry = true
	return has_geometry
