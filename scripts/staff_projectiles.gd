extends Node3D
## Friendly finite swept fire. Optional short penetration locks to the first exit.

signal rifle_hit(enemy,damage: float,knock: Vector3)
signal bolt_hit(enemy, damage: float, knock: Vector3)
signal fire_patch(position: Vector3)
signal impact(position: Vector3, reason: String)
signal damage_hit(enemy, damage: float, knock: Vector3, element: String)
signal impact_element(position: Vector3, reason: String, element: String)
signal area_impact(position: Vector3, radius: float, element: String)

const CrossbowArt = preload("res://scripts/crossbow_art.gd")
const BowArt = preload("res://scripts/bow_art.gd")
const CONTACT_EPSILON := 0.000001
const HISTORY_LIMIT := 32
var active: Array[Dictionary] = []
var shots_fired := 0
var resolved: Array[Dictionary] = []
var _clear_generation := 0

func spawn_fireball(where: Vector3, direction: Vector3, definition: Dictionary, camera: Camera3D) -> bool:
	if not where.is_finite() or not direction.is_finite(): return false
	var ground := Vector3(direction.x, 0.0, direction.z)
	var largest := maxf(absf(ground.x), absf(ground.z))
	if largest <= 0.0: return false
	ground = (ground / largest).normalized()
	var element := "physical" if definition.get("element", "fire") == "physical" else "fire"
	var physical := element == "physical"
	var damage := _positive_setting(definition, ["damage"], 18.0 if physical else 24.0)
	var max_range := _positive_setting(definition, ["projectile_range", "max_range", "range"], 7.0 if physical else 6.0)
	var speed := _positive_setting(definition, ["projectile_speed", "speed"], 18.0 if physical else 8.5)
	var radius := _positive_setting(definition, ["projectile_radius", "radius"], 0.10 if physical else 0.18)
	var knockback := _positive_setting(definition, ["knockback"], 0.8 if physical else 1.4)
	if minf(minf(damage, max_range), minf(speed, minf(radius, knockback))) <= 0.0: return false
	var pierce_after_exit := 0.0
	if definition.has("pierce_after_exit"):
		pierce_after_exit = _positive_setting(definition, ["pierce_after_exit"], 0.0)
		if pierce_after_exit <= 0.0: return false
	var splash_radius := 0.0
	var splash_damage := 0.0
	if not physical and (definition.has("splash_radius") or definition.has("splash_damage")):
		splash_radius = _positive_setting(definition, ["splash_radius"], 0.0)
		splash_damage = _positive_setting(definition, ["splash_damage"], 0.0)
		if splash_radius <= 0.0 or splash_damage <= 0.0: return false
	var launch_origin: Variant = definition.get("launch_origin", where)
	if not (launch_origin is Vector3) or not launch_origin.is_finite(): return false
	var node: Node3D
	var visual_path := "res://scripts/bullet_visual.gd" if physical else "res://scripts/fireball_visual.gd"
	if physical and definition.get("projectile_visual", "") == "rifle":
		visual_path = "res://scripts/rifle_bullet_visual.gd"
	if physical and definition.get("projectile_visual") in ["arrow", "bolt"]:
		var arrow := Sprite3D.new()
		arrow.texture = CrossbowArt.bolt_texture() if definition.projectile_visual == "bolt" else BowArt.arrow_texture()
		arrow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		arrow.pixel_size = 0.026
		arrow.shaded = false
		arrow.offset = Vector2(-8, 0)
		node = arrow
	elif ResourceLoader.exists(visual_path):
		node = load(visual_path).new()
	else:
		node = Node3D.new()
	add_child(node)
	node.global_position = where
	active.append({"node": node, "origin": where, "direction": ground, "damage": damage,
		"element": element, "travelled": 0.0, "max_range": max_range, "speed": speed,
		"bolt":definition.get("projectile_visual", "") == "bolt", "rifle":definition.get("projectile_visual","")=="rifle","rifle_aimed":bool(definition.get("rifle_aimed",false)),"max_targets":int(definition.get("max_targets",0)),
		"radius": radius, "age": 0.0, "knockback": knockback,"ground_fire":bool(definition.get("ground_fire",false)) and not physical,
		"launch_origin": launch_origin, "launch_pending": true,
		"pierce_after_exit": pierce_after_exit, "pierce_started": false, "hitids": [],
		"splash_radius": splash_radius, "splash_damage": splash_damage})
	shots_fired += 1
	_update_visual(active.back(), camera)
	return true

