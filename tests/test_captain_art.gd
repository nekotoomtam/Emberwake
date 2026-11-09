extends SceneTree

var failures := 0

func _initialize() -> void:
	var path := "res://scripts/captain_art.gd"
	if not ResourceLoader.exists(path):
		check(false, "Captain procedural art API is missing")
		quit(1)
		return
	var art = load(path)
	var intact: SpriteFrames = art.frames()
	var cut: SpriteFrames = art.frames(true)
	var counts := {"idle": 2, "walk": 4, "attack": 3, "hit": 1, "death": 3, "sweep_windup":5,"sweep_active":4,"throw_windup":5,"throw_active":4,"slam_windup":5,"slam_active":3,"recover":4,"throw_reel":6,"sweep_recover":6,"throw_recover":6,"slam_recover":6}
	check(art.has_method("hand_pixel"), "Attachment wrist API exists")
	check(art.has_method("anchor_ring_pixel"), "Anchor ring center API exists")
	check(art.has_method("arm_center_pixel"), "Moving control arm center API exists")
	for required: String in counts:
		check(intact.has_animation(required), "Required tell animation %s" % required)
	if failures > 0:
		quit(1)
		return
	# Every phase boundary preserves the complete drawn pose and both wrists.
	var joins := [["throw_windup",4,"throw_active",0],["sweep_active",3,"sweep_recover",0],["throw_active",3,"throw_reel",0],["throw_reel",5,"throw_recover",0],["slam_active",2,"slam_recover",0],["sweep_recover",5,"idle",0],["throw_recover",5,"idle",0],["slam_recover",5,"idle",0]]
	for join: Array in joins:
		check(art._pose(join[0],join[1]) == art._pose(join[2],join[3]), "Exact shared joints at %s -> %s" % [join[0],join[2]])
		for severed in [false,true]:
			var posed: SpriteFrames = cut if severed else intact
			check(difference_count(posed.get_frame_texture(join[0],join[1]).get_image(),posed.get_frame_texture(join[2],join[3]).get_image()) == 0, "No pose image jump at phase boundary")
	check(art._pose("throw_reel",0) == art._pose("throw_reel",5), "Reel returns to exact cast endpoint")
	for severed in [false,true]:
		check(art.hand_pixel("throw_reel",1,severed).x < art.hand_pixel("throw_reel",0,severed).x - 10, "Reel visibly pulls both arm variants inward")
		check(art.hand_pixel("throw_reel",2,severed).x > art.hand_pixel("throw_reel",1,severed).x + 8, "Reel reaches after pull")
	for reel_frame in 6:
		check(art._pose("throw_reel",reel_frame).torso.y <= 3, "Throw reel never adopts slam crouch")
	check(art.anchor_ring_pixel() == Vector2(64,27), "Anchor ring center follows actual open-ring art")
	for animation: String in counts:
		check(intact.has_animation(animation), "Captain has %s animation" % animation)
		check(intact.get_frame_count(animation) == counts[animation], "%s frame count" % animation)
		check(cut.get_frame_count(animation) == counts[animation], "Cut %s frame count" % animation)
		for index: int in counts[animation]:
			var full_image: Image = intact.get_frame_texture(animation, index).get_image()
			var cut_image: Image = cut.get_frame_texture(animation, index).get_image()
			check(full_image.get_size() == Vector2i(128,128), "Canvas is 128px")
			var bounds := full_image.get_used_rect()
			check(bounds.size.x <= 104, "%s %d arms fit canvas" % [animation,index])
			check(bounds.end.y <= 112, "Feet remain on baseline112")
			if animation in ["idle","walk"]:
				check(bounds.size.y >= 84 and bounds.size.y <= 94, "Adult silhouette remains tall")
			check(pixel_count(full_image) > (400 if animation == "death" else 1000), "%s %d must contain substantial opaque art" % [animation,index])
			check(pixel_count(full_image) - pixel_count(cut_image) >= 20, "%s %d removes full arm (%d pixels)" % [animation,index,pixel_count(full_image)-pixel_count(cut_image)])
			if animation != "death":
				for severed in [false,true]:
					var wrist: Vector2 = art.hand_pixel(animation,index,severed)
					var posed_image: Image = cut_image if severed else full_image
					check(posed_image.get_pixel(int(wrist.x),int(wrist.y)).is_equal_approx(art.SKIN), "Attachment lies on drawn wrist %s %d cut=%s" % [animation,index,severed])
				check(art.hand_pixel(animation,index,false) != art.hand_pixel(animation,index,true), "Cut uses remaining weapon hand")
			check(difference_count(full_image,cut_image) > 40, "Every animation removes visible control limb pixels")
	var total := 0
	for animation: String in counts:
		total += intact.get_frame_count(animation)
	check(total == 67, "67 authored frames in each arm state")
	check(art.BODY_RADIUS == 0.25 and art.ARM_RADIUS == 0.14 and art.ARM_OFFSET == -0.36, "Logical collision constants remain unchanged")
	for first_tell in ["sweep_windup","throw_windup","slam_windup"]:
		for other_tell in ["sweep_windup","throw_windup","slam_windup"]:
			if first_tell != other_tell:
				for severed in [false,true]:
					var posed: SpriteFrames = cut if severed else intact
					check(silhouette_difference(posed.get_frame_texture(first_tell,4).get_image(),posed.get_frame_texture(other_tell,4).get_image()) > 100, "Attack windups have distinct silhouettes even after severance")
	for index in 2:
		var first: Image = intact.get_frame_texture("attack", index).get_image()
		var second: Image = intact.get_frame_texture("attack", index + 1).get_image()
		check(difference_count(first,second) > 100, "Attack poses visibly differ")
	for tell in ["sweep_windup","throw_windup","slam_windup","sweep_active","throw_active","slam_active","recover","sweep_recover","throw_recover","slam_recover"]:
		for severed in [false,true]:
			var posed: SpriteFrames = cut if severed else intact
			check(difference_count(posed.get_frame_texture(tell,0).get_image(),posed.get_frame_texture(tell,counts[tell]-1).get_image()) > 140, "Tell changes conspicuously: %s cut=%s" % [tell,severed])
	check(art.hand_pixel("slam_windup",4).y < 30, "Slam control wrist reaches above head")
	check(art.hand_pixel("slam_windup",4,true).y < 30, "Cut slam weapon wrist reaches above head")
	check(art.hand_pixel("throw_windup",4).x < art.hand_pixel("throw_active",3).x - 30, "Throw loads behind then casts forward")
	check(art.arm_center_pixel("slam_windup",4).y < art.arm_center_pixel("idle",0).y - 16, "Control hurt center follows overhead arm")
	var anchor: Image = art.anchor_texture().get_image()
	var ring: Vector2 = art.anchor_ring_pixel()
	check(anchor.get_pixel(int(ring.x),int(ring.y)).a == 0.0, "Ring attachment is inside actual opening")
	for rim in [Vector2i(64,17),Vector2i(64,35),Vector2i(55,27),Vector2i(73,27)]:
		check(anchor.get_pixelv(rim).a > 0.5, "Opaque ring surrounds attachment opening")
	check(anchor.get_size() == Vector2i(128,128), "Anchor is transparent128")
	check(pixel_count(anchor) > 600 and pixel_count(anchor) < 5000, "Anchor readable silhouette with transparent surroundings")
	check(anchor.get_pixel(0,0).a == 0.0, "Anchor has no opaque background")
	var idle_bounds: Rect2i = intact.get_frame_texture("idle",0).get_image().get_used_rect()
	print("CAPTAIN_ART_GEOMETRY idle=%s body_radius=%.2f arm_radius=%.2f arm_offset=%.2f" % [idle_bounds,art.BODY_RADIUS,art.ARM_RADIUS,art.ARM_OFFSET])
	if "--export-art" in OS.get_cmdline_user_args():
		export_sheet(intact,cut,art.anchor_texture())
	if failures == 0:
		print("CAPTAIN_ART_PASS: 134 frames; motion tells, shared wrist poses, arm removal, anchor transparency")
	quit(0 if failures == 0 else 1)

