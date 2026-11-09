extends CanvasLayer

const Room = preload("res://scripts/dungeon_room.gd")
const Dungeon = preload("res://scripts/dungeon_run.gd")
const Facing = preload("res://scripts/fisherman_art.gd")
const MAX_SWEEP := deg_to_rad(29.0)
const RAY_COUNT := 192

var preview_room: Room
var scene_camera: Camera3D
var sight_material: ShaderMaterial
var sight_range := 0.0
var forward := Vector3.RIGHT
var encounter_props: Array[Node3D] = []
var sight_boxes: Array[AABB] = []
var _eyes: Vector3
var _door_axis: Vector3
var _opening: Dictionary
var _view: SubViewport

func _ready() -> void:
	layer = 30
	var screen := SubViewportContainer.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.stretch = true
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.handle_input_locally = false
	_view.size = Vector2i(get_viewport().get_visible_rect().size)
	screen.add_child(_view)
	_view.size_changed.connect(_set_mask)
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sight_material = ShaderMaterial.new()
	sight_material.shader = preload("res://shaders/dungeon_peek_sight.gdshader")
	shade.material = sight_material
	hide()

func open(room: Dictionary, travel: Vector2i, map_basis: Basis, reach: float, create_enemy: Callable) -> void:
	close()
	_door_axis = Vector3(travel.x, 0, travel.y)
	forward = _door_axis
	sight_range = maxf(reach, .01)
	_opening = room.get("opening", {})
	preview_room = Room.new()
	preview_room.visual_only = true
	_view.add_child(preview_room)
	preview_room.add_room_lighting()
	preview_room.build_room(room.links, room.variant, room.cleared, false, [], -travel, room.feature, room.feature_origin, room.feature_seed, room.floor_seed)
	var half := Room.HALF.x if travel.x != 0 else Room.HALF.y
	_eyes = -_door_axis * (half - .45) + Vector3.UP * .03

	scene_camera = Camera3D.new()
	scene_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene_camera.size = 11.5
	preview_room.add_child(scene_camera)
	var focus := _eyes + _door_axis * 6.7
	# Preserve the map view while moving the origin to the linked doorway.
	scene_camera.transform = Transform3D(map_basis, focus + map_basis.z * 17.0)
	scene_camera.make_current()
	_collect_sight_boxes(preview_room)
	_upload_rays()
	_add_encounter_props(create_enemy)
	_present_patrol()
	_set_mask()
	show()

func _process(delta: float) -> void:
	if not visible: return
	Dungeon.advance_patrol(_opening, delta)
	_present_patrol()

func aim_at(screen: Vector2) -> void:
	if not visible: return
	var point := _ground(screen)
	var offset := Vector3(point.x - _eyes.x, 0, point.y - _eyes.z)
	if offset.length_squared() < .01: return
	var angle := _door_axis.signed_angle_to(offset.normalized(), Vector3.UP)
	forward = _door_axis.rotated(Vector3.UP, clampf(angle, -MAX_SWEEP, MAX_SWEEP))
	sight_material.set_shader_parameter("forward", Vector2(forward.x, forward.z))
	_present_encounter()

func _add_encounter_props(create_enemy: Callable) -> void:
	if _opening.is_empty(): return
	for placement in _opening.enemies:
		var actor = create_enemy.call(placement.kind)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.position = placement.position
		preview_room.layout.add_child(actor)
		actor.collision_layer = 0
		actor.collision_mask = 0
		var sprite: AnimatedSprite3D = actor.sprite
		for child in actor.get_children():
			if child is Node3D and child != sprite: child.hide()
		sprite.basis = scene_camera.global_basis
		sprite.position = scene_camera.global_basis.y * ((float(actor._profile.foot_pixel) - 64.0) * sprite.pixel_size)
		encounter_props.append(actor)
	preview_room.show_trap(_opening.trap)
	if is_instance_valid(preview_room.trap): encounter_props.append(preview_room.trap)

