extends SceneTree
## Compare the redrawn and original cutouts in the practice arena.

const ART_DIR := "res://lineart_preview/"
# The original cutout is 2.22 world units tall. The redrawn silhouette
# spans 370 pixels at rest.
const CHARACTER_SCALE := 1.15
const PIXEL_SIZE := (2.22 / 370.0) * CHARACTER_SCALE
const CANVAS_SIZE := Vector2i(560, 560)
const ART_ANCHOR := Vector2(232, 427)
const CANVAS_ANCHOR := Vector2(280, 485)
const COMPARISON_SPACING := 2.8
const WALK_FRAME_COUNT := 16
const WALK_CELL := 256
const WALK_FEET_Y := 230.0
const WALK_PIXEL_SIZE := (2.22 / 200.0) * CHARACTER_SCALE
const BIND := {
	"torso": Vector2(232, 313), "head": Vector2(230, 216),
	"upper_arm_r": Vector2(207, 238), "forearm_r": Vector2(198, 271), "hand_r": Vector2(188, 307),
	"upper_arm_l": Vector2(251, 237), "forearm_l": Vector2(260, 270), "hand_l": Vector2(272, 305),
	"thigh_r": Vector2(213, 329), "lower_leg_foot_r": Vector2(213, 372),
	"thigh_l": Vector2(254, 327), "lower_leg_foot_l": Vector2(249, 368),
}
const DRAW_ORDER := ["upper_arm_l", "forearm_l", "hand_l", "thigh_l", "lower_leg_foot_l",
	"thigh_r", "lower_leg_foot_r", "torso", "upper_arm_r", "forearm_r", "hand_r", "head"]
const CONTOUR := preload("res://lineart_preview/contour.gdshader")

var game
var hero
var character
var viewport: SubViewport
var ink_viewport: SubViewport
var sheet: Sprite3D
var walk_atlases: Dictionary = {}
var joints: Dictionary = {}
var poses: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.use_cutout_avatar = true
	root.add_child(game)
	game.start_run(true)
	hero = game.avatar
	if hero == null or hero.cutout == null:
		printerr("Could not find the player's modular cutout")
		quit(1)
		return
	character = hero.cutout.character
	if not _build_art():
		quit(1)
		return
	if "--verify" in OS.get_cmdline_user_args():
		await _verify()
	else:
		process_frame.connect(_sync_art)


func _build_art() -> bool:
	viewport = SubViewport.new()
	viewport.size = CANVAS_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hero.add_child(viewport)
	var art_root := Node2D.new()
	art_root.position = CANVAS_ANCHOR - ART_ANCHOR
	viewport.add_child(art_root)
	var bind: Dictionary = character.PIVOT_DATA.data.right
	for part: String in bind:
		var joint := Node2D.new()
		joint.name = part
		var parent: String = bind[part].parent
		var parent_node: Node2D = art_root if parent.is_empty() else joints[parent]
		parent_node.add_child(joint)
		joint.position = BIND[part] if parent.is_empty() else BIND[part] - BIND[parent]
		joints[part] = joint
		var image := Image.load_from_file(ART_DIR + part + ".png")
		if image == null or image.is_empty():
			printerr("Missing line art: ", part)
			return false
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.centered = false
		sprite.position = -BIND[part]
		sprite.z_index = DRAW_ORDER.find(part)
		sprite.z_as_relative = false
		joint.add_child(sprite)
	for direction in ["front", "back"]:
		var image := Image.load_from_file(ART_DIR + direction + "_walk.png")
		if image == null or image.is_empty():
			printerr("Missing walk atlas: ", direction)
			return false
		var frame := AtlasTexture.new()
		frame.atlas = ImageTexture.create_from_image(image)
		frame.filter_clip = true
		walk_atlases[direction] = frame
	ink_viewport = SubViewport.new()
	ink_viewport.size = viewport.size
	ink_viewport.transparent_bg = true
	ink_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hero.add_child(ink_viewport)
	var ink := Sprite2D.new()
	ink.centered = false
	ink.texture = viewport.get_texture()
	var contour := ShaderMaterial.new()
	contour.shader = CONTOUR
	ink.material = contour
	ink_viewport.add_child(ink)
	sheet = Sprite3D.new()
	sheet.texture = ink_viewport.get_texture()
	sheet.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sheet.pixel_size = PIXEL_SIZE
	sheet.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hero.add_child(sheet)
	return true


