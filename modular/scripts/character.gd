extends Node2D
## Root origin is the common ground anchor. Use set_view() or the view_name property.

const VIEW_ORDER := ["front", "back", "left", "right"]
const ANIMATION_NAMES := ["idle", "arm_rotation", "elbow_bend", "leg_rotation", "knee_bend", "view_switching"]
const HairColors = preload("res://modular/scripts/hair_colors.gd")
const Eyes = preload("res://modular/scripts/eyes.gd")
const EYE_PALETTES = preload("res://modular/data/eye_palettes.json")
const Blink = preload("res://modular/city-preview/idle_blink.gd")
const PIVOT_DATA := preload("res://modular/data/pivots.json")
const LAYER_DATA := preload("res://modular/data/view_layers.json")

@export_enum("front", "back", "left", "right") var view_name: String = "front":
	set(value):
		if value == view_name:
			return
		if is_node_ready() and not PIVOT_DATA.data.has(value):
			return
		view_name = value
		if is_node_ready():
			_apply_view()
			_update_motion_signs()

@onready var canvas: SubViewport = $PixelCanvas
@onready var rig: Node2D = $PixelCanvas/Rig
@onready var output: Sprite2D = $Silhouette
@onready var player: AnimationPlayer = $AnimationPlayer

var joints: Dictionary = {}
var art: Dictionary = {}
var textures: Dictionary = {}
var rear_hair: Sprite2D
var fringe: Sprite2D
var eyes: Sprite2D
var headwear: Sprite2D
var headwear_id := ""
var face_id := "ropeworker"
var hair_id := "ropeworker"
var hair_palette: Dictionary = {}
var upper_id := "ropeworker"
var lower_id := "ropeworker"
var upper_alt := false
var lower_alt := false
const HEAD_ART_GROUND := Vector2(16, 38)
var idle_blink_enabled := true
var blink_pose := Blink.OPEN
var blink := Blink.new()
var motion_is_back := false
var motion_tracks: Array[Animation] = []


func _ready() -> void:
	$OutlineCanvas/Outline.texture = canvas.get_texture()
	output.texture = $OutlineCanvas.get_texture()
	var first: String = PIVOT_DATA.data.keys()[0]
	if not PIVOT_DATA.data.has(view_name):
		view_name = first
	for part: String in PIVOT_DATA.data[first]:
		var joint := Node2D.new()
		joint.name = part
		var parent: String = PIVOT_DATA.data[first][part]["parent"]
		var parent_node: Node2D = rig if parent.is_empty() else joints[parent]
		parent_node.add_child(joint)
		joints[part] = joint

		var sprite := Sprite2D.new()
		sprite.name = "Art"
		sprite.centered = false
		sprite.z_as_relative = false
		joint.add_child(sprite)
		art[part] = sprite
	rear_hair = Sprite2D.new()
	rear_hair.name = "HairDepth"
	rear_hair.centered = false
	rear_hair.z_as_relative = false
	joints["head"].add_child(rear_hair)
	fringe = Sprite2D.new()
	fringe.name = "HairFringe"
	fringe.centered = false
	fringe.z_as_relative = false
	joints["head"].add_child(fringe)
	eyes = Sprite2D.new()
	eyes.name = "Eyes"
	eyes.centered = false
	eyes.z_as_relative = false
	joints["head"].add_child(eyes)
	headwear = Sprite2D.new()
	headwear.name = "Headwear"
	headwear.centered = false
	headwear.z_as_relative = false
	headwear.z_index = 14
	joints["head"].add_child(headwear)
	_apply_view()
	_build_animations()
	_update_motion_signs()
	blink.reset()

func _process(delta: float) -> void:
	if idle_blink_enabled and view_name != "back" and player.current_animation == "idle":
		set_blink_pose(blink.advance(delta))

func set_blink_pose(pose: int) -> void:
	var next_pose := Blink.OPEN if view_name == "back" else pose
	if blink_pose == next_pose:
		return
	blink_pose = next_pose
	_update_eyes()

func _update_eyes() -> void:
	var palette: Dictionary = EYE_PALETTES.data[face_id]
	eyes.texture = Eyes.texture(view_name,blink_pose,Color(palette.iris),Color(palette.lid),
		Color(palette.white),Color(palette.shadow),bool(palette.wide_front))

func _apply_view() -> void:
	for part: String in joints:
		var info: Dictionary = PIVOT_DATA.data[view_name][part]
		var layer: Dictionary = LAYER_DATA.data[view_name][part]
		joints[part].position = _vector(info["position"])
		art[part].offset = -_vector(info["pivot_in_png"])
		var id := face_id
		var name_suffix := ""
		if part != "head" and not part.begins_with("hand"):
			var is_lower := part.begins_with("thigh") or part.begins_with("lower_leg")
			id = lower_id if is_lower else upper_id
			if lower_alt if is_lower else upper_alt:
				name_suffix = "_alt"
		art[part].texture = _look_texture(id,part+name_suffix)
		art[part].z_index = int(layer["z"])
		art[part].visible = layer["visible"]

	# Hair and face share the original head pivot. The bigger texture only
	# gives the hairstyle room outside the base head's cropped texture.
	var head: Dictionary = PIVOT_DATA.data[view_name]["head"]
	var offset := -HEAD_ART_GROUND - _vector(head["pivot_from_ground"])
	art["head"].offset = offset
	eyes.offset = offset
	eyes.z_index = int(LAYER_DATA.data[view_name]["head"]["z"])
	rear_hair.texture = _hair_texture("head_rear")
	fringe.texture = _hair_texture("head_fringe")
	rear_hair.offset = offset - Vector2(0, max(0, rear_hair.texture.get_height() - 40))
	fringe.offset = offset - Vector2(0, max(0, fringe.texture.get_height() - 40))
	fringe.z_index = 12
	rear_hair.z_index = 13 if view_name == "back" else -1
	rear_hair.visible = true
	_apply_headwear()
	blink_pose = Blink.OPEN
	_update_eyes()
	blink.reset()

