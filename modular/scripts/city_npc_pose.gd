extends RefCounted
## Generates standing city actor frames from the accepted 12-piece outfit rig.
## Each sampled pose also returns hand anchors for the existing world props.
const PIVOTS := preload("res://modular/data/pivots.json")
const LAYERS := preload("res://modular/data/view_layers.json")
const PEOPLE := preload("res://modular/data/residents.json")
const CLOTHES := preload("res://modular/data/outfits.json")
const HAIRSTYLES := preload("res://modular/data/hairstyles.json")
const HATS := preload("res://modular/data/headwear.json")
const EYES := preload("res://modular/scripts/eyes.gd")
const EYE_PALETTES := preload("res://modular/data/eye_palettes.json")
const COLORS := preload("res://modular/scripts/hair_colors.gd")
const GROUND := Vector2(24, 40)
const CENTER := Vector2(24, 24)
const ART_GROUND := Vector2(16, 38)
const PALM := Vector2(0, 1.2)
const PIXEL_SIZE := 0.054

static var frames: Dictionary = {}
static var images: Dictionary = {}

static func player_look() -> Dictionary:
	var outfit: Dictionary = CLOTHES.data.filter(func(row: Dictionary) -> bool: return row.id == "blonde")[0]
	return {"face": "blonde", "hair": "blonde", "top": outfit, "bottom": outfit, "palette": {}, "hat": ""}


static func appearance(profile: Dictionary, actor_name: String, tier_hint: String = "") -> Dictionary:
	var id := String(profile.get("id", actor_name))
	var tier := tier_hint
	if tier.is_empty():
		tier = "Worker"
		if id.contains("seller") or id.contains("customer"):
			tier = "Middle"
	var sex := "m" if profile.get("male", true) else "f"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id + "/" + tier + "/" + sex)
	var faces: Array = PEOPLE.data.filter(func(row: Dictionary) -> bool: return row.sex == sex)
	var hair: Array = HAIRSTYLES.data.filter(func(row: Dictionary) -> bool: return row.sex == sex)
	var outfits: Array = CLOTHES.data.filter(func(row: Dictionary) -> bool:
		return row.tier == tier and row.sex == sex
	)
	var headwear: Array = HATS.data.filter(func(row: Dictionary) -> bool: return row.tier == tier)
	var palette_options := COLORS.choices(0)
	var palette: Dictionary = palette_options[rng.randi_range(0, palette_options.size() - 1)] if rng.randf() < 0.75 else {}
	return {
		"face": faces[rng.randi_range(0, faces.size() - 1)].id,
		"hair": hair[rng.randi_range(0, hair.size() - 1)].id,
		"top": outfits[rng.randi_range(0, outfits.size() - 1)],
		"bottom": outfits[rng.randi_range(0, outfits.size() - 1)],
		"palette": palette,
		"hat": headwear[rng.randi_range(0, headwear.size() - 1)].id if rng.randf() < 0.18 else "",
		"tier": tier,
		"sex": sex,
	}


