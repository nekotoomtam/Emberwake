extends Node3D
const Companion = preload("res://scripts/expedition_companion.gd")
signal friendly_hit(ally: Companion, damage: float)
## Friendly finite swept fire. Optional short penetration locks to the first exit.

signal rifle_hit(enemy,damage: float,knock: Vector3)
signal rifle_armor_hit(enemy, damage: float, knock: Vector3, stacks: int)
signal rifle_mark_hit(enemy, damage: float, knock: Vector3)
signal rifle_pellet_hit(enemy, damage: float, knock: Vector3, volley: Dictionary)
signal rifle_pellet_impact(position: Vector3, color: Color)
signal rifle_split(position: Vector3, direction: Vector3, reach: float, half_angle: float)
signal rifle_pierce_spark(position: Vector3)
signal bolt_hit(enemy, damage: float, knock: Vector3)
signal fire_patch(position: Vector3)
signal impact(position: Vector3, reason: String)
signal damage_hit(enemy, damage: float, knock: Vector3, element: String)
signal companion_hit(enemy, damage: float, knock: Vector3, element: String, bolt: bool)
signal ice_volley_hit(enemy, damage: float, knock: Vector3)
signal ice_volley_contact(position: Vector3)
signal chain_lightning_contact(position: Vector3)
signal lightning_jump(from: Vector3, to: Vector3)
signal sword_wave_hit(enemy, damage: float, knock: Vector3, kind: String)
signal vacuum_wake_segment(from: Vector3, to: Vector3)
signal impact_element(position: Vector3, reason: String, element: String)
signal area_impact(position: Vector3, radius: float, element: String)
signal area_visual(position: Vector3, ground_y: float, radius: float, element: String, charged_fire: bool)

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
	var element := String(definition.get("element", "fire"))
	if element not in ["physical", "fire", "ice", "lightning"]: element = "fire"
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
	if physical and definition.get("projectile_visual", "") == "sword_wave":
		visual_path = "res://scripts/sword_wave_visual.gd"
	if physical and definition.get("projectile_visual", "") == "vacuum_wave":
		visual_path = "res://scripts/vacuum_wave_visual.gd"
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
	if not physical:
		node.configure_element(element)
		node.charged_art = bool(definition.get("charged_fire_art", false)) and element == "fire"
		node.basic_staff_art = bool(definition.get("basic_staff_art", false))
		node.ice_volley_art = definition.has("ice_angles")
		node.chain_lightning_art = definition.has("chain_damage")
	var rifle_aimed := bool(definition.get("rifle_aimed", false))
	var piercing_round: bool = physical and definition.get("projectile_visual", "") == "rifle" and bool(definition.get("piercing_round", false))
	if physical and definition.get("projectile_visual", "") == "rifle" and definition.has("tracer_color"):
		node.tint_tracer(definition.tracer_color)
		node.length_scale = float(definition.get("tracer_length", 1.0))
	var pellet: bool = definition.has("scatter_volley")
	if pellet: node.length_scale = .29
	active.append({"node": node, "origin": where, "direction": ground, "damage": damage,
		"sword_wave": String(definition.get("projectile_visual", "")) if physical and definition.get("projectile_visual", "") in ["sword_wave", "vacuum_wave"] else "",
		"element": element, "ice_volley": definition.has("ice_angles"), "travelled": 0.0, "max_range": max_range, "speed": speed,
		"charged_fire_art": bool(definition.get("charged_fire_art", false)),
		"companion_shot": bool(definition.get("companion_shot", false)),
		"chain_damage": definition.get("chain_damage", []), "chain_radius": float(definition.get("chain_radius", 0.0)),
		"bolt":definition.get("projectile_visual", "") == "bolt", "rifle":definition.get("projectile_visual","")=="rifle","rifle_aimed":rifle_aimed,"max_targets":int(definition.get("max_targets",0)),
		"rifle_falloff": float(definition.get("rifle_falloff", .25 if rifle_aimed else 0.0)),
		"piercing_round": piercing_round,
		"armor_break_stacks": int(definition.get("armor_break_stacks", 0)),
		"mark_round": bool(definition.get("mark_round", false)),
		"pellet": pellet, "scatter_volley": definition.get("scatter_volley", {}),
		"rifle_split": definition.get("rifle_split", {}), "tracer_color": definition.get("tracer_color", Color.WHITE),
		"radius": radius, "age": 0.0, "knockback": knockback,"ground_fire":bool(definition.get("ground_fire",false)) and element == "fire",
		"launch_origin": launch_origin, "launch_pending": true,
		"wake_ground_y": definition.get("wake_ground_y", launch_origin.y - 0.75),
		"pierce_after_exit": pierce_after_exit, "pierce_started": false, "hitids": [],
		"enemy_hits": 0,
		"block_on_ally": bool(definition.get("block_on_ally", false)),
		"pierce_damage_multiplier": float(definition.get("pierce_damage_multiplier", 1.0)),
		"splash_radius": splash_radius, "splash_damage": splash_damage,
		"splash_on_stop": bool(definition.get("splash_on_stop", false)),
		"splash_ground_y": float(definition.get("splash_ground_y", 0.0))})
	shots_fired += 1
	_update_visual(active.back(), camera)
	return true