func set_headwear(id: String) -> void:
	headwear_id = id
	_apply_headwear()


func _apply_headwear() -> void:
	headwear.visible = not headwear_id.is_empty()
	if not headwear.visible:
		headwear.texture = null
		return
	var path := "res://modular/headwear/%s/%s.png" % [headwear_id, view_name]
	if not textures.has(path):
		textures[path] = load(path)
	headwear.texture = textures[path]
	headwear.offset = art["head"].offset - Vector2(4, 16)


func set_hair_palette(palette: Dictionary) -> void:
	if hair_palette == palette:
		return
	hair_palette = palette
	rear_hair.texture = _hair_texture("head_rear")
	fringe.texture = _hair_texture("head_fringe")


func _hair_texture(part: String) -> Texture2D:
	var original := _look_texture(hair_id, part)
	if hair_palette.is_empty():
		return original
	var key := "hair-color/%s/%s/%s/%s" % [hair_id, view_name, part, hair_palette.id]
	if not textures.has(key):
		textures[key] = HairColors.recolor(original, HairColors.replacement_map(hair_id, hair_palette))
	return textures[key]


func _look_texture(id: String, part: String) -> Texture2D:
	var path := "res://modular/sprites/%s/%s/%s.png" % [id,view_name,part]
	if not textures.has(path):
		textures[path] = load(path)
	return textures[path]

func set_look(id: String, face_choice: String, hair_choice: String, top: bool, bottom: bool,
		upper_source: String = "", lower_source: String = "") -> void:
	upper_id = id if upper_source.is_empty() else upper_source
	lower_id = id if lower_source.is_empty() else lower_source
	face_id = face_choice
	hair_id = hair_choice
	upper_alt = top
	lower_alt = bottom
	_apply_view()


func set_view(direction: String) -> void:
	play_test("idle")
	view_name = direction


func play_test(clip: String) -> void:
	if not player.has_animation(clip):
		return
	set_blink_pose(Blink.OPEN)
	blink.reset()
	player.stop()
	for joint: Node2D in joints.values():
		joint.rotation = 0.0
	player.play(clip)
	player.advance(0.0)


func _build_animations() -> void:
	var library := AnimationLibrary.new()
	library.add_animation("idle", _clip(1.0))
	# The same motion tracks are available in every projection. Left and right
	# are anatomical. Their screen signs are selected when a clip starts.
	var arm := _clip(1.6)
	var elbow := _clip(1.6)
	var leg := _clip(1.6)
	var knee := _clip(1.6)
	for side in ["l", "r"]:
		_track_rotation(arm, "upper_arm_" + side, 23.0, side)
		_track_rotation(elbow, "forearm_" + side, 20.0, side)
		_track_rotation(leg, "thigh_" + side, 13.0, side)
		_track_rotation(knee, "lower_leg_foot_" + side, 15.0, side)
	motion_tracks.assign([arm, elbow, leg, knee])
	library.add_animation("arm_rotation", arm)
	library.add_animation("elbow_bend", elbow)
	library.add_animation("leg_rotation", leg)
	library.add_animation("knee_bend", knee)

	var switch := _clip(float(PIVOT_DATA.data.size()))
	var index := switch.add_track(Animation.TYPE_VALUE)
	switch.track_set_path(index, NodePath(".:view_name"))
	switch.value_track_set_update_mode(index, Animation.UPDATE_DISCRETE)
	var time := 0.0
	for view in VIEW_ORDER:
		if PIVOT_DATA.data.has(view):
			switch.track_insert_key(index, time, view)
			time += 1.0
	library.add_animation("view_switching", switch)
	player.add_animation_library("", library)


func _track_rotation(animation: Animation, part: String, degrees: float, side: String) -> void:
	var index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index, NodePath(str(get_path_to(joints[part])) + ":rotation"))
	# Positive rotation moves a downward vector toward screen left.
	var front_sign := 1.0 if side == "r" else -1.0
	for sample in [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.8, 1.0), Vector2(1.05, 1.0), Vector2(1.6, 0.0)]:
		animation.track_insert_key(index, sample.x, deg_to_rad(degrees * sample.y * front_sign))


func _update_motion_signs() -> void:
	var should_invert := view_name == "back"
	if motion_is_back == should_invert:
		return
	motion_is_back = should_invert
	for animation in motion_tracks:
		for track in animation.get_track_count():
			for key in animation.track_get_key_count(track):
				animation.track_set_key_value(track, key, -animation.track_get_key_value(track, key))


func _clip(seconds: float) -> Animation:
	var animation := Animation.new()
	animation.length = seconds
	animation.loop_mode = Animation.LOOP_LINEAR
	return animation


func _vector(array: Array) -> Vector2:
	return Vector2(array[0], array[1])

