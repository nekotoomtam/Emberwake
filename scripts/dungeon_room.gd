extends Node3D
## The occupied forest clearing and its connections to graph neighbors.
const Hazards = preload("res://scripts/dungeon_hazards.gd")
const Grove = preload("res://scripts/dungeon_mushroom_grove.gd")
const Forest = preload("res://scripts/dungeon_forest.gd")
const RevelationGrowth = preload("res://scripts/dungeon_revelation_growth.gd")
const HALF := Vector2(21.0, 15.7)
const START_HALF := Vector2(24.0, 18.0)
var room_half := HALF
const DOOR_WIDTH := 3.6
const CORRIDOR := 3.6
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var walkable_outline: PackedVector2Array
var sight_edges: Array[Dictionary] = []
var obstacles: Array[Vector3] = []
var peek_exits: Dictionary = {}
var sight_boxes: Dictionary = {}
var trap: Node3D
var hazards: Hazards
var revelation_growth: RevelationGrowth
var visual_only := false
var layout: Node3D
var gates: Node3D


func _ready() -> void:
	if not visual_only: add_room_lighting()


func add_room_lighting() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#1b2921")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#afbdcc")
	world.environment.ambient_light_energy = 0.76
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -35, 0)
	light.light_color = Color("#ffe1b6")
	light.light_energy = 0.7
	add_child(light)


func build_room(links: Dictionary, variant: int, cleared: bool, is_start: bool = false, dark_exits: Array[Vector2i] = [], joined_entry: Vector2i = Vector2i.ZERO, feature: String = "", feature_origin := Vector3.ZERO, feature_seed: int = 0, floor_seed: int = 0) -> void:
	trap = null
	hazards = null
	revelation_growth = null
	room_half = START_HALF if is_start else HALF
	if is_instance_valid(layout):
		remove_child(layout)
		layout.queue_free()
	layout = Node3D.new()
	add_child(layout)
	gates = Node3D.new()
	layout.add_child(gates)
	var mats := Forest.surfaces()
	var lock := material("#60483c")
	var shape := 0 if is_start else variant
	var forest := Forest.new()
	forest.collect_revelation_sites = true
	layout.add_child(forest)
	walkable_outline = Forest.outline_for(room_half, DOOR_WIDTH, shape)
	box(layout, Vector3(0,-.22,0), Vector3(room_half.x * 2.0 + 10, .44, room_half.y * 2.0 + 10), mats.understory)
	forest.ground(walkable_outline, hash([floor_seed, shape]), links, room_half)
	forest.backdrop(room_half, walkable_outline, links, shape)
	obstacles.clear()
	peek_exits.clear()
	sight_boxes.clear()
	sight_edges.clear()
	_add_forest_borders(forest, links)
	var poison_groups: Array[Vector2] = []
	if feature == "mushrooms":
		var grove_seed := hash([floor_seed, "mushroom_grove"])
		var grove := Grove.plan(walkable_outline, grove_seed)
		poison_groups = grove.poison
		for index in grove.trees.size():
			var at: Vector2 = grove.trees[index]
			_add_grove_tree(forest, Vector3(at.x, 0, at.y), hash([grove_seed, index]))
		Grove.build(layout, walkable_outline, grove.groups, poison_groups, links, room_half, grove_seed)
	elif not is_start:
		_add_forest_cover(forest, shape)
	forest.collect_revelation_sites = false
	for direction: Vector2i in DIRECTIONS:
		var axis := Vector3(direction.x, 0, direction.y)
		var across := Vector3(axis.z, 0, -axis.x)
		var edge := axis * (room_half.x if direction.x != 0 else room_half.y)
		if not links.has(direction): continue
		for side in [-1.0, 1.0]:
			if direction != joined_entry:
				var flank: Vector3 = edge + across * side * DOOR_WIDTH * .5
				var outside := flank + axis * CORRIDOR
				_add_forest_barrier(flank, outside, .32, 1.25)
				if side > 0:
					forest.thicket(flank, outside, 6111 + direction.x + direction.y * 3)
				else:
					forest.thicket(outside, flank, 6129 + direction.x + direction.y * 3)
		if direction == joined_entry: continue
		var unexplored := direction in dark_exits
		var corridor := layout
		if unexplored:
			corridor = Node3D.new()
			corridor.name = "UnexploredExit_%d_%d" % [direction.x, direction.y]
			layout.add_child(corridor)
			forest.scout_bush(edge, axis, across)
			_add_scout_hint(corridor, direction, edge, axis)
		forest.passage(corridor, direction, edge, DOOR_WIDTH, CORRIDOR)
		var end := edge + axis * CORRIDOR
		_add_forest_barrier(end - across * DOOR_WIDTH * .5, end + across * DOOR_WIDTH * .5, .26, 1.0)
		if not cleared:
			box(gates, edge+Vector3.UP*.48, oriented(direction,DOOR_WIDTH,.96,.24), lock)
	forest.finish()
	revelation_growth = RevelationGrowth.new()
	revelation_growth.name = "RevelationGrowth"
	layout.add_child(revelation_growth)
	revelation_growth.setup(forest.revelation_sites, forest.revelation_borders, hash([floor_seed, "revelation_growth"]))
	if not feature.is_empty():
		hazards = Hazards.new()
		hazards.position = feature_origin
		layout.add_child(hazards)
		hazards.configure(feature, walkable_outline, feature_seed, poison_groups)