func tick(delta: float, enemies: Array, world: World3D, on_hit: Callable, camera: Camera3D) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	for entry: Dictionary in active.duplicate():
		if not active.has(entry): continue
		if not is_instance_valid(entry.node):
			active.erase(entry)
			continue
		if entry.pierce_after_exit > 0.0:
			_tick_piercing(entry, delta, enemies, world, on_hit, camera)
			continue
		# The visible tip may already be beyond a close monster or a thin wall.
		# Resolve this safety segment only when simulation advances, never on spawn.
		if entry.launch_pending:
			entry.launch_pending = false
			var launch: Dictionary = _first_contact(entry.launch_origin, entry.origin, entry.radius, enemies, world)
			if not launch.is_empty():
				_finish(entry, launch.position, launch.reason, launch.get("enemy"), on_hit, enemies, world)
				continue
		var remaining: float = maxf(0.0, entry.max_range - entry.travelled)
		# Compare before multiplying, so even very large finite deltas stay bounded.
		var distance: float = remaining if delta >= remaining / entry.speed else entry.speed * delta
		var old: Vector3 = entry.node.global_position
		var end: Vector3 = old + entry.direction * distance
		var contact: Dictionary = _first_contact(old, end, entry.radius, enemies, world)
		entry.age += delta
		if not contact.is_empty():
			entry.travelled = minf(entry.max_range, entry.travelled + distance * contact.fraction)
			_finish(entry, contact.position, contact.reason, contact.get("enemy"), on_hit, enemies, world)
			continue
		entry.travelled = minf(entry.max_range, entry.travelled + distance)
		entry.node.global_position = end
		if entry.travelled >= entry.max_range:
			_finish(entry, end, "range", null, on_hit, enemies, world)
		else:
			_update_visual(entry, camera)

func clear() -> void:
	_clear_generation += 1
	for entry: Dictionary in active:
		_remove_node(entry.node)
	active.clear()
	shots_fired = 0
	resolved.clear()

func _positive_setting(definition: Dictionary, keys: Array, fallback: float) -> float:
	for key in keys:
		if not definition.has(key): continue
		var value: Variant = definition[key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]: return -1.0
		var number := float(value)
		return number if is_finite(number) and number > 0.0 else -1.0
	return fallback

func _tick_piercing(entry: Dictionary, delta: float, enemies: Array, world: World3D, on_hit: Callable, camera: Camera3D) -> void:
	entry.age += delta
	if entry.launch_pending:
		entry.launch_pending = false
		if _sweep_piercing(entry, entry.launch_origin, entry.origin, enemies, world, on_hit, true): return
	var remaining: float = maxf(0.0, entry.max_range - entry.travelled)
	var distance: float = remaining if delta >= remaining / entry.speed else entry.speed * delta
	var start: Vector3 = entry.node.global_position
	if _sweep_piercing(entry, start, start + entry.direction * distance, enemies, world, on_hit): return
	if distance >= remaining:
		# The swept endpoint already used the exact remaining budget. Avoid
		# keeping diagonal flights alive due to Vector3 projection roundoff.
		entry.travelled = entry.max_range
		_finish(entry, entry.node.global_position, "range", null, on_hit, enemies, world)
	else:
		_update_visual(entry, camera)

