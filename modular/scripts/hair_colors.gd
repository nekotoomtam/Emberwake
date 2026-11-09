extends RefCounted

const DATA := preload("res://modular/data/hair_colors.json")
const GROUPS := ["All groups", "Dark", "Brown", "Blonde", "Copper", "Silver", "Fantasy"]

static func choices(group_index: int) -> Array:
	if group_index > 0:
		return DATA.data.groups[group_index - 1].colors
	var all: Array = []
	for group: Dictionary in DATA.data.groups:
		all.append_array(group.colors)
	return all


static func replacement_map(hair_id: String, palette: Dictionary) -> Dictionary:
	var source: Dictionary = DATA.data.profiles[hair_id]
	var result := {}
	var stops: Array = palette.stops
	for code: String in source:
		var level := float(source[code]) / 20.0
		var index := mini(3, int(level))
		var start := Color.html(stops[index])
		var finish := Color.html(stops[index + 1])
		result[Color.html(code).to_rgba32()] = start.lerp(finish, level - index)
	return result


static func recolor(texture: Texture2D, mapping: Dictionary) -> Texture2D:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	for y in image.get_height():
		for x in image.get_width():
			var original := image.get_pixel(x, y)
			var key := original.to_rgba32()
			if mapping.has(key):
				image.set_pixel(x, y, mapping[key])
	return ImageTexture.create_from_image(image)
