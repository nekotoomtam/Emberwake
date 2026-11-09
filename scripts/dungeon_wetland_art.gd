extends RefCounted
## Paints the wet surface and the bare soil around it using the same shoreline.
const Forest = preload("res://scripts/dungeon_forest.gd")
const GroundShader = preload("res://shaders/dungeon_wetland_ground.gdshader")
const FIELD_RANGE := 3.0
const BANK_PADDING := 1.8


static func surface(outline: PackedVector2Array, footprint: Rect2, water: bool) -> MeshInstance3D:
	var bounds := footprint.grow(BANK_PADDING)
	var dirt: StandardMaterial3D = Forest.surfaces().soil
	var axis := (outline[0] - outline[outline.size() / 2]).normalized()
	var material := ShaderMaterial.new()
	material.shader = GroundShader
	material.set_shader_parameter("shore_field", _shore_field(outline, bounds))
	material.set_shader_parameter("field_range", FIELD_RANGE)
	material.set_shader_parameter("soil_texture", dirt.albedo_texture)
	material.set_shader_parameter("soil_uv_scale", Vector2(dirt.uv1_scale.x, dirt.uv1_scale.y) * .42)
	material.set_shader_parameter("patch_origin", bounds.position)
	material.set_shader_parameter("patch_size", bounds.size)
	material.set_shader_parameter("flow_axis", axis)
	material.set_shader_parameter("water", water)
	var plane := PlaneMesh.new()
	plane.size = bounds.size
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = material
	node.position = Vector3(bounds.get_center().x, .028, bounds.get_center().y)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _shore_field(outline: PackedVector2Array, bounds: Rect2) -> ImageTexture:
	var width := clampi(ceili(bounds.size.x * 3.7), 16, 112)
	var height := clampi(ceili(bounds.size.y * 3.7), 16, 112)
	var values := PackedByteArray()
	values.resize(width * height)
	for y in height:
		for x in width:
			var uv := Vector2((x + .5) / width, (y + .5) / height)
			var point := bounds.position + uv * bounds.size
			var distance_squared := FIELD_RANGE * FIELD_RANGE
			for index in outline.size():
				var closest := Geometry2D.get_closest_point_to_segment(point, outline[index], outline[(index + 1) % outline.size()])
				distance_squared = minf(distance_squared, closest.distance_squared_to(point))
			var distance := sqrt(distance_squared)
			if Geometry2D.is_point_in_polygon(point, outline): distance = -distance
			values[y * width + x] = roundi((.5 + distance / (FIELD_RANGE * 2.0)) * 255.0)
	return ImageTexture.create_from_image(Image.create_from_data(width, height, false, Image.FORMAT_R8, values))