func _sweep_piercing(entry: Dictionary, start: Vector3, end: Vector3, enemies: Array, world: World3D, on_hit: Callable, launch := false) -> bool:
	# A zero-length launch has no sweep direction; the forward flight handles it.
	if launch and start.is_equal_approx(end): return false
	var cursor := start
	# Every contact marks a unique ID before user code runs. One extra iteration
	# resolves the remaining segment, keeping even a huge time step bounded.
	var contact_budget := enemies.size() + 1
	for index in range(contact_budget):
		if not active.has(entry) or not is_instance_valid(entry.node): return true
		var sweep_end := end
		var reaches_cutoff := false
		if entry.pierce_started:
			var start_distance: float = (cursor - entry.origin).dot(entry.direction)
			var end_distance: float = (end - entry.origin).dot(entry.direction)
			if end_distance >= entry.pierce_cutoff - CONTACT_EPSILON:
				reaches_cutoff = true
				var span := end_distance - start_distance
				var fraction := clampf((entry.pierce_cutoff - start_distance) / span, 0.0, 1.0) if span > 0.0 else 0.0
				sweep_end = cursor.lerp(end, fraction)
		var contact := _first_contact(cursor, sweep_end, entry.radius, enemies, world, entry.hitids)
		if contact.is_empty():
			entry.node.global_position = sweep_end
			entry.travelled = clampf((sweep_end - entry.origin).dot(entry.direction), 0.0, entry.max_range)
			if reaches_cutoff:
				_finish(entry, sweep_end, "pierce_limit", null, on_hit, enemies, world)
				return true
			return false
		entry.node.global_position = contact.position
		entry.travelled = clampf((contact.position - entry.origin).dot(entry.direction), 0.0, entry.max_range)
		if contact.reason == "cover":
			_finish(entry, contact.position, "cover", null, on_hit, enemies, world)
			return true
		if not entry.pierce_started:
			# Capture the far root before damage callbacks can move or kill the target.
			var ground := Vector3(end.x - start.x, 0.0, end.z - start.z).normalized()
			var cutoff: Vector3 = contact.exit_position + ground * entry.pierce_after_exit
			entry.pierce_cutoff = minf(entry.max_range, (cutoff - entry.origin).dot(entry.direction))
			entry.cutoff_position = entry.origin + entry.direction * entry.pierce_cutoff
			entry.first_exit_position = contact.exit_position
			entry.pierce_started = true
		entry.hitids.append(contact.enemy.get_instance_id())
		_emit_enemy_contact(entry, contact.position, contact.enemy, on_hit)
		if not active.has(entry):return true
		if entry.max_targets>0 and entry.hitids.size()>=entry.max_targets:
			_finish(entry,contact.position,"hit_limit",null,on_hit,enemies,world);return true
		cursor = contact.position
	return not active.has(entry)

func _first_contact(start: Vector3, end: Vector3, radius: float, enemies: Array, world: World3D, ignored_ids: Array = []) -> Dictionary:
	var result: Dictionary = {}
	var first_fraction := INF
	var ground_segment := Vector2(end.x - start.x, end.z - start.z)
	var length := ground_segment.length()
	var unit := ground_segment / length if length > 0.0 else Vector2.ZERO
	for enemy in enemies:
		if not is_instance_valid(enemy) or not (enemy is Node3D): continue
		if enemy.get_instance_id() in ignored_ids: continue
		if enemy.get("dead") == true: continue
		var health: Variant = enemy.get("health")
		if health == null or float(health) <= 0.0: continue
		var regions: Array=enemy.image_hurt_regions(start.y) if enemy.has_method("image_hurt_regions") else enemy.hurt_regions() if enemy.has_method("hurt_regions") else [{"position":enemy.global_position,"radius":.55 if enemy.get("kind")=="elite" else .36}]
		for region in regions:
			var center: Vector3 = region.position
			if not center.is_finite(): continue
			var expanded := radius + float(region.radius)
			var offset := Vector2(start.x - center.x, start.z - center.z)
			var outside := offset.length_squared() - expanded * expanded
			var distance := 0.0
			var exit_distance := 0.0
			if length > 0.0:
				var projection := offset.dot(unit)
				var discriminant := projection * projection - outside
				if discriminant < 0.0: continue
				var root := sqrt(discriminant)
				exit_distance = maxf(0.0, -projection + root)
				if outside > 0.0:
					distance = -projection - root
					if distance < -CONTACT_EPSILON or distance > length + CONTACT_EPSILON: continue
			elif outside > 0.0:
				continue
			var fraction := clampf(distance / length, 0.0, 1.0) if length > 0.0 else 0.0
			if fraction < first_fraction:
				first_fraction = fraction
				result = {"fraction": fraction, "position": start.lerp(end, fraction), "reason": "enemy", "enemy": enemy,
					"exit_position": start + Vector3(unit.x, 0.0, unit.y) * exit_distance}
		# Image bodies comprise several cells. Short rifle penetration starts at
		# the body's far edge, not the first tiny cell's exit. Boss limb rules stay separate.
		if result.get("enemy")==enemy and enemy.has_method("image_hurt_regions") and length>0:
			var farthest:=0.0
			for region in regions:
				var offset:=Vector2(start.x-region.position.x,start.z-region.position.z)
				var projection:=offset.dot(unit)
				var expanded:=radius+float(region.radius)
				var discriminant:=projection*projection-offset.length_squared()+expanded*expanded
				if discriminant>=0:farthest=maxf(farthest,-projection+sqrt(discriminant))
			result.exit_position=start+Vector3(unit.x,0,unit.y)*farthest
	if is_instance_valid(world) and not start.is_equal_approx(end):
		var query := PhysicsRayQueryParameters3D.create(start, end, 1)
		query.hit_from_inside = true
		var cover: Dictionary = world.direct_space_state.intersect_ray(query)
		if not cover.is_empty():
			var fraction := clampf(start.distance_to(cover.position) / start.distance_to(end), 0.0, 1.0)
			# Cover owns ties, preventing an enemy surface on a wall from taking damage through it.
			if fraction <= first_fraction + CONTACT_EPSILON:
				result = {"fraction": fraction, "position": cover.position, "reason": "cover"}
	return result

