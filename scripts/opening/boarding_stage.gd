extends Node3D
## Formation markers share the departure ship's real deck and motion.
const MARKS := [Vector3(7.35, 0, -8.03), Vector3(4.55, 0, -9.85), Vector3(8.39, 0, -9.85)]
const Look = preload("res://modular/scripts/city_npc_pose.gd")
const Directions = preload("res://scripts/opening/harbor_hero_appearance.gd")
const Ship = preload("res://scripts/opening/departure_ship.gd")
const BOW_MARKS := [Vector3(11.8, 0, 1.6), Vector3(9.3, 0, 2.75), Vector3(7.8, 0, 1.25)]
const SAIL_SIDE_LANES := [2.85, 3.15, 2.2]
const ACTOR_PIXEL_SIZE := .018
const FOOT_OFFSET := .864

var figures: Array[Sprite3D] = []
var rings: Array[MeshInstance3D] = []
var feet: Array[Vector3] = []
var departure_party: Array[Dictionary] = []
var bow_progress := 0.0
var bow_walk_elapsed := 0.0


func _ready() -> void:
	for index in MARKS.size():
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = .54
		mesh.outer_radius = .58
		mesh.rings = 24
		mesh.ring_segments = 8
		ring.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("#e8bb75") if index == 0 else Color("#88b9a4")
		ring.material_override = material
		add_child(ring)
		rings.append(ring)
		var actor := Sprite3D.new()
		actor.pixel_size = ACTOR_PIXEL_SIZE
		actor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		actor.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		add_child(actor)
		figures.append(actor)
		feet.append(Vector3.ZERO)


func set_portrait(slot: int, texture: Texture2D) -> void:
	figures[slot].texture = texture


static func bow_walk_point(index: int, ship_position: Vector3, progress: float) -> Vector3:
	var mark_on_ship: Vector3 = BOW_MARKS[index]
	mark_on_ship.x *= Ship.LENGTH_SCALE
	var bow := ship_position + mark_on_ship
	bow.y = 0.0
	var mark: Vector3 = MARKS[index]
	var at := mark.lerp(bow, progress)
	# Pass on the camera side of the sails, then fan out on the foredeck.
	var lane: float = ship_position.z + SAIL_SIDE_LANES[index]
	at.z = lerpf(mark.z, lane, smoothstep(0.0, .42, progress))
	at.z = lerpf(at.z, bow.z, smoothstep(.83, 1.0, progress))
	return at


func sync(world, camera: Camera3D) -> void:
	var height: float = world.ship.position.y + 2.865
	for index in MARKS.size():
		var at: Vector3 = MARKS[index]
		if not departure_party.is_empty() and index >= departure_party.size():
			figures[index].hide()
			continue
		figures[index].show()
		if not departure_party.is_empty():
			at = bow_walk_point(index, world.ship.position, bow_progress)
			var from := bow_walk_point(index, world.ship.position, maxf(0.0, bow_progress - .01))
			var ahead := bow_walk_point(index, world.ship.position, minf(1.0, bow_progress + .01))
			var heading := ahead - from
			var walking := bow_progress > 0.0 and bow_progress < 1.0
			var view := Directions.choose(heading, camera, "right")
			var sample := (int(bow_walk_elapsed * 8.0) + index) % 4 if walking else 0
			figures[index].texture = Look.frame(departure_party[index].look, view, "walk" if walking else "idle", sample).texture
		at.y = height
		feet[index] = at + world.main_ship_offset(at)
		rings[index].global_basis = world.ship.visual_root.global_basis
		rings[index].global_position = feet[index] + Vector3.UP * .035
		figures[index].global_basis = camera.global_basis
		figures[index].global_position = feet[index] + camera.global_basis.y * FOOT_OFFSET
