extends RefCounted
## Consume an authored distance curve, never frame velocity, for a short strike.
var requested: float = 0.0
var travelled: float = 0.0

func reset() -> void:
	requested = 0.0
	travelled = 0.0

func advance(body: CharacterBody3D, direction: Vector3, desired: float, targets: Array, limit: float = 0.75) -> float:
	if not is_finite(desired) or not is_finite(limit) or not direction.is_finite() or limit <= 0:
		return 0.0
	direction.y = 0
	if direction.length_squared() < 0.001: return 0.0
	direction = direction.normalized()
	var next: float = clampf(desired, requested, limit)
	var distance: float = next - requested
	requested = next
	if distance <= 0: return 0.0
	for target in targets:
		if not is_instance_valid(target) or target.dead: continue
		var offset: Vector3 = target.position - body.position
		offset.y = 0
		var along: float = offset.dot(direction)
		if along < 0: continue
		var radius: float = 0.86 if target.kind == "elite" else 0.74
		var across_squared: float = maxf(0.0, offset.length_squared() - along * along)
		if across_squared >= radius * radius: continue
		var contact: float = along - sqrt(maxf(0.0, radius * radius - across_squared))
		distance = minf(distance, maxf(0.0, contact))
	var before: Vector3 = body.position
	if distance > 0:
		var collision := body.move_and_collide(direction * distance, false, 0.001)
		# Floor recovery may return a vertical collision while the intended
		# movement remains horizontal. Continue only along that floor plane.
		if collision != null and collision.get_normal().y > 0.7:
			body.move_and_collide(collision.get_remainder().slide(collision.get_normal()), false, 0.001)
	var displacement: Vector3 = body.position - before
	displacement.y = 0
	var actual: float = displacement.length()
	travelled += actual
	return actual
