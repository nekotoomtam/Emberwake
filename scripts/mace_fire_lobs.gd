extends Node3D

signal detonated(point: Vector3, direct: Node3D, hit_ids: Dictionary, damage: float)
signal ember_sample(point: Vector3, direction: Vector3, age: float)
signal impacted(point: Vector3, direction: Vector3, leg: int, on_floor: bool)

const FireVisual = preload("res://scripts/mace_burning_clod_visual.gd")
const EnemyBody = preload("res://scripts/enemy.gd")
const Companion = preload("res://scripts/expedition_companion.gd")
const TERRAIN_MASK := 1
const ENEMY_MASK := 2
const FLIGHT_TIME := .58
const ARC_HEIGHT := 1.5
const LANDING_DISTANCE := 5.5
const LEG_TIMES := [FLIGHT_TIME, .39, .27]
const LEG_HEIGHTS := [ARC_HEIGHT, .85, .42]
const BOUNCE_DISTANCES := [3.2, 2.1]
const SPLIT_ANGLE := .46
const SPLIT_WIDTH := .53
const BLAST_RADIUS := .85

var active: Array[Dictionary] = []
var shots_fired := 0

func launch(origin: Vector3, target: Vector3, direction: Vector3, camera: Camera3D, damage: float) -> void:
	var visual := FireVisual.new()
	add_child(visual)
	visual.global_position = origin
	visual.update_visual(camera, (target - origin + Vector3.UP * ARC_HEIGHT * 4.0).normalized(), 0.0)
	active.append({"node": visual, "origin": origin, "target": target,
		"direction": direction, "age": 0.0, "total_age": 0.0, "leg": 0, "hit_ids": {}, "damage": damage})
	shots_fired += 1

func tick(delta: float, camera: Camera3D, world: World3D) -> void:
	for flight in active.duplicate():
		_advance(flight, delta, camera, world)

func _advance(flight: Dictionary, delta: float, camera: Camera3D, world: World3D) -> void:
	var visual: Node3D = flight.node
	if not is_instance_valid(visual) or visual.is_queued_for_deletion(): return
	var remaining := delta
	while remaining > .000001 and not visual.is_queued_for_deletion():
		var leg: int = flight.leg
		var duration: float = LEG_TIMES[leg]
		var height: float = LEG_HEIGHTS[leg]
		var step := minf(remaining, minf(.025, duration - float(flight.age)))
		if step <= 0.0: break
		var previous: Vector3 = visual.global_position
		flight.age += step
		flight.total_age += step
		remaining -= step
		var progress: float = flight.age / duration
		var point: Vector3 = flight.origin.lerp(flight.target, progress) + Vector3.UP * (4.0 * height * progress * (1.0 - progress))
		var hit := _first_contact(previous, point, world)
		if not hit.is_empty():
			var contact: Vector3 = hit.position
			if hit.collider is EnemyBody or hit.collider is Companion:
				_finish(flight, contact, false, hit.collider)
			elif hit.normal.y > .65:
				contact += hit.normal * .035
				_land(flight, contact, remaining, camera, world)
			else:
				_finish(flight, contact + hit.normal * .035, false)
			continue
		visual.global_position = point
		var direction := previous.direction_to(point)
		visual.update_visual(camera, direction, flight.total_age)
		if int(flight.total_age / .036) > int((flight.total_age - step) / .036):
			ember_sample.emit(point, direction, flight.total_age)
		if flight.age >= duration - .000001: _land(flight, flight.target, remaining, camera, world)

func _first_contact(from: Vector3, to: Vector3, world: World3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, TERRAIN_MASK | ENEMY_MASK | Companion.PROJECTILE_LAYER)
	query.hit_from_inside = true
	var excluded: Array[RID] = []
	while true:
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty(): return hit
		var body = hit.collider
		if body is EnemyBody:
			if not body.dead: return hit
		elif body is Companion:
			if not body.downed: return hit
		elif not body is CollisionObject3D or (body.collision_layer & TERRAIN_MASK) != 0:
			return hit
		excluded.append(hit.rid)
		query.exclude = excluded
	return {}

func _land(flight: Dictionary, point: Vector3, remaining: float, camera: Camera3D, world: World3D) -> void:
	var next_leg: int = flight.leg + 1
	if next_leg >= LEG_TIMES.size():
		_finish(flight, point, true)
		return
	flight.node.global_position = point
	flight.origin = point
	flight.target = point + flight.direction * float(BOUNCE_DISTANCES[next_leg - 1])
	flight.age = 0.0
	flight.leg = next_leg
	impacted.emit(point, flight.direction, next_leg - 1, true)
	detonated.emit(point, null, {}, flight.damage)
	if next_leg != 2 or flight.node.is_queued_for_deletion(): return
	flight.node.set_width(SPLIT_WIDTH)
	var split_hit_ids: Dictionary = flight.hit_ids
	var distance: float = BOUNCE_DISTANCES[next_leg - 1]
	for spread: float in [-SPLIT_ANGLE, SPLIT_ANGLE]:
		var heading: Vector3 = flight.direction.rotated(Vector3.UP, spread)
		var fragment := FireVisual.new()
		add_child(fragment)
		fragment.set_width(SPLIT_WIDTH * .91)
		fragment.global_position = point
		fragment.update_visual(camera, (heading + Vector3.UP * .55).normalized(), flight.total_age)
		var side_flight := {"node": fragment, "origin": point, "target": point + heading * distance,
			"direction": heading, "age": 0.0, "total_age": flight.total_age, "leg": next_leg, "hit_ids": split_hit_ids, "damage": flight.damage}
		active.append(side_flight)
		_advance(side_flight, remaining, camera, world)

func _finish(flight: Dictionary, point: Vector3, on_floor: bool, direct: Node3D = null) -> void:
	active.erase(flight)
	flight.node.queue_free()
	impacted.emit(point, flight.direction, flight.leg, on_floor)
	if on_floor or direct != null: detonated.emit(point, direct, flight.hit_ids, flight.damage)

func clear() -> void:
	for flight in active:
		if is_instance_valid(flight.node): flight.node.queue_free()
	active.clear()
	shots_fired = 0