func spawn_rifle_pellets(origin: Vector3, direction: Vector3, definition: Dictionary, angles: Array, camera: Camera3D) -> Array[Dictionary]:
	var pellets: Array[Dictionary] = []
	definition.scatter_volley = {}
	for offset: float in angles:
		var spread_direction := direction.rotated(Vector3.DOWN, deg_to_rad(offset))
		if spawn_fireball(origin, spread_direction, definition, camera):
			pellets.append(active.back())
	return pellets

func tick(delta: float, enemies: Array, world: World3D, on_hit: Callable, camera: Camera3D, allies: Array = []) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	var player_targets := enemies if allies.is_empty() else enemies + allies
	for entry: Dictionary in active.duplicate():
		if not active.has(entry): continue
		if not is_instance_valid(entry.node):
			active.erase(entry)
			continue
		var targets := enemies if entry.companion_shot else player_targets
		if entry.pierce_after_exit > 0.0 or entry.sword_wave == "vacuum_wave":
			_tick_piercing(entry, delta, targets, world, on_hit, camera)
		else:
			_tick_direct(entry, delta, targets, world, on_hit, camera)

func _tick_direct(entry: Dictionary, delta: float, enemies: Array, world: World3D, on_hit: Callable, camera: Camera3D) -> void:
	# The visible tip may already be beyond a close monster or a thin wall.
	if entry.launch_pending:
		entry.launch_pending = false
		var launch := _first_contact(entry.launch_origin, entry.origin, entry.radius, enemies, world)
		if not launch.is_empty():
			_finish(entry, launch.position, launch.reason, launch.get("enemy"), on_hit, enemies, world)
			return
	var remaining: float = maxf(0.0, entry.max_range - entry.travelled)
	# Compare before multiplying, so even very large finite deltas stay bounded.
	var distance: float = remaining if delta >= remaining / entry.speed else entry.speed * delta
	var old: Vector3 = entry.node.global_position
	var end: Vector3 = old + entry.direction * distance
	var contact := _first_contact(old, end, entry.radius, enemies, world)
	entry.age += delta
	if not contact.is_empty():
		entry.travelled = minf(entry.max_range, entry.travelled + distance * contact.fraction)
		_finish(entry, contact.position, contact.reason, contact.get("enemy"), on_hit, enemies, world)
		return
	entry.travelled = minf(entry.max_range, entry.travelled + distance)
	entry.node.global_position = end
	if distance < remaining:
		_update_visual(entry, camera)
	elif not entry.rifle_split.is_empty():
		_split_rifle_round(entry, end, enemies, world, on_hit)
	else:
		_finish(entry, end, "range", null, on_hit, enemies, world)

