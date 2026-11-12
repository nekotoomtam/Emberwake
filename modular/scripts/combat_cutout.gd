extends Node3D
## The combat timeline and weapon mounts drive the same four-view character
## used in town. Angles are solved in the billboard's pixel plane.
const Character := preload("res://modular/scenes/character_base.tscn")
const Look := preload("res://modular/scripts/city_npc_pose.gd")
const PIXEL_SIZE := 0.060
const CENTER := Vector2(72, 56)
const PALM := Vector2(0, 1.2)
const MAX_STRETCH := 1.4
const BODY_SEGMENTS := {"upper_arm_":"upper_arm", "forearm_":"forearm", "hand_":"forearm",
	"thigh_":"thigh", "lower_leg_foot_":"lower_leg"}

var character: Node2D
var billboard: Sprite3D
var grip_errors := {}
var mount_offsets := {}
var mount_depths := {}
var palms: Dictionary = {}


func _ready() -> void:
	character = Character.instantiate()
	add_child(character)
	character.output.hide()
	apply_look(Look.player_look())
	character.idle_blink_enabled = false
	billboard = Sprite3D.new()
	billboard.texture = character.output.texture
	billboard.pixel_size = PIXEL_SIZE
	billboard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(billboard)
	for side in ["r", "l"]:
		var palm := Sprite3D.new()
		palm.pixel_size = PIXEL_SIZE
		palm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		palm.render_priority = 6
		palm.hide()
		add_child(palm)
		palms[side] = palm


func apply_look(look: Dictionary) -> void:
	character.set_look(look.top.id, look.face, look.hair, look.top.alt, look.bottom.alt, look.top.id, look.bottom.id)
	character.set_hair_palette(look.palette)
	character.set_headwear(look.hat)


func pose(view: String, animation: String, frame: int, clock: float, body_transform: Transform3D,
		tint: Color, anatomy, dash: Dictionary, crawling: bool, walking: bool,
		phase: String, mounts: Array, floor_targets: Dictionary) -> void:
	character.view_name = view
	billboard.global_basis = body_transform.basis
	billboard.global_position = body_transform.origin + body_transform.basis.y * ((94.0-CENTER.y)*PIXEL_SIZE - 0.864)
	billboard.modulate = tint
	var bind: Dictionary = character.PIVOT_DATA.data[view]
	var order: Dictionary = character.LAYER_DATA.data[view]
	var joints: Dictionary = character.joints
	var art: Dictionary = character.art
	for id: String in joints:
		joints[id].position = Vector2(bind[id].position[0], bind[id].position[1])
		joints[id].rotation = 0.0
		art[id].transform = Transform2D.IDENTITY
		art[id].z_index = order[id].z
		art[id].visible = order[id].visible

	var stride := sin(clock * 15.7) if walking and not crawling else 0.0
	var tuck: float = dash.get("amount", 0.0)
	var falling := animation == "death"
	var drop := 1.0 if animation == "hit" else (0.7 if phase == "windup" else 0.0)
	var torso: Node2D = joints.torso
	torso.position.y += drop + absf(stride)*0.55
	character.rig.position = Vector2(72, 94)
	character.rig.rotation = 0.0
	if falling:
		character.rig.rotation = [0.35, 0.95, 1.57][clampi(frame, 0, 2)] * (-1 if view == "left" else 1)
		character.rig.position.y -= 3.0 if frame > 0 else 0.0
	elif crawling:
		torso.position.y += 1.0
		torso.rotation = -0.22 if view == "left" else 0.22
		joints.head.rotation = -torso.rotation
	for side: String in ["r", "l"]:
		var sign_x := -1.0 if side == "r" else 1.0
		var arm: String = "right_arm" if side == "r" else "left_arm"
		var leg: String = "right_leg" if side == "r" else "left_leg"
		var body_side := "right_" if side == "r" else "left_"
		for prefix: String in BODY_SEGMENTS:
			art[prefix+side].visible = anatomy.present(body_side+BODY_SEGMENTS[prefix]) and order[prefix+side].visible
		var gait := stride * sign_x if anatomy.functional(leg) else 0.0
		joints["thigh_"+side].rotation = gait*.55 + tuck*sign_x*.72
		joints["lower_leg_foot_"+side].rotation = -gait*.30 - tuck*sign_x*.48
		joints["upper_arm_"+side].rotation = -gait*.3 + tuck*sign_x*.28
		joints["forearm_"+side].rotation = -sign_x*.28 if not anatomy.functional(arm) else 0.0
	art.head.visible = anatomy.present("head")
	character.eyes.visible = art.head.visible
	character.fringe.visible = art.head.visible
	character.rear_hair.visible = art.head.visible
	art.torso.visible = anatomy.present("torso")
	character.set_blink_pose(2 if falling or animation=="hit" or (
		animation=="idle" and fposmod(clock+1.0,5.3)<.13) else 0)

	grip_errors.clear()
	mount_offsets.clear()
	mount_depths.clear()
	for palm: Sprite3D in palms.values(): palm.hide()
	for mount: Dictionary in mounts:
		fit_mount(mount)
	for side: String in floor_targets:
		var point: Vector3 = floor_targets[side]
		aim_arm(side, to_pixel(point))


func to_pixel(point: Vector3) -> Vector2:
	var local: Vector3 = billboard.to_local(point)
	return CENTER + Vector2(local.x, -local.y) / PIXEL_SIZE