func _emit_enemy_contact(entry: Dictionary, position: Vector3, enemy, on_hit: Callable) -> void:
	var factor: float=maxf(.0,1.0-.25*(entry.hitids.size()-1)) if entry.rifle_aimed else 1.0
	if entry.rifle:
		rifle_hit.emit(enemy,entry.damage*factor,entry.direction*entry.knockback)
		if not active.has(entry):return
		impact.emit(position,"enemy");impact_element.emit(position,"enemy",entry.element);return
	if on_hit.is_valid(): on_hit.call(enemy, entry.damage, entry.direction * entry.knockback)
	damage_hit.emit(enemy, entry.damage, entry.direction * entry.knockback, entry.element)
	impact.emit(position, "enemy")
	impact_element.emit(position, "enemy", entry.element)

func _finish(entry: Dictionary, position: Vector3, reason: String, enemy, on_hit: Callable, enemies: Array = [], world: World3D = null) -> void:
	var generation := _clear_generation
	active.erase(entry)
	_remove_node(entry.node)
	var record := {"direction":entry.direction,"rifle_aimed":entry.rifle_aimed,"reason": reason, "position": position, "travelled": entry.travelled, "element": entry.element}
	if is_instance_valid(enemy): record["targetid"] = enemy.get_instance_id()
	var detonate: bool = reason == "enemy" and is_instance_valid(enemy) and entry.element == "fire" and entry.splash_radius > 0.0
	# Capture the primary's ground height and ID before direct damage can kill,
	# remove or reposition it. The blast stays at the swept contact location.
	var primary_id: int = enemy.get_instance_id() if detonate else 0
	var blast_ground_y: float = enemy.global_position.y if detonate else 0.0
	if detonate:
		record["splash_radius"] = entry.splash_radius
		record["splash_hitids"] = []
	if entry.pierce_after_exit > 0.0:
		record["hitids"] = entry.hitids.duplicate()
		if entry.pierce_started:
			record["pierce_cutoff"] = entry.pierce_cutoff
			record["cutoff_position"] = entry.cutoff_position
			record["first_exit_position"] = entry.first_exit_position
	resolved.append(record)
	if resolved.size() > HISTORY_LIMIT: resolved.pop_front()
	if reason == "enemy" and is_instance_valid(enemy):
		if on_hit.is_valid(): on_hit.call(enemy, entry.damage, entry.direction * entry.knockback)
		if detonate and generation != _clear_generation: return
		if entry.rifle:rifle_hit.emit(enemy,entry.damage,entry.direction*entry.knockback)
		elif entry.bolt:bolt_hit.emit(enemy, entry.damage, entry.direction * entry.knockback)
		else:damage_hit.emit(enemy, entry.damage, entry.direction * entry.knockback, entry.element)
		if detonate and generation != _clear_generation: return
	if detonate:
		_apply_splash(entry, position, blast_ground_y, primary_id, enemies, world, on_hit, record.splash_hitids, generation)
		if generation != _clear_generation: return
		area_impact.emit(position, entry.splash_radius, entry.element)
		if generation != _clear_generation: return
	if generation!=_clear_generation:return
	if entry.get("ground_fire",false):
		fire_patch.emit(Vector3(position.x,0,position.z)-entry.direction*.05)
		if generation!=_clear_generation:return
	if reason!="hit_limit":
		impact.emit(position, reason)
		impact_element.emit(position, reason, entry.element)

