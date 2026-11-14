extends Node2D

const TINT := "#dacbb9"
const INK := "#624c3d"
const CANVAS := Vector2i(1289, 1221)
const POSES := [
	{},
	{"near_upper_arm": 22, "far_upper_arm": -22},
	{"near_upper_arm": 67, "near_forearm": 2, "far_upper_arm": -67, "far_forearm": -2},
	{"near_upper_arm": 40, "near_forearm": 27, "far_upper_arm": -40, "far_forearm": -27},
	{"near_hand": 14, "far_hand": -14},
	{"near_thigh": 12, "near_shin_foot": -26, "far_thigh": -12, "far_shin_foot": 26},
	{"near_thigh": 12, "near_shin_foot": -26},
	{"far_thigh": -12, "far_shin_foot": 26},
	{"near_upper_arm": 22, "near_forearm": 30},
	{"far_upper_arm": -22, "far_forearm": -30},
	{"head": -8},
	{"head": 8},
	{}
]

@onready var skeleton: Skeleton2D = $Skeleton2D
var bones: Dictionary = {}
var inverse_rest: Dictionary = {}
const TERMINAL_TIPS := {
	"torso": Vector2(623,595), "head": Vector2(623,370),
	"near_shin_foot": Vector2(553,1075), "far_shin_foot": Vector2(693,1075),
	"near_hand": Vector2(449,895), "far_hand": Vector2(797,895)
}
const ART_SLOTS := {
	"far_leg": "lower_leg_foot_r",
	"near_leg": "lower_leg_foot_l",
	"far_arm": "hand_r",
	"torso": "torso",
	"near_arm": "hand_l",
	"head": "head"
}
var art: Dictionary
var layer_sprites: Dictionary = {}
var composite: SubViewport
var composite_root: Node2D
var preview := Sprite2D.new()
var label := Label.new()
var current_pose := 0
var show_bones := false
var playing := false
var playhead := 0.0

func _ready() -> void:
	art = JSON.parse_string(FileAccess.get_file_as_string("res://art.json"))
	register_bones(skeleton)
	setup_layers()
	add_child(preview)
	preview.centered = false
	preview.position = Vector2(50, -75)
	preview.scale = Vector2.ONE * 0.72
	add_child(label)
	label.position = Vector2(18, 12)
	label.add_theme_color_override("font_color", Color("#614d3c"))
	if "--qc" in OS.get_cmdline_user_args():
		run_qc()
	else:
		set_pose(0)

func setup_layers() -> void:
	composite = SubViewport.new()
	composite.size = CANVAS
	composite.transparent_bg = true
	add_child(composite)
	composite_root = Node2D.new()
	composite.add_child(composite_root)
	var back: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://view_layers.json")).back
	for id in ["outline", "near_leg", "far_leg", "far_arm", "torso", "near_arm", "head", "guides"]:
		var sprite := Sprite2D.new()
		sprite.name = id
		sprite.centered = false
		sprite.z_as_relative = false
		if ART_SLOTS.has(id):
			var slot: Dictionary = back[ART_SLOTS[id]]
			sprite.z_index = int(slot.z)
			sprite.visible = slot.visible
		else:
			sprite.z_index = -1 if id == "outline" else 20
		composite_root.add_child(sprite)
		layer_sprites[id] = sprite
	if DisplayServer.get_name() != "headless":
		preview.texture = composite.get_texture()

func update_layer(id: String, document: String) -> Image:
	var image := Image.new()
	image.load_svg_from_string(document + "</svg>")
	var sprite: Sprite2D = layer_sprites[id]
	if DisplayServer.get_name() != "headless":
		if sprite.texture == null:
			sprite.texture = ImageTexture.create_from_image(image)
		else:
			sprite.texture.update(image)
	return image

func register_bones(parent: Node2D) -> void:
	for bone in parent.get_children():
		var id := String(bone.name)
		bones[id] = bone
		inverse_rest[id] = bone.global_transform.affine_inverse()
		register_bones(bone)

func set_pose(index: int) -> void:
	current_pose = posmod(index, POSES.size())
	apply_pose(POSES[current_pose])
	label.text = "Pose %02d / %02d     Arrows: pose     B: bones     Space: play" % [current_pose + 1, POSES.size()]