func pixel_count(image: Image) -> int:
	return region_count(image, Rect2i(Vector2i.ZERO,image.get_size()))

func region_count(image: Image, region: Rect2i) -> int:
	var count := 0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			if image.get_pixel(x,y).a > 0.5:
				count += 1
	return count

func difference_count(first: Image, second: Image) -> int:
	var count := 0
	for y in 128:
		for x in 128:
			if first.get_pixel(x,y) != second.get_pixel(x,y):
				count += 1
	return count

func silhouette_difference(first: Image, second: Image) -> int:
	var count := 0
	for y in 128:
		for x in 128:
			if (first.get_pixel(x,y).a > 0.5) != (second.get_pixel(x,y).a > 0.5):
				count += 1
	return count

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func export_sheet(intact: SpriteFrames, cut: SpriteFrames, anchor: Texture2D) -> void:
	var sheet := Image.create(128*6,128*32,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("67727a"))
	for row in 2:
		var frames := intact if row == 0 else cut
		var column := 0
		var line := row*16
		for animation in ["idle","walk","attack","hit","death","sweep_windup","sweep_active","throw_windup","throw_active","slam_windup","slam_active","recover","throw_reel","sweep_recover","throw_recover","slam_recover"]:
			for index in frames.get_frame_count(animation):
				sheet.blend_rect(frames.get_frame_texture(animation,index).get_image(),Rect2i(0,0,128,128),Vector2i(column*128,line*128))
				column += 1
			column = 0
			line += 1
	sheet.blend_rect(anchor.get_image(),Rect2i(0,0,128,128),Vector2i(128*5,128*31))
	var path := OS.get_cache_dir().path_join("emberwake-v60-captain-art.png")
	sheet.save_png(path)
	print("CAPTAIN_ART_SHEET ",path)