func _present_patrol() -> void:
	if _opening.is_empty(): return
	for index in _opening.enemies.size():
		var placement: Dictionary = _opening.enemies[index]
		var actor := encounter_props[index]
		actor.position = placement.position
		var sprite: AnimatedSprite3D = actor.sprite
		var view := Facing.direction(placement.facing, scene_camera)
		var animation := view + ("_run" if placement.kind == "brinehound" else "_walk")
		if not sprite.sprite_frames.has_animation(animation):
			animation = "walk"
			sprite.flip_h = view == "left"
		sprite.animation = animation
		var count := sprite.sprite_frames.get_frame_count(animation)
		sprite.frame = int(_opening.patrol_time * 6.0) % count
	_present_encounter()

func _present_encounter() -> void:
	for prop in encounter_props:
		var offset := prop.global_position - _eyes
		offset.y = 0
		var ahead := offset.dot(forward)
		var width := lerpf(.18, 2.15, clampf(ahead / sight_range, 0, 1))
		prop.visible = ahead > 0.0 and absf(offset.cross(forward).y) < width \
			and offset.length() < ray_distance(offset.normalized())

func _collect_sight_boxes(room: Room) -> void:
	for mesh: MeshInstance3D in room.sight_boxes:
		if not is_instance_valid(mesh) or not mesh.is_visible_in_tree(): continue
		var bounds: AABB = room.sight_boxes[mesh]
		bounds.position += room.global_position
		sight_boxes.append(bounds)

func ray_distance(direction: Vector3) -> float:
	var eye := Vector3(_eyes.x, .68, _eyes.z)
	var distance := sight_range
	for bounds in sight_boxes:
		var hit: Variant = bounds.intersects_ray(eye, direction)
		if hit is Vector3:
			distance = minf(distance, eye.distance_to(hit))
	for edge in preview_room.sight_edges:
		var inverse: Transform3D = edge.inverse
		var local_eye := inverse * eye
		var hit: Variant = edge.bounds.intersects_ray(local_eye, inverse.basis * direction)
		if hit is Vector3:
			distance = minf(distance, local_eye.distance_to(hit))
	return distance

func _upload_rays() -> void:
	var samples := Image.create(RAY_COUNT, 1, false, Image.FORMAT_RF)
	for index in RAY_COUNT:
		var angle := (float(index) + .5) * TAU / RAY_COUNT
		var reach := ray_distance(Vector3(cos(angle), 0, sin(angle)))
		samples.set_pixel(index, 0, Color(reach / sight_range, 0, 0))
	sight_material.set_shader_parameter("ray_lengths", ImageTexture.create_from_image(samples))
	sight_material.set_shader_parameter("sight_length", sight_range)

func close() -> void:
	hide()
	if is_instance_valid(preview_room):
		_view.remove_child(preview_room)
		preview_room.queue_free()
	preview_room = null
	encounter_props.clear()
	sight_boxes.clear()
	scene_camera = null
	_opening = {}

func _set_mask() -> void:
	if not is_instance_valid(scene_camera): return
	var size := Vector2(_view.size)
	var origin := _ground(Vector2.ZERO)
	sight_material.set_shader_parameter("world_origin", origin)
	sight_material.set_shader_parameter("world_dx", _ground(Vector2(size.x, 0)) - origin)
	sight_material.set_shader_parameter("world_dy", _ground(Vector2(0, size.y)) - origin)
	sight_material.set_shader_parameter("eyes", Vector2(_eyes.x, _eyes.z))
	sight_material.set_shader_parameter("forward", Vector2(forward.x, forward.z))

func _ground(screen: Vector2) -> Vector2:
	var origin := scene_camera.project_ray_origin(screen)
	var ray := scene_camera.project_ray_normal(screen)
	var point := origin - ray * (origin.y / ray.y)
	return Vector2(point.x, point.z)