func arm_center(side: String) -> Vector2:
	return character.joints["upper_arm_"+side].global_position + PALM


func arm_reach(side: String) -> float:
	var fore: Vector2 = character.joints["forearm_"+side].position
	var hand: Vector2 = character.joints["hand_"+side].position
	return (fore.length()+hand.length())*MAX_STRETCH-.12


func fit_mount(mount: Dictionary) -> void:
	var side: String = mount.side
	var original := to_pixel(mount.point)
	var grip := original
	var main_center := arm_center(side)
	var main_reach := arm_reach(side)
	var other: String = mount.get("other", "")
	var axis: Vector3 = billboard.global_basis.inverse() * mount.axis
	var wrist_angle := clampf(atan2(-axis.y, absf(axis.x)), -.58, .58)
	if axis.x < 0.0: wrist_angle *= -1.0
	var support_target := Vector2.ZERO
	if not other.is_empty():
		var span := to_pixel(mount.support)-original
		var support_center := arm_center(other)
		var support_reach := arm_reach(other)
		# Preserve the authored grip separation whenever both arms can reach.
		var allowed_span := (main_reach + support_reach) * .90
		span = support_center - main_center + (span - (support_center - main_center)).limit_length(allowed_span)
		for pass_index in 12:
			grip = main_center + (grip-main_center).limit_length(main_reach)
			grip = support_center - span + (grip+span-support_center).limit_length(support_reach)
		support_target = grip + span
	else:
		grip = main_center + (grip-main_center).limit_length(main_reach)
	record_grip(side, grip, wrist_angle)
	var hand: Node2D = character.joints["hand_"+side]
	var final_grip := hand.to_global(PALM)
	var delta := (final_grip-original)*PIXEL_SIZE
	mount_offsets[mount.rig] = billboard.global_basis*Vector3(delta.x,-delta.y,0)
	var front: bool = mount.front
	mount_depths[mount.rig] = .045 if front else -.045
	if not other.is_empty():
		record_grip(other, support_target + final_grip - grip, wrist_angle)
	if front and not mount.hide_palms:
		show_palm(side)
		if not other.is_empty(): show_palm(other)


func show_palm(side: String) -> void:
	var art: Sprite2D = character.art["hand_" + side]
	if not art.visible or art.texture == null: return
	var palm: Sprite3D = palms[side]
	var pixel := art.to_global(art.offset + art.texture.get_size() * .5)
	var center := (pixel - CENTER) * PIXEL_SIZE
	palm.texture = art.texture
	palm.modulate = billboard.modulate
	palm.global_transform = Transform3D(
		billboard.global_basis * Basis(Vector3.BACK, -art.global_rotation),
		billboard.global_transform * Vector3(center.x, -center.y, .085))
	palm.show()


func record_grip(side: String, pixel: Vector2, wrist_angle: float) -> void:
	aim_arm(side, pixel, wrist_angle)
	var hand: Node2D = character.joints["hand_"+side]
	grip_errors[side] = hand.to_global(PALM).distance_to(pixel)*PIXEL_SIZE


func aim_arm(side: String, target: Vector2, wrist_angle: float = 0.0) -> void:
	var upper: Node2D = character.joints["upper_arm_"+side]
	var fore: Node2D = character.joints["forearm_"+side]
	var hand: Node2D = character.joints["hand_"+side]
	# Work in the shoulder's parent plane so inherited torso tilt is accounted for.
	var local: Vector2 = upper.get_parent().to_local(target) - upper.position
	var wrist := local - PALM.rotated(wrist_angle - character.joints.torso.global_rotation)
	var stretch := clampf(wrist.length() / (fore.position.length() + hand.position.length() - 0.08),1.0,MAX_STRETCH)
	stretch_link(character.art["upper_arm_"+side], fore.position, stretch)
	stretch_link(character.art["forearm_"+side], hand.position, stretch)
	fore.position *= stretch
	hand.position *= stretch
	var first := fore.position.length()
	var second := hand.position.length()
	var reach := clampf(wrist.length(), absf(first-second)+.04, first+second-.04)
	var bend := acos(clampf((reach*reach+first*first-second*second)/(2.0*reach*first),-1.0,1.0))
	# Keep the authored outward fold throughout the view, even when the
	# weapon crosses the vertical line through the shoulder.
	var elbow_sign := 1.0 if fore.position.x < 0.0 else -1.0
	var elbow := Vector2.from_angle(wrist.angle()+elbow_sign*bend)*first
	var end := Vector2.from_angle(wrist.angle())*reach
	upper.rotation = angle_difference(fore.position.angle(),elbow.angle())
	fore.rotation = angle_difference(hand.position.angle(),(end-elbow).angle())-upper.rotation
	hand.global_rotation = wrist_angle
	var view: String = character.view_name
	var near := view=="front" or (view=="left" and side=="l") or (view=="right" and side=="r")
	if near:
		character.art["forearm_"+side].z_index = 11
		character.art["hand_"+side].z_index = 12


func stretch_link(sprite: Sprite2D, along: Vector2, amount: float) -> void:
	if is_equal_approx(amount,1.0):
		return
	var axis := along.normalized()
	var delta := amount-1.0
	sprite.transform = Transform2D(Vector2.RIGHT + axis*axis.x*delta,
		Vector2.DOWN + axis*axis.y*delta, Vector2.ZERO)