func _apply_splash(entry: Dictionary, position: Vector3, ground_y: float, primary_id: int, enemies: Array, world: World3D, on_hit: Callable, hitids: Array, generation: int) -> void:
	var ray_origin := Vector3(position.x, ground_y + 0.68, position.z)
	for enemy in enemies.duplicate():
		# Clear may run synchronously in either damage consumer. Abandon the old
		# blast even if that consumer immediately starts a new projectile session.
		if generation != _clear_generation: return
		if not is_instance_valid(enemy) or not enemy is Node3D: continue
		var target_id: int = enemy.get_instance_id()
		if target_id == primary_id or target_id in hitids or enemy.get("dead") == true: continue
		var health: Variant = enemy.get("health")
		if typeof(health) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(health)) or float(health) <= 0.0: continue
		var target_position: Vector3 = enemy.global_position
		if not target_position.is_finite(): continue
		var offset := Vector2(target_position.x - position.x, target_position.z - position.z)
		var radius: float = entry.splash_radius + (0.55 if enemy.get("kind") == "elite" else 0.36)
		var inside: bool=offset.length_squared()<=radius*radius+CONTACT_EPSILON
		if enemy.has_method("hurt_regions"):
			inside=false
			for region in enemy.hurt_regions():
				var gap:=Vector2(region.position.x-position.x,region.position.z-position.z)
				if gap.length_squared()<=pow(float(entry.splash_radius)+float(region.radius),2)+CONTACT_EPSILON:inside=true;break
		if not inside:continue
		if is_instance_valid(world):
			var ray_end := target_position + Vector3.UP * 0.68
			if not ray_origin.is_equal_approx(ray_end):
				var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1)
				query.hit_from_inside = true
				if not world.direct_space_state.intersect_ray(query).is_empty(): continue
		# Mark before consumers run, so duplicate target entries cannot deal twice.
		hitids.append(target_id)
		var knock: Vector3 = entry.direction * entry.knockback
		if on_hit.is_valid(): on_hit.call(enemy, entry.splash_damage, knock)
		if generation != _clear_generation: return
		damage_hit.emit(enemy, entry.splash_damage, knock, entry.element)
		if generation != _clear_generation: return

func _remove_node(node) -> void:
	if not is_instance_valid(node): return
	if node.get_parent() != null: node.get_parent().remove_child(node)
	node.queue_free()

func _update_visual(entry: Dictionary, camera: Camera3D) -> void:
	if is_instance_valid(camera) and entry.node is Sprite3D:
		var arrow: Sprite3D = entry.node
		var projection := Vector2(camera.global_basis.x.dot(entry.direction), camera.global_basis.y.dot(entry.direction))
		arrow.global_basis = camera.global_basis * Basis(Vector3.BACK, projection.angle())
		arrow.scale.x = maxf(0.35, projection.length())
	elif is_instance_valid(camera) and entry.node.has_method("update_visual"):
		if entry.node.has_method("configure_contact"):entry.node.configure_contact(entry.radius)
		entry.node.update_visual(camera, entry.direction, entry.age)