func present_revelation(revealed: bool, observer: Vector3) -> void:
	if revelation_growth != null:
		revelation_growth.present(revealed, observer)


func show_trap(data: Dictionary) -> void:
	if data.is_empty() or data.spent: return
	trap = Node3D.new()
	trap.position = data.position
	layout.add_child(trap)
	var steel := material("#655c53")
	var rim := material("#d6a46c")
	box(trap, Vector3.ZERO, Vector3(1.06, .065, 1.06), steel, false)
	for side in [-1.0, 1.0]:
		box(trap, Vector3(side * .46, .04, 0), Vector3(.09, .035, 1.0), rim, false)
		box(trap, Vector3(0, .04, side * .46), Vector3(.9, .035, .09), rim, false)
	box(trap, Vector3(0, .04, 0), Vector3(.45, .04, .36), material("#a96149"), false)


func hide_trap() -> void:
	trap.hide()
	trap.queue_free()
	trap = null


func _add_scout_hint(parent: Node3D, direction: Vector2i, edge: Vector3, axis: Vector3) -> void:
	var hint := Label3D.new()
	hint.text = "[E] ส่องผ่านพุ่ม"
	hint.position = edge - axis * .35 + Vector3.UP * 2.65
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.no_depth_test = true
	hint.font_size = 32
	hint.pixel_size = .01
	hint.outline_size = 8
	hint.modulate = Color("#dfdbac")
	hint.hide()
	parent.add_child(hint)
	peek_exits[direction] = hint

func peek_direction(at: Vector3) -> Vector2i:
	for direction: Vector2i in peek_exits:
		var hint: Label3D = peek_exits[direction]
		var flat := hint.global_position
		flat.y = at.y
		if at.distance_squared_to(flat) <= 2.45 * 2.45: return direction
	return Vector2i.ZERO

func update_peek_hints(at: Vector3, available: bool) -> void:
	var nearby := peek_direction(at) if available else Vector2i.ZERO
	for direction: Vector2i in peek_exits:
		peek_exits[direction].visible = direction == nearby

func _add_forest_borders(forest: Node3D, links: Dictionary) -> void:
	for index in walkable_outline.size():
		var first := walkable_outline[index]
		var last := walkable_outline[(index + 1) % walkable_outline.size()]
		var middle := (first + last) * .5
		var door := Vector2i.ZERO
		if is_equal_approx(absf(middle.x), room_half.x): door.x = int(signf(middle.x))
		if is_equal_approx(absf(middle.y), room_half.y): door.y = int(signf(middle.y))
		if links.has(door): continue
		var a := Vector3(first.x, 0, first.y)
		var b := Vector3(last.x, 0, last.y)
		forest.revelation_borders.append(a)
		forest.revelation_borders.append(b)
		_add_forest_barrier(a, b, .82, 1.7)
		forest.thicket(a, b, 5500 + index * 17)


func _add_forest_barrier(a: Vector3, b: Vector3, depth: float, height: float) -> void:
	var along := b - a
	var rotation := Basis(Vector3.UP, -atan2(along.z, along.x))
	var pose := Transform3D(rotation, (a + b) * .5 + Vector3.UP * height * .5)
	var size := Vector3(along.length() + .35, height, depth)
	sight_edges.append({"inverse": pose.affine_inverse(), "bounds": AABB(-size * .5, size)})
	if visual_only: return
	var body := StaticBody3D.new()
	body.transform = pose
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	layout.add_child(body)