static func frame(look: Dictionary, view: String, action: String, sample: int, blink: bool = false) -> Dictionary:
	var key := [look.face, look.hair, look.top.id, look.top.alt, look.bottom.id, look.bottom.alt,
		look.hat, look.palette.get("id", ""), view, action, sample, blink]
	if frames.has(key):
		return frames[key]

	var data: Dictionary = PIVOTS.data[view]
	var positions := {}
	var angles := {}
	var local := {}
	for id: String in data:
		local[id] = vector(data[id].position)
		angles[id] = 0.0
	apply_pose(local, angles, view, action, sample)
	for id: String in data:
		var parent: String = data[id].parent
		positions[id] = GROUND + local[id] if parent.is_empty() else (
			positions[parent] + Vector2(local[id]).rotated(angles[parent])
		)
		if not parent.is_empty():
			angles[id] += angles[parent]

	var draw: Array = []
	for id: String in data:
		var layer: Dictionary = LAYERS.data[view][id]
		if not layer.visible:
			continue
		var img: Image
		var z: int = int(layer.z) * 10
		var offset := -vector(data[id].pivot_in_png)
		if id == "head":
			img = source(look.face, view, id)
			offset = -ART_GROUND - vector(data[id].pivot_from_ground)
		elif id.begins_with("hand"):
			img = source(look.face, view, id)
		else:
			var outfit: Dictionary = look.bottom if id.begins_with("thigh") or id.begins_with("lower_leg") else look.top
			img = source(outfit.id, view, id + ("_alt" if outfit.alt else ""))
		if action in ["carry_walk", "lift", "place", "painting", "work", "ticket", "hold_tag", "inspect"] and (
			id.begins_with("forearm") or id.begins_with("hand")
		):
			z += 80
		draw.append([z, img, positions[id], offset, angles[id]])

	var head: Vector2 = positions.head
	var head_angle: float = angles.head
	var head_offset := -ART_GROUND - vector(data.head.pivot_from_ground)
	for part: String in ["head_rear", "head_fringe"]:
		var img := hair_image(look, view, part)
		var z := 130 if view == "back" else -10
		if part == "head_fringe":
			z = 120
		draw.append([z, img, head, head_offset - Vector2(0, maxi(0, img.get_height() - 40)), head_angle])
	if view != "back":
		var eye: Dictionary = EYE_PALETTES.data[look.face]
		var eye_image: Image = EYES.texture(view, 2 if blink else 0, Color(eye.iris),
			Color(eye.lid), Color(eye.white), Color(eye.shadow), bool(eye.wide_front)).get_image()
		draw.append([115, eye_image, head, head_offset, head_angle])
	if not String(look.hat).is_empty():
		var hat := read_image("res://modular/headwear/%s/%s.png" % [look.hat, view])
		draw.append([140, hat, head, head_offset - Vector2(4, 16), head_angle])
	draw.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var image := Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
	for item: Array in draw:
		blit_pose(image, item[1], item[2], item[3], item[4])
	var right: Vector2 = positions.hand_r + PALM.rotated(angles.hand_r)
	var left: Vector2 = positions.hand_l + PALM.rotated(angles.hand_l)
	if action in ["ticket", "hold_tag"]:
		stamp_ticket(image, right)
	if action == "broom":
		var handle := Vector2i(right.round())
		for y: int in range(0, 11):
			image.set_pixelv(handle + Vector2i(1 + y / 5, y), Color("#987654"))
		image.fill_rect(Rect2i(handle + Vector2i(0, 9), Vector2i(5, 3)), Color("#bcaa7a"))
	image.resize(144, 144, Image.INTERPOLATE_NEAREST)
	var result := {"texture": ImageTexture.create_from_image(image), "right": right, "left": left}
	frames[key] = result
	return result


static func right_grip(pose: Dictionary, basis: Basis, center: Vector3) -> Vector3:
	var pixel: Vector2 = (Vector2(pose.right) - CENTER) * PIXEL_SIZE
	return center + basis * Vector3(pixel.x, -pixel.y, 0.018)


static func apply_pose(local: Dictionary, angles: Dictionary, view: String, action: String, sample: int) -> void:
	var stride: float = [0.0, 0.65, 0.0, -0.65][posmod(sample, 4)]
	var turn := -1.0 if view == "left" else 1.0
	if action in ["walk", "carry_walk", "luggage_walk"]:
		local.torso.y -= 1.0 if sample % 2 else 0.0
		for side: String in ["l", "r"]:
			var sign_x := -1.0 if side == "l" else 1.0
			angles["thigh_" + side] = stride * sign_x
			angles["lower_leg_foot_" + side] = -stride * sign_x * 0.45
			if action == "walk" or (action == "luggage_walk" and side == "l"):
				angles["upper_arm_" + side] = -stride * sign_x * 0.5
	elif action in ["lift", "place", "inspect"]:
		local.torso.y += 1.0 + float(sample % 2)
		angles.torso = 0.10 * turn
		angles.thigh_l = -0.3
		angles.thigh_r = 0.3
		angles.lower_leg_foot_l = 0.35
		angles.lower_leg_foot_r = -0.35

	if action in ["luggage_idle", "luggage_walk"]:
		var shoulder: Vector2 = local.upper_arm_r
		aim(local, angles, "r", shoulder + Vector2(signf(shoulder.x), 6.0), -turn)
	elif action in ["carry_walk", "lift", "place"]:
		var drop := 2.0 if action != "carry_walk" else 0.0
		aim(local, angles, "r", Vector2(-3.3 + turn, 1.7 + drop), -1.0)
		aim(local, angles, "l", Vector2(3.3 + turn, 1.7 + drop), 1.0)
	elif action in ["ticket", "hold_tag", "inspect"]:
		aim(local, angles, "r", Vector2(2.3 * turn, -0.5 + float(sample % 3)), -turn)
	elif action in ["painting", "work", "broom"]:
		aim(local, angles, "r", Vector2(5.2 * turn, -1.0 + float(sample % 3)), -turn)
		if action in ["painting", "broom"]:
			aim(local, angles, "l", Vector2(2.6 * turn, 2.3), turn)
	elif action == "portrait_pose":
		angles.head = 0.06 * turn * float(sample % 2)