func _split_rifle_round(entry: Dictionary, position: Vector3, enemies: Array, world: World3D, on_hit: Callable) -> void:
	var generation := _clear_generation
	var spec: Dictionary = entry.rifle_split
	var direction: Vector3 = entry.direction
	var forward := Vector2(direction.x, direction.z)
	var reach: float = spec.reach
	var half_angle: float = spec.half_angle
	_finish(entry, position, "split", null, on_hit, enemies, world)
	rifle_split.emit(position, direction, reach, half_angle)
	var hit_ids: Dictionary = {}
	for enemy in enemies.duplicate():
		if generation != _clear_generation: return
		if not is_instance_valid(enemy) or not enemy is Node3D or enemy.get("dead") == true: continue
		var target_id: int = enemy.get_instance_id()
		if hit_ids.has(target_id): continue
		if not _inside_split_cone(enemy, position, forward, reach, half_angle, world): continue
		hit_ids[target_id] = true
		if enemy is Companion:
			friendly_hit.emit(enemy, spec.damage)
			continue
		var knock: Vector3 = direction * float(spec.knockback)
		if on_hit.is_valid(): on_hit.call(enemy, spec.damage, knock)
		if generation != _clear_generation: return
		rifle_hit.emit(enemy, spec.damage, knock)

func _inside_split_cone(enemy, origin: Vector3, forward: Vector2, reach: float, half_angle: float, world: World3D) -> bool:
	for region in _enemy_hurt_regions(enemy, origin.y):
		var center: Vector3 = region.position
		if not center.is_finite(): continue
		var offset := Vector2(center.x - origin.x, center.z - origin.z)
		if offset.dot(forward) < 0.0: continue
		var angle := clampf(forward.angle_to(offset), -half_angle, half_angle)
		var ray := forward.rotated(angle)
		var nearest := ray * clampf(offset.dot(ray), 0.0, reach)
		if offset.distance_squared_to(nearest) > pow(float(region.radius), 2) + CONTACT_EPSILON: continue
		var contact := origin + Vector3(offset.x, 0.0, offset.y)
		if is_instance_valid(world) and not origin.is_equal_approx(contact):
			var query := PhysicsRayQueryParameters3D.create(origin, contact, 1)
			query.hit_from_inside = true
			if not world.direct_space_state.intersect_ray(query).is_empty(): continue
		return true
	return false

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
			_advance_piercing_position(entry, cursor, sweep_end)
			if reaches_cutoff:
				_finish(entry, sweep_end, "pierce_limit", null, on_hit, enemies, world)
				return true
			return false
		_advance_piercing_position(entry, cursor, contact.position)
		if contact.reason == "cover":
			_finish(entry, contact.position, "cover", null, on_hit, enemies, world)
			return true
		var friendly: bool = contact.enemy is Companion
		if friendly and entry.block_on_ally:
			_finish(entry, contact.position, "enemy", contact.enemy, on_hit, enemies, world)
			return true
		if not friendly: entry.enemy_hits += 1
		if not friendly and entry.pierce_after_exit > 0.0 and not entry.pierce_started:
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
		if entry.max_targets>0 and entry.enemy_hits>=entry.max_targets:
			_finish(entry,contact.position,"hit_limit",null,on_hit,enemies,world);return true
		cursor = contact.position
	return not active.has(entry)

func _advance_piercing_position(entry: Dictionary, from: Vector3, to: Vector3) -> void:
	entry.node.global_position = to
	entry.travelled = clampf((to - entry.origin).dot(entry.direction), 0.0, entry.max_range)
	if entry.sword_wave == "vacuum_wave" and not from.is_equal_approx(to):
		var base: Vector3 = entry.node.ground_anchor(to, entry.direction, entry.radius, entry.wake_ground_y)
		var start := base - (to - from)
		var launch: Vector3 = entry.launch_origin
		launch.y = base.y
		if (base - launch).dot(entry.direction) > CONTACT_EPSILON:
			if (start - launch).dot(entry.direction) < 0.0: start = launch
			vacuum_wake_segment.emit(start, base)

