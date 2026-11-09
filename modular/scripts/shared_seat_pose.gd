extends Node3D
## Camera-facing, live 12-part outfit rig for an occupied seat.
const CHARACTER := preload("res://modular/scenes/character_base.tscn")
const PIXEL_SIZE := 0.052
const CENTER := Vector2(72, 56)
const GRIP := Vector2(0, 1.3)

var character: Node2D
var billboard: Sprite3D
var current_view := ""
var right_grip := Vector3.ZERO
var left_grip := Vector3.ZERO
var left_target := Vector3.ZERO
var mouth_error := 0.0


func _ready() -> void:
	character = CHARACTER.instantiate()
	add_child(character)
	character.output.hide()
	billboard = Sprite3D.new()
	billboard.texture = character.output.texture
	billboard.pixel_size = PIXEL_SIZE
	billboard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(billboard)


func dress(id: String, hair: String) -> void:
	character.set_look(id, id, hair, false, false)


func dress_look(look: Dictionary) -> void:
	character.set_look(look.top.id, look.face, look.hair, look.top.alt, look.bottom.alt,
		look.top.id, look.bottom.id)
	character.set_hair_palette(look.palette)
	character.set_headwear(look.hat)


func pose(camera: Camera3D, hip: Vector3, view: String, action: String, amount: float,
		cup: Node3D = null, cup_rest: Vector3 = Vector3.ZERO,
		handle: Vector3 = Vector3.ZERO, palm: Vector3 = Vector3.ZERO,
		case_target: Vector3 = Vector3.ZERO) -> void:
	if current_view != view:
		current_view = view
		character.set_view(view)
	for joint: Node2D in character.joints.values():
		joint.rotation = 0.0
	var sign_x := -1.0 if view == "left" else 1.0
	for side: String in ["l", "r"]:
		var bend := sign_x * (-1.06 if side == "r" else -1.22)
		if view == "front" or view == "back":
			bend = 0.88 if side == "r" else -0.88
		if action == "rise":
			bend *= 1.0 - amount
		character.joints["thigh_" + side].rotation = bend
		character.joints["lower_leg_foot_" + side].rotation = -bend * 0.88
	var torso: Node2D = character.joints["torso"]
	var hip_pixel := torso.to_global(Vector2(0, 2))
	billboard.global_basis = camera.global_basis
	var from_center := (hip_pixel - CENTER) * PIXEL_SIZE
	billboard.global_position = hip - camera.global_basis * Vector3(from_center.x, -from_center.y, 0)
	if cup == null and action != "rise":
		# The legs hang from the front lip of the slats. Bring the card
		# in front of that lip so the seat cannot cut through the thighs.
		billboard.global_position += camera.global_basis.z * 0.20
	var base_pose: Dictionary = character.PIVOT_DATA.data[view]
	for side: String in ["l", "r"]:
		var arm_name := "upper_arm_" + side
		var position: Array = base_pose[arm_name].position
		character.joints[arm_name].position = Vector2(position[0], position[1])
	if cup != null:
		# The shoulders project into the same torso when seated side-on.
		# Bring the right shoulder toward the table and keep the other
		# arm slightly farther back, while staying inside the coat.
		character.joints["upper_arm_r"].position = Vector2(3.7 * sign_x, lerpf(-3.0, -5.5, amount))
		character.joints["upper_arm_l"].position = Vector2(1.1 * sign_x, -3)
	var shoulder_r: Vector2 = character.joints["upper_arm_r"].global_position
	var shoulder_l: Vector2 = character.joints["upper_arm_l"].global_position
	var rest_r := shoulder_r + Vector2(1.5 * sign_x, 4.5)
	var rest_l := shoulder_l + Vector2(2.0 * sign_x, 4.5)
	if cup != null:
		var grip_rest := to_pixel(cup_rest + handle)
		var mouth: Vector2 = character.joints["head"].to_global(Vector2(5.0 * sign_x, -1.5))
		var desired := grip_rest.lerp(mouth, amount) + Vector2(0, -0.55 * sin(PI * amount))
		aim_arm("r", desired, sign_x)
		aim_arm("l", to_pixel(palm), -sign_x)
		var depth := billboard.global_basis.z.dot(cup_rest + handle - billboard.global_position)
		right_grip = to_world(hand_pixel("r"), lerpf(depth, 0.09, amount))
		mouth_error = (hand_pixel("r") - mouth).length() * PIXEL_SIZE
		left_grip = to_world(hand_pixel("l"), billboard.global_basis.z.dot(palm - billboard.global_position))
		left_target = palm
		cup.global_position = right_grip - handle if amount > 0.01 else cup_rest
	elif action == "rise":
		var reach := smoothstep(0.0, 0.25, amount)
		aim_arm("r", rest_r.lerp(to_pixel(case_target), reach), -sign_x)
		aim_arm("l", rest_l, -sign_x)
		right_grip = to_world(hand_pixel("r"),
			billboard.global_basis.z.dot(case_target - billboard.global_position))
	else:
		var gesture := Vector2(0.0, -1.7 * amount) if action == "bench_hand_rest" else Vector2.ZERO
		aim_arm("r", rest_r + gesture, sign_x)
		aim_arm("l", rest_l, -sign_x)
		character.joints["head"].rotation = 0.09 * amount if action == "bench_glance" else 0.0
		right_grip = to_world(hand_pixel("r"), 0.0)
		left_grip = to_world(hand_pixel("l"), 0.0)


func aim_arm(side: String, target: Vector2, elbow_sign: float) -> void:
	var upper: Node2D = character.joints["upper_arm_" + side]
	var fore: Node2D = character.joints["forearm_" + side]
	var hand: Node2D = character.joints["hand_" + side]
	var first := fore.position
	var second := hand.position
	var wrist := target - GRIP - upper.global_position
	var radius := clampf(wrist.length(), absf(first.length() - second.length()) + 0.1,
		first.length() + second.length() - 0.03)
	var bend := acos(clampf((radius * radius + first.length_squared() - second.length_squared())
		/ (2.0 * radius * first.length()), -1.0, 1.0))
	var elbow := Vector2.from_angle(wrist.angle() + bend * elbow_sign) * first.length()
	var desired_wrist := Vector2.from_angle(wrist.angle()) * radius
	upper.rotation = angle_difference(first.angle(), elbow.angle())
	fore.rotation = angle_difference(second.angle(), (desired_wrist - elbow).angle()) - upper.rotation
	hand.rotation = -fore.rotation - upper.rotation
	for part: String in ["upper_arm_", "forearm_", "hand_"]:
		character.art[part + side].z_index = 12 if side == "r" else 11


func hand_pixel(side: String) -> Vector2:
	return character.joints["hand_" + side].to_global(GRIP)


func to_pixel(point: Vector3) -> Vector2:
	var local := billboard.global_basis.inverse() * (point - billboard.global_position)
	return CENTER + Vector2(local.x, -local.y) / PIXEL_SIZE


func to_world(pixel: Vector2, depth: float) -> Vector3:
	var offset := (pixel - CENTER) * PIXEL_SIZE
	return billboard.global_position + billboard.global_basis * Vector3(offset.x, -offset.y, depth)
