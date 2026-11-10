extends CanvasLayer
## Hands off under the sky, then tilts the expedition camera down into the clearing.

const GAME_SCENE := "res://scenes/game.tscn"
const ENTRY := preload("res://scenes/opening/coastal_combat_entry.tscn")
const SKY_ART := preload("res://assets/foliage/expedition-forest-panorama.png")
const FOREST_ART := preload("res://assets/foliage/expedition-forest-depth-atlas.png")
const SKY_PITCH := deg_to_rad(23.0)
const SKY_CAMERA_LIFT := 7.5
const FOREST_REGIONS := [
	Rect2(32, 181, 704, 297),
	Rect2(805, 173, 698, 305),
]
const BoardingStage = preload("res://scripts/opening/boarding_stage.gd")
const BOW_WALK_TIME := 4.6
const BOW_TRACK_END := BOW_WALK_TIME + 3.0
const CAMERA_RELEASE_TIME := 1.2
const OUTBOUND_VELOCITY := Vector3(8.5, 0.0, -1.3)
const OPEN_SEA_AXIS := Vector3(1.0, 0.0, .40)
const STARBOARD_VIEW_OFFSET := 17.0
const STERN_TURN_START := 9.25
const STERN_TURN_END := 11.45
const DEPARTURE_SKY_START := STERN_TURN_END + 1.7
const DEPARTURE_TIME := DEPARTURE_SKY_START + 2.2
const PAN_TIME := 3.20
const WALK_DELAY := .55
const WALK_TIME := 3.85
const LETTERBOX_HEIGHT := .085
const LETTERBOX_IN_TIME := .55
const LETTERBOX_OUT_TIME := .60

var phase: StringName = &"departure"
var _harbor: Node3D
var _entry: Node
var _sky_cover: TextureRect
var _letterbox_top: ColorRect
var _letterbox_bottom: ColorRect
var _backdrop: Node3D
var _arrival_pitch: float
var _departure_start: Transform3D
var _departure_fov: float
var _walk_start: Vector3
var _walk_end: Vector3
var _gate_focus: Vector3
var _inward: Vector3
var _walk_previous := 0.0


func _ready() -> void:
	name = "ExpeditionVoyage"
	layer = 60
	var sky_image := SKY_ART.get_image()
	_sky_cover = TextureRect.new()
	_sky_cover.texture = ImageTexture.create_from_image(sky_image.get_region(Rect2i(0, 0, 1024, 550)))
	_sky_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_cover.modulate.a = 0.0
	add_child(_sky_cover)
	_letterbox_top = _make_letterbox_bar("LetterboxTop", Control.PRESET_TOP_WIDE)
	_letterbox_bottom = _make_letterbox_bar("LetterboxBottom", Control.PRESET_BOTTOM_WIDE)
	_set_letterbox(0.0)


func _make_letterbox_bar(bar_name: String, preset: int) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	bar.set_anchors_and_offsets_preset(preset)
	return bar


func _set_letterbox(amount: float) -> void:
	var height := LETTERBOX_HEIGHT * amount
	_letterbox_top.set_anchor_and_offset(SIDE_BOTTOM, height, 0.0)
	_letterbox_bottom.set_anchor_and_offset(SIDE_TOP, 1.0 - height, 0.0)
	_letterbox_top.visible = amount > 0.0
	_letterbox_bottom.visible = amount > 0.0


func _add_painting(
	id: String, texture: Texture2D, size_: Vector2, pose: Transform3D, uv: Vector4
) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_repeat = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.uv1_scale = Vector3(uv.z, uv.w, 1.0)
	material.uv1_offset = Vector3(uv.x, uv.y, 0.0)
	if texture == FOREST_ART:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = .25
	var quad := QuadMesh.new()
	quad.size = size_
	var painting := MeshInstance3D.new()
	painting.name = id
	painting.mesh = quad
	painting.material_override = material
	painting.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	painting.transform = pose
	_backdrop.add_child(painting)


func _mount_arrival_backdrop(game: Node3D) -> void:
	var camera: Camera3D = game.camera
	_arrival_pitch = camera.rotation.x
	camera.rotation.x = SKY_PITCH
	camera.position.y += SKY_CAMERA_LIFT
	_backdrop = Node3D.new()
	_backdrop.name = "ForestArrivalBackdrop"
	game.add_child(_backdrop)

	# The opening view samples the same sky rectangle as the harbor's load cover.
	# Extend the painting below that rectangle so the horizon stays behind the ridges.
	var view := camera.get_viewport().get_visible_rect().size
	var frame := Vector2(camera.size * view.x / view.y, camera.size)
	var sky_pose := camera.transform.translated_local(Vector3(0.0, -frame.y * 9.5, -165.0))
	_add_painting("Sky", _sky_cover.texture, frame * Vector2(4.0, 20.0), sky_pose, Vector4(-1.5, 0.0, 4.0, 20.0))

	# Like the harbor city paintings, these are stationary cutouts behind the playable terrain.
	var atlas_size := FOREST_ART.get_size()
	var room_edge: float = -game.arena.room_half.y
	for i in FOREST_REGIONS.size():
		var region: Rect2 = FOREST_REGIONS[i]
		var uv := Vector4(region.position.x / atlas_size.x, region.position.y / atlas_size.y,
			region.size.x / atlas_size.x, region.size.y / atlas_size.y)
		var id := "FarRidge" if i == 0 else "NearRidge"
		var position_ := Vector3(0.0, 13.5, room_edge - 51.0) if i == 0 else Vector3(0.0, 8.0, room_edge - 34.0)
		var size_ := Vector2(124.0, 39.0) if i == 0 else Vector2(110.0, 27.0)
		_add_painting(id, FOREST_ART, size_, Transform3D(Basis.IDENTITY, position_), uv)