static func aim(local: Dictionary, angles: Dictionary, side: String, target: Vector2, bend_sign: float) -> void:
	var upper := "upper_arm_" + side
	var fore := "forearm_" + side
	var hand := "hand_" + side
	var first: Vector2 = local[fore]
	var second: Vector2 = local[hand]
	var wrist: Vector2 = target - PALM - Vector2(local[upper])
	var reach := clampf(wrist.length(), absf(first.length() - second.length()) + 0.05,
		first.length() + second.length() - 0.03)
	var bend := acos(clampf((reach * reach + first.length_squared() - second.length_squared())
		/ (2.0 * reach * first.length()), -1.0, 1.0))
	var elbow := Vector2.from_angle(wrist.angle() + bend_sign * bend) * first.length()
	var end := Vector2.from_angle(wrist.angle()) * reach
	angles[upper] = angle_difference(first.angle(), elbow.angle())
	angles[fore] = angle_difference(second.angle(), (end - elbow).angle()) - angles[upper]
	angles[hand] = -angles[fore] - angles[upper]


static func source(id: String, view: String, part: String) -> Image:
	return read_image("res://modular/sprites/%s/%s/%s.png" % [id, view, part])


static func read_image(path: String) -> Image:
	if not images.has(path):
		var texture: Texture2D = load(path)
		images[path] = texture.get_image()
	return images[path]


static func hair_image(look: Dictionary, view: String, part: String) -> Image:
	if look.palette.is_empty():
		return source(look.hair, view, part)
	var key := "color/%s/%s/%s/%s" % [look.hair, view, part, look.palette.id]
	if not images.has(key):
		var texture: Texture2D = load("res://modular/sprites/%s/%s/%s.png" % [look.hair, view, part])
		images[key] = COLORS.recolor(texture, COLORS.replacement_map(look.hair, look.palette)).get_image()
	return images[key]


static func blit_pose(canvas: Image, img: Image, pivot: Vector2, offset: Vector2, turn: float) -> void:
	var used := img.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var extent := Rect2(pivot + (Vector2(used.position) + offset).rotated(turn), Vector2.ZERO)
	for corner: Vector2 in [Vector2(used.end.x, used.position.y), Vector2(used.position.x, used.end.y), Vector2(used.end)]:
		extent = extent.expand(pivot + (corner + offset).rotated(turn))
	var begin := Vector2i(extent.position.floor()).max(Vector2i.ZERO)
	var finish := Vector2i(extent.end.ceil() + Vector2.ONE).min(canvas.get_size())
	for y in range(begin.y, finish.y):
		for x in range(begin.x, finish.x):
			var sample := Vector2i(((Vector2(x, y) - pivot).rotated(-turn) - offset).round())
			if not used.has_point(sample):
				continue
			var pixel := img.get_pixelv(sample)
			if pixel.a > 0.5:
				canvas.set_pixel(x, y, pixel)


static func stamp_ticket(image: Image, hand: Vector2) -> void:
	var origin := Vector2i(hand.round()) + Vector2i(-1, -3)
	image.fill_rect(Rect2i(origin, Vector2i(4, 3)), Color("#51444b"))
	image.fill_rect(Rect2i(origin + Vector2i(1, 0), Vector2i(3, 2)), Color("#f1d9a3"))


static func vector(values: Array) -> Vector2:
	return Vector2(values[0], values[1])

