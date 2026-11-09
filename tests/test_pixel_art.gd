extends SceneTree

const ART_PATH = "res://scripts/pixel_art.gd"
var failures := 0

func _initialize() -> void:
	var art = load(ART_PATH)
	if art == null:
		push_error("Pixel art API is missing")
		quit(1)
		return
	var counts := {"idle": 2, "walk": 4, "attack": 3, "hit": 1, "death": 3}
	for kind in ["player", "melee", "ranged", "elite", "dummy"]:
		var frames: SpriteFrames = art.frames(kind)
		check(frames == art.frames(kind), "Cache should reuse %s SpriteFrames" % kind)
		for animation in counts:
			check(frames.has_animation(animation), "%s missing %s" % [kind, animation])
			check(frames.get_frame_count(animation) == counts[animation], "%s %s frame count" % [kind, animation])
			for index in counts[animation]:
				var texture: Texture2D = frames.get_frame_texture(animation, index)
				check(texture.get_size() == Vector2(128, 128), "Sprite canvas must be 128px")
				var used: Rect2i = texture.get_image().get_used_rect()
				check(used.size.x > 16 and used.size.y > 12, "Sprite must have visible pixels")
				check(used.end.y <= 112, "%s %s frame %d must stay above foot baseline" % [kind, animation, index])
	check(art.sword_texture().get_size() == Vector2(64, 20), "Sword canvas must be 64x20px")
	check(art.sword_texture() == art.sword_texture(), "Sword must be cached")
	check(art.sword_texture().get_image().get_pixel(12, 8).a > 0.0, "Sword pivot must be within the grip hand" )
	check(art.sword_texture().get_image().get_used_rect().end.x <= 60, "Sword tip must end within x60" )
	check(art.floor_texture().get_size() == Vector2(32, 32), "Floor tile must be 32px")
	if "--export-art" in OS.get_cmdline_user_args():
		export_contact_sheet(art)
	if failures == 0:
		print("PIXEL_ART_PASS: 5 characters, 65 frames, baseline112, sword64x20, tile32x32")
	quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func export_contact_sheet(art) -> void:
	var sheet := Image.create(128 * 13, 128 * 5, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("182531"))
	var row := 0
	for kind in ["player", "melee", "ranged", "elite", "dummy"]:
		var column := 0
		var frames: SpriteFrames = art.frames(kind)
		for animation in ["idle", "walk", "attack", "hit", "death"]:
			for index in frames.get_frame_count(animation):
				sheet.blend_rect(frames.get_frame_texture(animation, index).get_image(), Rect2i(0, 0, 128, 128), Vector2i(column * 128, row * 128))
				column += 1
		row += 1
	sheet.save_png("res://docs/pixel-art-contact-sheet.png")

