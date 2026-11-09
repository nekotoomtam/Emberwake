extends RefCounted
## Snapshot a nearby mouse-aligned target once, before accepting a melee stroke.

const AttackStep = preload("res://scripts/attack_step.gd")
const MACE_SECOND_DISTANCE := 0.75
const CONE_DOT := 0.8660254037844386 # Inclusive 30-degree ground-plane cone.
const SAFETY_INSET := 0.12
const RAY_HEIGHT := 0.68
const TIE_EPSILON := 0.000001


func choose(family: String, stage: int, origin: Vector3, aim: Vector3, definition: Dictionary, targets: Array, world: World3D = null) -> Dictionary:
	var direction := Vector3(aim.x, 0.0, aim.z)
	if not direction.is_finite(): direction = Vector3.ZERO
	if direction.length_squared() > 0.000001: direction = direction.normalized()
	var plan := {
		"target_id": 0,
		"target_position": Vector3.ZERO,
		"direction": direction,
		"distance": 0.0,
		"search_radius": 0.0,
		"distance_limit": 0.0,
		"assisted": false,
		"reason": "unsupported",
	}
	if not AttackStep.DISTANCES.has(family) or stage < 0 or stage > 2:
		return plan
	var mace_second := family == "mace" and stage == 1
	var base_distance: float = MACE_SECOND_DISTANCE if mace_second else AttackStep.DISTANCES[family][stage]
	plan.distance = base_distance
	plan.distance_limit = base_distance
	if not origin.is_finite():
		plan.reason = "invalid_origin"
		return plan
	if not aim.is_finite() or direction.length_squared() < 0.000001:
		plan.reason = "invalid_aim"
		return plan
	if not _finite_number(definition.get("reach")) or float(definition.reach) < 0.0 or not is_finite(float(definition.reach) * 2.0):
		plan.reason = "invalid_definition"
		return plan
	var search_radius: float = float(definition.reach) * 2.0
	plan.search_radius = search_radius
	plan.distance_limit = maxf(base_distance, float(definition.reach) + SAFETY_INSET)
	var best_alignment := -1.0
	var best_distance := INF
	var best_id := 0
	var best_position := Vector3.ZERO
	var best_direction := Vector3.ZERO
	var best_required := 0.0
	var best_in_range := false
	for target in targets:
		if not is_instance_valid(target) or not target is Node3D:
			continue
		if target.get("dead") != false or not _finite_number(target.get("health")) or float(target.get("health")) <= 0.0:
			continue
		var target_position: Vector3 = target.global_position
		if not target_position.is_finite(): continue
		var offset := target_position - origin
		offset.y = 0.0
		var target_distance := offset.length()
		if not is_finite(target_distance) or target_distance <= TIE_EPSILON: continue
		if target_distance > search_radius + TIE_EPSILON: continue
		var target_direction := offset / target_distance
		var alignment := direction.dot(target_direction)
		if alignment + TIE_EPSILON < CONE_DOT: continue
		var radius := 0.55 if target.get("kind") == "elite" else 0.36
		var reach: float = float(definition.reach) + radius
		var in_range := target_distance <= reach
		var required: float = maxf(base_distance, target_distance - reach + SAFETY_INSET)
		if world != null:
			var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * RAY_HEIGHT, target_position + Vector3.UP * RAY_HEIGHT, 1)
			if not world.direct_space_state.intersect_ray(ray).is_empty(): continue
		var target_id: int = target.get_instance_id()
		var same_alignment := absf(alignment - best_alignment) <= TIE_EPSILON
		var nearer := target_distance < best_distance - TIE_EPSILON
		var same_distance := absf(target_distance - best_distance) <= TIE_EPSILON
		var better_alignment := alignment > best_alignment + TIE_EPSILON
		if not nearer and not (same_distance and (better_alignment or (same_alignment and target_id < best_id))):
			continue
		best_alignment = alignment
		best_distance = target_distance
		best_id = target_id
		best_position = target_position
		best_direction = target_direction
		best_required = required
		best_in_range = in_range
	if best_id == 0:
		plan.reason = "no_target"
		return plan
	plan.target_id = best_id
	plan.target_position = best_position
	if best_in_range:
		plan.reason = "in_range"
		return plan
	plan.direction = best_direction
	plan.distance = best_required
	plan.assisted = true
	plan.reason = "approach"
	return plan


func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value))
