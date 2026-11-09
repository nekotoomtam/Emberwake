extends Node3D
## Formation markers share the departure ship's real deck and motion.
const MARKS := [Vector3(7.35, 0, -8.03), Vector3(4.55, 0, -9.85), Vector3(8.39, 0, -9.85)]
const ACTOR_PIXEL_SIZE := .018
const FOOT_OFFSET := .864

var figures: Array[Sprite3D] = []
var rings: Array[MeshInstance3D] = []
var feet: Array[Vector3] = []


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


func sync(world, camera: Camera3D) -> void:
	var height: float = world.ship.position.y + 2.865
	for index in MARKS.size():
		var at: Vector3 = MARKS[index] + Vector3.UP * height
		feet[index] = at + world.main_ship_offset(at)
		rings[index].global_basis = world.ship.visual_root.global_basis
		rings[index].global_position = feet[index] + Vector3.UP * .035
		figures[index].global_basis = camera.global_basis
		figures[index].global_position = feet[index] + camera.global_basis.y * FOOT_OFFSET