func run(harbor: Node3D, party: Array[Dictionary]) -> void:
	_harbor = harbor
	var tree := get_tree()
	var request := ResourceLoader.load_threaded_request(GAME_SCENE, "PackedScene")
	_departure_start = _harbor.camera.transform
	_departure_fov = _harbor.camera.fov
	_harbor.boarding_party.stage.departure_party = party
	var departure := create_tween().set_parallel()
	departure.tween_method(_depart, 0.0, DEPARTURE_TIME, DEPARTURE_TIME)
	departure.tween_method(_set_letterbox, 0.0, 1.0, LETTERBOX_IN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await departure.finished
	phase = &"sky"
	while request == OK and ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not is_instance_valid(_harbor):
			queue_free()
			return
		await tree.process_frame
	if not is_instance_valid(_harbor) or tree.current_scene != _harbor:
		queue_free()
		return

	var prepared: PackedScene
	if request == OK and ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_LOADED:
		prepared = ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	else:
		prepared = load(GAME_SCENE) as PackedScene
	if prepared == null:
		_harbor.cancel_departure()
		queue_free()
		return
	# Let the sky fully cover the scene before mounting and building the room.
	await tree.process_frame
	if not is_instance_valid(_harbor) or tree.current_scene != _harbor:
		queue_free()
		return
	_entry = ENTRY.instantiate()
	_entry.party = party
	_entry.prepared_game = prepared
	_entry.arrival_locked = true
	if tree.change_scene_to_node(_entry) != OK:
		_entry.free()
		_harbor.cancel_departure()
		queue_free()
		return
	await tree.scene_changed
	if not is_instance_valid(_entry) or tree.current_scene != _entry:
		queue_free()
		return

	_prepare_arrival()
	_mount_arrival_backdrop(_entry.game)
	_sky_cover.hide()
	phase = &"forest"
	await create_tween().tween_method(_descend, 0.0, WALK_DELAY + WALK_TIME, WALK_DELAY + WALK_TIME).finished
	if is_instance_valid(_entry):
		var game = _entry.game
		game.arrival_motion = Vector3.ZERO
		for companion in game.companions:
			companion.velocity = Vector3.ZERO
		game._visual_tick(0.0)
		_backdrop.queue_free()
		game.set_arrival_lock(false)
	queue_free()


func _departure_travel(elapsed: float) -> Vector3:
	var acceleration_time := .9
	var distance_time := elapsed - acceleration_time * (1.0 - exp(-elapsed / acceleration_time))
	return OUTBOUND_VELOCITY * distance_time


func _depart(elapsed: float) -> void:
	if not is_instance_valid(_harbor):
		return
	var stage = _harbor.boarding_party.stage
	stage.bow_progress = smoothstep(0.0, BOW_WALK_TIME, elapsed)
	stage.bow_walk_elapsed = elapsed

	# Follow the moving bow, then ease the tracking velocity to zero.
	var release := clampf((elapsed - BOW_TRACK_END) / CAMERA_RELEASE_TIME, 0.0, 1.0)
	var follow_time := minf(elapsed, BOW_TRACK_END)
	follow_time += CAMERA_RELEASE_TIME * (release - pow(release, 3) + .5 * pow(release, 4))
	var ship: Vector3 = _harbor.world.ship.position
	var leader := BoardingStage.bow_walk_point(0, ship, stage.bow_progress)
	leader.y = ship.y + 2.865
	var formation_shift := 2.45 * smoothstep(.45, 1.0, stage.bow_progress)
	var eye := leader + Vector3(-.6 - formation_shift, 1.35, 10.8)
	var target := leader + Vector3(-.4 - formation_shift, 1.35, .1)
	var tracking := Transform3D(Basis.looking_at(target - eye), eye)
	var settle := smoothstep(0.0, 1.25, elapsed)
	var pose := _departure_start.interpolate_with(tracking, settle)
	pose.origin += _departure_travel(follow_time)

	# Take the outbound line to port of the stopped camera so its starboard side stays visible.
	var sea_direction := OPEN_SEA_AXIS.normalized()
	var across := sea_direction.cross(Vector3.UP)
	var travel := _departure_travel(elapsed)
	var lateral := across * ((pose.origin - ship - travel).dot(across) - STARBOARD_VIEW_OFFSET)
	var alignment := clampf((elapsed - STERN_TURN_START) / (STERN_TURN_END - STERN_TURN_START), 0.0, 1.0)
	var blend := smoothstep(0.0, 1.0, alignment)
	_harbor.world.departure_offset = travel + lateral * blend
	var lateral_speed := 6.0 * alignment * (1.0 - alignment) / (STERN_TURN_END - STERN_TURN_START)
	var heading := OUTBOUND_VELOCITY - across * OUTBOUND_VELOCITY.dot(across) * blend + lateral * lateral_speed
	_harbor.world.departure_heading = atan2(-heading.z, heading.x) * smoothstep(STERN_TURN_START, STERN_TURN_START + 1.0, elapsed)

	var stern_turn := blend
	var turn_focus: Vector3 = ship + _harbor.world.departure_offset
	if elapsed >= STERN_TURN_END:
		turn_focus = ship + _departure_travel(STERN_TURN_END)
		turn_focus += across * ((pose.origin - turn_focus).dot(across) - STARBOARD_VIEW_OFFSET)
	# The turn and the pullback finish together, then the camera holds while the ship recedes.
	pose.origin += Vector3(-18.5, 1.3, 1.1) * stern_turn
	turn_focus.y = pose.origin.y
	var stern_view := Basis.looking_at(turn_focus - pose.origin) if stern_turn > 0.0 else pose.basis
	pose.basis = pose.basis.slerp(stern_view, stern_turn)
	var horizon := -pose.basis.z
	horizon.y = 0.0
	var sky := Basis.looking_at(horizon.normalized() * .55 + Vector3.UP * .84)
	pose.basis = pose.basis.slerp(sky, smoothstep(DEPARTURE_SKY_START, DEPARTURE_TIME - .5, elapsed))
	_harbor.camera.transform = pose
	_harbor.camera.fov = lerpf(_departure_fov, lerpf(45.0, 43.0, stern_turn), settle)
	_sky_cover.modulate.a = smoothstep(DEPARTURE_TIME - .9, DEPARTURE_TIME, elapsed)


func _prepare_arrival() -> void:
	var game = _entry.game
	var links: Dictionary = game.dungeon.rooms[game.dungeon.start].links
	var direction: Vector2i = links.keys()[0]
	if links.has(Vector2i.UP):
		direction = Vector2i.UP
	var outward := Vector3(direction.x, 0.0, direction.y)
	_inward = -outward
	var entry_point: Vector3 = game.arena.entry_position(direction)
	_walk_start = entry_point + outward * 3.8
	_walk_end = entry_point + _inward * 4.5
	_gate_focus = entry_point + _inward * 2.0
	_walk(0.0, 0.0)


func _descend(elapsed: float) -> void:
	var arrival_end := WALK_DELAY + WALK_TIME
	if elapsed >= arrival_end - LETTERBOX_OUT_TIME:
		_set_letterbox(1.0 - smoothstep(arrival_end - LETTERBOX_OUT_TIME, arrival_end, elapsed))
	var pan := smoothstep(0.0, PAN_TIME, elapsed)
	if elapsed >= PAN_TIME:
		phase = &"arrival"
	_walk(clampf((elapsed - WALK_DELAY) / WALK_TIME, 0.0, 1.0), pan)
	var camera: Camera3D = _entry.game.camera
	# Keep the close treetops below the view until the distant ridges are in frame.
	camera.position.y += SKY_CAMERA_LIFT * (1.0 - smoothstep(.28, .78, pan))
	camera.rotation.x = lerpf(SKY_PITCH, _arrival_pitch, pan)


func _walk(progress: float, pan: float) -> void:
	var game = _entry.game
	var distance := smoothstep(0.0, 1.0, progress)
	var side := _inward.cross(Vector3.UP)
	# Stay centered at the gate, then bend across the clearing.
	var lateral := -.7 + .7 * distance + 2.8 * distance * distance
	var position_ := _walk_start.lerp(_walk_end, distance) + side * lateral
	var tangent := _walk_end - _walk_start + side * (.7 + 5.6 * distance)
	var facing := tangent.normalized()
	var delta := (progress - _walk_previous) * WALK_TIME
	var travel := (distance - smoothstep(0.0, 1.0, _walk_previous)) * tangent.length()
	_walk_previous = progress
	game.player.position = position_
	game.aim = facing
	var speed := travel / maxf(delta, .001) if progress < 1.0 else 0.0
	game.arrival_motion = facing if speed > .35 else Vector3.ZERO
	var spacing := lerpf(.48, 1.30, smoothstep(.48, .88, progress))
	for i in game.companions.size():
		var companion = game.companions[i]
		var flank := (-spacing if i == 0 else spacing) * side
		companion.position = position_ + flank - facing * (.78 + i * .38)
		companion.facing = facing
		companion.velocity = facing * speed
	game._camera_focus = _gate_focus.lerp(position_ + facing * .45, pan)
	game._visual_tick(delta)
	game.arena.update_peek_hints(position_, false)
	game.camera.size += lerpf(4.0, 0.0, progress)