func _enemy_hurt_regions(enemy, height: float) -> Array:
	if enemy is Companion: return enemy.projectile_hurt_regions(height)
	if enemy.has_method("image_hurt_regions"): return enemy.image_hurt_regions(height)
	if enemy.has_method("hurt_regions"): return enemy.hurt_regions()
	return [{"position": enemy.global_position, "radius": .55 if enemy.get("kind") == "elite" else .36}]

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
		var regions := _enemy_hurt_regions(enemy, start.y)
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
	if entry.rifle:
		var previous_hits: int = entry.enemy_hits if enemy is Companion else entry.enemy_hits - 1
		var factor := maxf(0.0, 1.0 - float(entry.rifle_falloff) * previous_hits)
		if enemy is Companion: friendly_hit.emit(enemy, entry.damage * factor)
		else: rifle_hit.emit(enemy,entry.damage*factor,entry.direction*entry.knockback)
		if not active.has(entry):return
		if entry.piercing_round: rifle_pierce_spark.emit(position)
		impact.emit(position,"enemy");impact_element.emit(position,"enemy",entry.element);return
	var previous_hits: int = entry.enemy_hits if enemy is Companion else entry.enemy_hits - 1
	var damage: float = entry.damage * (entry.pierce_damage_multiplier if previous_hits > 0 else 1.0)
	if enemy is Companion:
		friendly_hit.emit(enemy, damage)
		if active.has(entry):
			impact.emit(position, "enemy")
			impact_element.emit(position, "enemy", entry.element)
		return
	if on_hit.is_valid(): on_hit.call(enemy, damage, entry.direction * entry.knockback)
	if not active.has(entry): return
	if not entry.sword_wave.is_empty(): sword_wave_hit.emit(enemy, damage, entry.direction * entry.knockback, entry.sword_wave)
	else: damage_hit.emit(enemy, damage, entry.direction * entry.knockback, entry.element)
	if not active.has(entry): return
	impact.emit(position, "enemy")
	impact_element.emit(position, "enemy", entry.element)

func _finish(entry: Dictionary, position: Vector3, reason: String, enemy, on_hit: Callable, enemies: Array = [], world: World3D = null) -> void:
	var generation := _clear_generation
	active.erase(entry)
	_remove_node(entry.node)
	var record := {"direction":entry.direction,"rifle_aimed":entry.rifle_aimed,"reason": reason, "position": position, "travelled": entry.travelled, "element": entry.element}
	if is_instance_valid(enemy): record["targetid"] = enemy.get_instance_id()
	var direct_hit := reason == "enemy" and is_instance_valid(enemy)
	var detonate: bool = entry.element == "fire" and entry.splash_radius > 0.0 and (direct_hit or entry.splash_on_stop)
	# Capture the primary's ground height and ID before direct damage can kill,
	# remove or reposition it. The blast stays at the swept contact location.
	var primary_id: int = enemy.get_instance_id() if direct_hit else 0
	var blast_ground_y: float = enemy.global_position.y if direct_hit else entry.splash_ground_y
	if detonate:
		record["splash_radius"] = entry.splash_radius
		record["splash_hitids"] = []
	if entry.pierce_after_exit > 0.0 or entry.sword_wave == "vacuum_wave":
		record["hitids"] = entry.hitids.duplicate()
		if entry.pierce_started:
			record["pierce_cutoff"] = entry.pierce_cutoff
			record["cutoff_position"] = entry.cutoff_position
			record["first_exit_position"] = entry.first_exit_position
	resolved.append(record)
	if resolved.size() > HISTORY_LIMIT: resolved.pop_front()
	if direct_hit and enemy is Companion:
		var factor := maxf(0.0, 1.0 - float(entry.rifle_falloff) * int(entry.enemy_hits)) if entry.rifle else 1.0
		friendly_hit.emit(enemy, entry.damage * factor)
	elif direct_hit:
		var chain_origin: Vector3 = enemy.global_position + Vector3.UP * .85
		if on_hit.is_valid(): on_hit.call(enemy, entry.damage, entry.direction * entry.knockback)
		if detonate and generation != _clear_generation: return
		if entry.pellet: rifle_pellet_hit.emit(enemy, entry.damage, entry.direction * entry.knockback, entry.scatter_volley)
		elif entry.rifle and entry.mark_round: rifle_mark_hit.emit(enemy, entry.damage, entry.direction * entry.knockback)
		elif entry.rifle and entry.armor_break_stacks > 0: rifle_armor_hit.emit(enemy, entry.damage, entry.direction * entry.knockback, entry.armor_break_stacks)
		elif entry.rifle:rifle_hit.emit(enemy,entry.damage,entry.direction*entry.knockback)
		elif entry.companion_shot: companion_hit.emit(enemy, entry.damage, entry.direction * entry.knockback, entry.element, entry.bolt)
		elif entry.bolt:bolt_hit.emit(enemy, entry.damage, entry.direction * entry.knockback)
		elif not entry.sword_wave.is_empty(): sword_wave_hit.emit(enemy, entry.damage, entry.direction * entry.knockback, entry.sword_wave)
		elif entry.ice_volley: ice_volley_hit.emit(enemy, entry.damage, entry.direction * entry.knockback)
		else:damage_hit.emit(enemy, entry.damage, entry.direction * entry.knockback, entry.element)
		if generation == _clear_generation and not entry.chain_damage.is_empty():
			_apply_lightning_chain(entry, chain_origin, primary_id, enemies, world, on_hit, generation)
		if detonate and generation != _clear_generation: return
	if detonate:
		var blast_center: Vector3 = position - entry.direction * .04 if reason == "cover" else position
		_apply_splash(entry, blast_center, blast_ground_y, primary_id, enemies, world, on_hit, record.splash_hitids, generation)
		if generation != _clear_generation: return
		area_visual.emit(blast_center, blast_ground_y, entry.splash_radius, entry.element, entry.charged_fire_art)
		area_impact.emit(blast_center, entry.splash_radius, entry.element)
		if generation != _clear_generation: return
	if generation!=_clear_generation:return
	if entry.pellet:
		if reason in ["enemy", "cover"]: rifle_pellet_impact.emit(position, entry.tracer_color)
		return
	if entry.get("ground_fire",false):
		fire_patch.emit(Vector3(position.x,0,position.z)-entry.direction*.05)
		if generation!=_clear_generation:return
	if reason not in ["hit_limit", "split"]:
		if entry.ice_volley and reason in ["enemy", "cover"]: ice_volley_contact.emit(position)
		if not entry.chain_damage.is_empty() and reason in ["enemy", "cover"]: chain_lightning_contact.emit(position)
		impact.emit(position, reason)
		impact_element.emit(position, reason, entry.element)