func _sync_art() -> void:
	var direction: String = hero.facing
	var feet_from_center: float
	if walk_atlases.has(direction):
		var frame: AtlasTexture = walk_atlases[direction]
		var cycle := fposmod(float(hero.clock) * 15.7, TAU) / TAU
		var index := 1 + floori(cycle * WALK_FRAME_COUNT) if hero.cutout_walking else 0
		frame.region = Rect2(Vector2(index % 4, index >> 2) * WALK_CELL, Vector2.ONE * WALK_CELL)
		sheet.texture = frame
		sheet.pixel_size = WALK_PIXEL_SIZE
		sheet.flip_h = false
		feet_from_center = WALK_FEET_Y - WALK_CELL * 0.5
	else:
		var pose := _pose()
		for part: String in joints:
			joints[part].rotation = pose[part]
		joints.torso.position = BIND.torso + Vector2(0, pose.bob)
		sheet.texture = ink_viewport.get_texture()
		sheet.pixel_size = PIXEL_SIZE
		sheet.flip_h = direction == "left"
		feet_from_center = CANVAS_ANCHOR.y - CANVAS_SIZE.y * 0.5
	var original: Sprite3D = hero.cutout.billboard
	var basis := original.global_basis
	var ground := original.global_position - basis.y * (38.0 * original.pixel_size)
	var camera: Camera3D = game.camera
	ground -= camera.global_basis.x * COMPARISON_SPACING
	sheet.global_transform = Transform3D(basis, ground + basis.y * (feet_from_center * sheet.pixel_size))


func _pose() -> Dictionary:
	var pose := {}
	for part: String in joints:
		pose[part] = character.joints[part].rotation
	# The combat cutout's weapon IK overrides the arm swing. The unarmed
	# preview uses the same gait phase as the cutout legs.
	var stride := sin(float(hero.clock) * 15.7) if hero.cutout_walking else 0.0
	pose.upper_arm_r = stride * 0.29
	pose.upper_arm_l = -stride * 0.29
	pose.forearm_r = -0.07 - maxf(0, stride) * 0.12
	pose.forearm_l = -0.07 - maxf(0, -stride) * 0.12
	pose.hand_r = 0.0
	pose.hand_l = 0.0
	pose.thigh_r *= 0.82
	pose.thigh_l *= 0.82
	pose.lower_leg_foot_r *= 0.80
	pose.lower_leg_foot_l *= 0.80
	pose.bob = (character.joints.torso.position.y - character.PIVOT_DATA.data.right.torso.position[1]) * 5.5
	return pose


func _verify() -> void:
	game.set_physics_process(false)
	var from: Vector3 = game.player.position
	game.test_aim = Vector3.RIGHT
	game.move_input = Vector2.RIGHT
	for index in 49:
		await physics_frame
		game.tick(1.0 / 120.0)
		if index % 2 == 0:
			_sync_art()
			poses.append(_pose())
	var moved: float = game.player.position.x - from.x
	if moved <= 0.35 or not sheet.visible or poses.size() != 25:
		printerr("Walk verification failed: moved=", moved, " facing=", hero.facing, " frames=", poses.size())
		quit(1)
		return
	var camera: Camera3D = game.camera
	var original: Sprite3D = hero.cutout.billboard
	var original_feet := original.global_position - original.global_basis.y * (38.0 * original.pixel_size)
	var redraw_feet := sheet.global_position - sheet.global_basis.y * (
		(CANVAS_ANCHOR.y - CANVAS_SIZE.y * 0.5) * sheet.pixel_size)
	var original_screen := camera.unproject_position(original_feet)
	var redraw_screen := camera.unproject_position(redraw_feet)
	if not original.visible or redraw_screen.x >= original_screen.x or absf(redraw_screen.y - original_screen.y) > 0.1:
		printerr("Comparison requires the redraw on the left, original on the right, and aligned feet")
		quit(1)
		return
	var low: float = poses[0].upper_arm_l
	var high := low
	for pose: Dictionary in poses:
		low = minf(low, pose.upper_arm_l)
		high = maxf(high, pose.upper_arm_l)
	if high - low < 0.15:
		printerr("Far arm did not swing: ", low, " to ", high)
		quit(1)
		return
	var toward := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z)
	var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z)
	var aims := {"front": toward, "back": -toward, "left": -right}
	for direction: String in aims:
		game.test_aim = aims[direction]
		game.tick(1.0 / 120.0)
		_sync_art()
		var expected: Texture2D = walk_atlases.get(direction, ink_viewport.get_texture())
		if hero.facing != direction or not sheet.visible or sheet.texture != expected or sheet.flip_h != (direction == "left"):
			printerr("Incorrect comparison art for direction: ", direction)
			quit(1)
			return
	var result := FileAccess.open("res://lineart_preview/walk_poses.json", FileAccess.WRITE)
	result.store_string(JSON.stringify(poses))
	result.close()
	print("Verified four comparison directions and practice walk: ", moved,
		" world units, far arm range ", high-low, " radians")
	quit()