func _add_grove_tree(forest: Node3D, at: Vector3, seed_: int) -> void:
	obstacles.append(at)
	forest.grove_tree(at, seed_)
	_add_forest_barrier(at - Vector3.RIGHT * .27, at + Vector3.RIGHT * .27, .84, 2.5)


func _add_forest_cover(forest: Node3D, variant: int) -> void:
	var positions: Array[Vector2]
	match variant:
		1: positions = [Vector2(-8.4, -4.6), Vector2(9.1, -5.2), Vector2(8.4, 5.5), Vector2(-9.6, 4.9)]
		2: positions = [Vector2(-6.9, 2.8), Vector2(7.5, 5.2), Vector2(3.5, 6.6), Vector2(-12.2, 6.6)]
		_: positions = [Vector2(-5.8, -6.0), Vector2(8.2, -6.8), Vector2(5.8, 6.0), Vector2(-8.2, 6.8)]
	for index in positions.size():
		var point := Vector3(positions[index].x, 0, positions[index].y)
		obstacles.append(point)
		forest.cover(point, variant, index)
		var half_width := .86 if index % 2 == 0 else .47
		var height := 1.12 if index % 2 == 0 else 2.5
		_add_forest_barrier(point - Vector3.RIGHT * (half_width - .18),
			point + Vector3.RIGHT * (half_width - .18), half_width * 2.0, height)


func is_walkable(point: Vector3, margin: float = .0) -> bool:
	var at := Vector2(point.x, point.z)
	if not Geometry2D.is_point_in_polygon(at, walkable_outline): return false
	if margin <= 0.0: return true
	for direction: Vector2i in DIRECTIONS:
		if not Geometry2D.is_point_in_polygon(at + Vector2(direction) * margin, walkable_outline): return false
	return true



func steer_around_cover(origin: Vector3, motion: Vector3, target_distance: float) -> Vector3:
	const CLEARANCE := 1.65
	if motion.length_squared() < .0001:
		return motion
	var direction := motion.normalized()
	if not is_walkable(origin + direction * minf(target_distance, 2.0)):
		direction = Vector3(-origin.x, 0, -origin.z).normalized()
		motion = direction * motion.length()
	var ahead := minf(target_distance, 3.5)
	var nearest := INF
	var detour := motion
	for cover in obstacles:
		var offset := cover - origin
		offset.y = 0
		var along := offset.dot(direction)
		if along <= 0 or along >= nearest:
			continue
		if (offset - direction * minf(along, ahead)).length_squared() >= CLEARANCE * CLEARANCE:
			continue
		var side := 1.0 if direction.cross(offset).y <= 0 else -1.0
		var angle := asin(minf(1.0, CLEARANCE / offset.length())) + .15
		detour = offset.normalized().rotated(Vector3.UP, side * angle) * motion.length()
		nearest = along
	return detour


func unlock_doors() -> void:
	layout.remove_child(gates)
	gates.queue_free()
	gates = null


func entry_position(direction: Vector2i) -> Vector3:
	return Vector3(direction.x*(room_half.x-1.0), .03, direction.y*(room_half.y-1.0))


func exit_direction(at: Vector3) -> Vector2i:
	if absf(at.x)>room_half.x+CORRIDOR-1.0 and absf(at.z)<DOOR_WIDTH*.5:
		return Vector2i(signi(roundi(at.x)), 0)
	if absf(at.z)>room_half.y+CORRIDOR-1.0 and absf(at.x)<DOOR_WIDTH*.5:
		return Vector2i(0, signi(roundi(at.z)))
	return Vector2i.ZERO


func oriented(direction: Vector2i, width: float, height: float, depth: float) -> Vector3:
	return Vector3(depth,height,width) if direction.x != 0 else Vector3(width,height,depth)


func material(hex: String) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color(hex)
	surface.roughness = .93
	return surface


func box(parent: Node3D, at: Vector3, size: Vector3, surface: Material, solid: bool = true) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = surface
	visual.position = at
	parent.add_child(visual)
	if solid and at.y + size.y * .5 >= .68:
		sight_boxes[visual] = AABB(at - size * .5, size)
	if not solid or visual_only: return visual
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return visual