func _apply_lightning_chain(entry: Dictionary, origin: Vector3, primary_id: int, enemies: Array, world: World3D, on_hit: Callable, generation: int) -> void:
	var visited: Array[int] = [primary_id]
	for damage: float in entry.chain_damage:
		var closest: Node3D
		var destination := origin
		var best_distance: float = entry.chain_radius * entry.chain_radius
		for enemy in enemies:
			if not is_instance_valid(enemy) or not enemy is Node3D or enemy.get("dead") == true: continue
			if enemy is Companion: continue
			if enemy.get_instance_id() in visited: continue
			var point: Vector3 = enemy.global_position + Vector3.UP * .85
			var distance := origin.distance_squared_to(point)
			if distance > best_distance or (closest != null and distance == best_distance): continue
			if world != null and not origin.is_equal_approx(point):
				var ray := PhysicsRayQueryParameters3D.create(origin, point, 1)
				ray.hit_from_inside = true
				if not world.direct_space_state.intersect_ray(ray).is_empty(): continue
			closest = enemy
			destination = point
			best_distance = distance
		if closest == null: return
		visited.append(closest.get_instance_id())
		lightning_jump.emit(origin, destination)
		if generation != _clear_generation: return
		if on_hit.is_valid(): on_hit.call(closest, damage, Vector3.ZERO)
		if generation != _clear_generation: return
		damage_hit.emit(closest, damage, Vector3.ZERO, "lightning")
		if generation != _clear_generation: return
		origin = destination

func _apply_splash(entry: Dictionary, position: Vector3, ground_y: float, primary_id: int, enemies: Array, world: World3D, on_hit: Callable, hitids: Array, generation: int) -> void:
	var ray_origin := Vector3(position.x, ground_y + 0.68, position.z)
	for enemy in enemies.duplicate():
		# Clear may run synchronously in either damage consumer. Abandon the old
		# blast even if that consumer immediately starts a new projectile session.
		if generation != _clear_generation: return
		if not is_instance_valid(enemy) or not enemy is Node3D: continue
		var target_id: int = enemy.get_instance_id()
		if target_id == primary_id or target_id in entry.hitids or target_id in hitids or enemy.get("dead") == true: continue
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
		if enemy is Companion:
			friendly_hit.emit(enemy, entry.splash_damage)
			continue
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
		if entry.sword_wave == "vacuum_wave": entry.node.configure_ground(entry.wake_ground_y)
		entry.node.update_visual(camera, entry.direction, entry.age)