func apply_pose(pose: Dictionary) -> void:
	for id in bones:
		var bone: Bone2D = bones[id]
		bone.apply_rest()
		bone.rotation = deg_to_rad(pose.get(id, 0.0))
	var frame := render_frame()
	if DisplayServer.get_name() == "headless":
		preview.texture = ImageTexture.create_from_image(frame)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		playing = false
		set_pose(current_pose + 1)
	elif event.is_action_pressed("ui_left"):
		playing = false
		set_pose(current_pose - 1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_B:
		show_bones = not show_bones
		set_pose(current_pose)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		playing = not playing

func _process(delta: float) -> void:
	if not playing:
		return
	playhead = fposmod(playhead + delta * 1.8, POSES.size() - 1)
	var i := floori(playhead)
	apply_pose(blend_pose(POSES[i], POSES[i+1], smoothstep(0.0,1.0,playhead-i)))

func blend_pose(from: Dictionary, to: Dictionary, ratio: float) -> Dictionary:
	var result: Dictionary = {}
	for id in bones:
		result[id] = lerpf(from.get(id,0.0),to.get(id,0.0),ratio)
	return result

func deform(p: Vector2, id: String, weight := 1.0) -> Vector2:
	var bone: Bone2D = bones[id]
	var local: Vector2 = inverse_rest[id] * p
	if weight < 1.0:
		local = local.rotated(-bone.rotation * (1.0 - weight))
	return bone.global_transform * local

func limb_points(chain: String, entries: Array) -> PackedVector2Array:
	var side := chain.get_slice("_", 0)
	var ids := ["upper_arm", "forearm", "hand"] if chain.ends_with("_arm") else ["thigh", "shin_foot"]
	var points := PackedVector2Array()
	for entry in entries:
		points.append(deform(Vector2(entry[0], entry[1]), side + "_" + ids[int(entry[2])], entry[3] if entry.size() == 4 else 1.0))
	return points

func sample_curve(points: PackedVector2Array) -> PackedVector2Array:
	var sampled := PackedVector2Array()
	var n := points.size()
	for i in n:
		var a := points[posmod(i - 1,n)]
		var b := points[i]
		var c := points[(i+1)%n]
		var d := points[(i+2)%n]
		for j in 10:
			sampled.append(b.bezier_interpolate(b+(c-a)/6.0,c-(d-b)/6.0,c,j/10.0))
	return sampled

func svg_point(p: Vector2) -> String:
	return "%.2f %.2f" % [p.x, p.y]

func outline(raw: PackedVector2Array) -> String:
	var points := PackedVector2Array()
	for p in raw:
		if points.is_empty() or points[-1].distance_to(p) >= 4.5:
			points.append(p)
	if points.size() < 3:
		points = raw
	var result := ""
	for i in points.size():
		var last := points[posmod(i-1,points.size())]
		var p := points[i]
		var next := points[(i+1)%points.size()]
		var before := p.move_toward(last, minf(11.0,p.distance_to(last)*0.46))
		var after := p.move_toward(next, minf(11.0,p.distance_to(next)*0.46))
		# Smooth the compound contour at intersections, where two separate shapes meet.
		result += ("M" if i == 0 else "L") + svg_point(before) + "Q" + svg_point(p) + " " + svg_point(after)
	return result+"Z"

func fixed_polygon(path_data: String, id: String) -> PackedVector2Array:
	var items := path_data.replace("M"," M ").replace("L"," L ").replace("C"," C ").replace("Q"," Q ").replace("Z"," Z ").strip_edges().split(" ",false)
	var result := PackedVector2Array()
	var current := Vector2.ZERO
	var i := 0
	while i < items.size():
		var command := items[i]
		i += 1
		if command == "Z":
			break
		var p := Vector2(items[i].to_float(),items[i+1].to_float())
		i += 2
		if command == "M" or command == "L":
			current = p
			result.append(deform(p,id))
		elif command == "Q":
			var end := Vector2(items[i].to_float(),items[i+1].to_float())
			i += 2
			for j in range(1,13):
				var t := j/12.0
				result.append(deform(current.lerp(p,t).lerp(p.lerp(end,t),t),id))
			current = end
		elif command == "C":
			var q := Vector2(items[i].to_float(),items[i+1].to_float())
			var end := Vector2(items[i+2].to_float(),items[i+3].to_float())
			i += 4
			for j in range(1,15):
				result.append(deform(current.bezier_interpolate(p,q,end,j/14.0),id))
			current = end
	return result

func detail(d: String) -> String:
	return '<path d="'+d+'" stroke="'+INK+'" fill="none" stroke-width="3" stroke-linecap="round"/>'

func render_frame() -> Image:
	var torso_poly := fixed_polygon(art.torso,"torso")
	var head_poly := fixed_polygon(art.head,"head")
	var body := torso_poly
	var holes: Array[PackedVector2Array] = []
	var limb_polygons: Dictionary = {}
	for pair in art.shapes:
		var anchors := limb_points(pair[0],pair[1])
		limb_polygons[pair[0]] = sample_curve(anchors)
		var merged := Geometry2D.merge_polygons(body,limb_polygons[pair[0]])
		body = merged[0]
		for i in range(1,merged.size()):
			holes.append(merged[i])
	body = Geometry2D.merge_polygons(body,head_poly)[0]
	var compound_path := outline(body)
	for hole in holes:
		compound_path += outline(hole)
	var header := '<svg xmlns="http://www.w3.org/2000/svg" width="1289" height="1221">'
	var silhouette := '<path d="'+compound_path+'" fill-rule="evenodd" fill="'+TINT+'" stroke="'+INK+'" stroke-width="4" stroke-linejoin="round"/>'
	var outlines := update_layer("outline",header+silhouette)
	var clip := '<defs><clipPath id="art"><path d="'+compound_path+'" clip-rule="evenodd"/></clipPath></defs><g clip-path="url(#art)">'
	var ear := '<g transform="rotate(%.3f 623 595)">' % rad_to_deg(bones.head.global_rotation)
	var ear_path := "M406 448 C422 444 426 470 433 494 Q440 522 447 536"
	ear += detail(ear_path)
	ear += '<g transform="translate(1246 0) scale(-1 1)">'+detail(ear_path)+'</g></g>'
	var back_body := Geometry2D.merge_polygons(torso_poly,limb_polygons.near_leg)[0]
	back_body = Geometry2D.merge_polygons(back_body,limb_polygons.far_leg)[0]
	var near_ink := arm_overlap(limb_polygons.near_arm,back_body)
	var far_ink := arm_overlap(limb_polygons.far_arm,back_body)
	var shapes := limb_polygons.duplicate()
	shapes["torso"] = torso_poly
	shapes["head"] = head_poly
	var pelvis := '<path d="M550 902 C571 919 600 923 622 920 C646 923 675 919 696 902 C678 920 648 926 622 923 C597 926 568 920 550 902Z" fill="'+INK+'" opacity="0.62"/>'
	var ink := {"head":ear,"torso":near_ink+far_ink+pelvis}
	var ordered := ART_SLOTS.keys()
	ordered.sort_custom(func(a, b): return layer_sprites[a].z_index < layer_sprites[b].z_index)
	var svg := header
	for id in ordered:
		var polygon: PackedVector2Array = shapes[id]
		var layer := '<path d="M'
		for vertex in polygon:
			layer += svg_point(vertex) + " "
		layer += 'Z" fill="'+TINT+'"/>' + ink.get(id,"")
		var image := update_layer(id,header+clip+layer+"</g>")
		if DisplayServer.get_name() == "headless" and layer_sprites[id].visible:
			outlines.blend_rect(image,Rect2i(Vector2i.ZERO,CANVAS),Vector2i.ZERO)
	if show_bones:
		for id in bones:
			var bone: Bone2D = bones[id]
			var tip: Vector2
			if TERMINAL_TIPS.has(id):
				tip = bone.to_global(inverse_rest[id] * TERMINAL_TIPS[id])
			else:
				tip = bone.get_child(0).global_position
			svg += bone_line(bone.global_position, tip)
			svg += '<circle cx="%.2f" cy="%.2f" r="6" fill="#087c83" stroke="white" stroke-width="2"/>' % [bone.global_position.x,bone.global_position.y]
		for hip in ["near_thigh", "far_thigh"]:
			svg += bone_line(bones.torso.global_position, bones[hip].global_position)
	var guides := update_layer("guides",svg)
	if show_bones and DisplayServer.get_name() == "headless":
		outlines.blend_rect(guides,Rect2i(Vector2i.ZERO,CANVAS),Vector2i.ZERO)
	return outlines

func arm_overlap(arm: PackedVector2Array, body: PackedVector2Array) -> String:
	var ink := ""
	for segment in Geometry2D.intersect_polyline_with_polygon(arm.slice(35,141),body):
		if segment.size() < 2 or segment[0].distance_to(segment[-1]) < 10.0:
			continue
		var line_path := "M"+svg_point(segment[0])
		for i in range(1,segment.size()):
			line_path += "L"+svg_point(segment[i])
		ink += detail(line_path)
	return ink

func bone_line(start: Vector2, end: Vector2) -> String:
	return '<path d="M'+svg_point(start)+'L'+svg_point(end)+'" stroke="#087c83" stroke-width="3"/>'

func run_qc() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qc"))
	var first: PackedByteArray
	for i in POSES.size():
		set_pose(i)
		var frame := preview.texture.get_image()
		if i == 0:
			first = frame.get_data()
		if i == POSES.size() - 1 and frame.get_data() != first:
			push_error("Return pose differs from the first render")
			get_tree().quit(1)
			return
		frame.save_png("res://qc/pose_%02d.png" % i)
	for i in range(POSES.size()-1):
		for step in [1,2,3]:
			apply_pose(blend_pose(POSES[i],POSES[i+1],step/4.0))
			var image := preview.texture.get_image()
			if image.is_empty() or image.get_used_rect().size.x < 400:
				push_error("Empty or clipped render in sweep")
				get_tree().quit(2)
				return
			image.save_png("res://qc/between_%02d_%d.png" % [i,step])
	show_bones = true
	for index in [0, 2, 3, 5, 6, 7]:
		set_pose(index)
		preview.texture.get_image().save_png("res://qc/bones_%02d.png" % index)
	print("Skeleton2D: %d bones. Rendered %d key poses and %d intermediate frames. Rest return matches." % [skeleton.get_bone_count(),POSES.size(),(POSES.size()-1)*3])
	get_tree().quit()
