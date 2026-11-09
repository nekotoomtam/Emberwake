extends RefCounted
## Draws only the eye layer. The selected face provides its palette and fit.
const FRAMES = preload("res://modular/data/eye_frames.json")
static var cached: Dictionary = {}

static func texture(view: String, phase: int, iris: Color, lid: Color, white: Color, shadow: Color, wide_front: bool = false) -> Texture2D:
	if view == "back":
		return null
	var layout := "front_wide" if view == "front" and wide_front else view
	var key := [layout, phase, iris, lid, white, shadow]
	if cached.has(key):
		return cached[key]
	var image := Image.create_empty(32,40,false,Image.FORMAT_RGBA8)
	var palette := {"iris":iris,"lid":lid,"white":white,"shadow":shadow}
	for pixel: Array in FRAMES.data[layout][phase]:
		image.set_pixel(int(pixel[0]),int(pixel[1]),palette[pixel[2]])
	var frame := ImageTexture.create_from_image(image)
	cached[key] = frame
	return frame
