extends CharacterBody3D

const Hero = preload("res://scripts/hero_visual.gd")
const Motion = preload("res://scripts/weapon_motion.gd")
const Dash = preload("res://scripts/dash_visual.gd")
const Rewards = preload("res://scripts/combat_rewards.gd")
const StaminaRules = preload("res://scripts/stamina_rules.gd")
const BaseStats = preload("res://data/player_base_stats.tres")
const Attacks = preload("res://scripts/enemy_attacks.gd")
const Anatomy = preload("res://scripts/anatomy_state.gd")
const LOW_HEALTH_FRACTION := .25
const RETREAT_DURATION := 4.0
const FOLLOW_RADIUS := 10.0
const REVIVE_RANGE := 1.6
const REVIVE_FRACTION := .30
const RANGED_REACH := 7.5
const DODGE_LOOKAHEAD := .27
const DASH_SCAN_INTERVAL := .06

var avatar: Hero
var motion = Motion.new()
var stats = BaseStats.duplicate(true)
var health := BaseStats.value("max_health")
var downed := false
var revive_marker: Label3D
var target: Node3D
var target_refresh_left := 0.0
var melee_reach := 2.1
var family := "sword"
var ranged := false
var slot := 0
var facing := Vector3.RIGHT
var retreat_left := 0.0
var cooldown := 0.0
var hurt_left := 0.0
var attack_target: Node3D
var attacks_committed := 0
var dash_left := 0.0
var dash_recharge := 0.0
var dash_scan_left := 0.0
var dash_direction := Vector3.ZERO
var stamina := BaseStats.value("max_stamina")
var mana := BaseStats.value("max_mana")
var energy := StaminaRules.new()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .30
	capsule.height = 1.35
	collider.shape = capsule
	collider.position.y = .68
	add_child(collider)
	avatar = Hero.new()
	add_child(avatar)
	avatar.enable_cutout()
	avatar.anatomy = Anatomy.new()
	revive_marker = Label3D.new()
	revive_marker.position.y = 2.4
	revive_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	revive_marker.font_size = 31
	revive_marker.pixel_size = .008
	revive_marker.outline_size = 8
	revive_marker.modulate = Color("#ffd49b")
	revive_marker.no_depth_test = true
	revive_marker.visible = false
	add_child(revive_marker)

func configure(recruit: Dictionary, index: int) -> void:
	slot = index
	stats.attributes = recruit.get("attributes", {}).duplicate()
	health = max_health()
	stamina = stats.value("max_stamina")
	mana = stats.value("max_mana")
	avatar.anatomy.bind_max_hp(health)
	family = recruit.get("weapon", "sword")
	ranged = family in ["pistol", "rifle", "staff", "bow", "crossbow"]
	avatar.set_weapon_family(family)
	motion.set_family(family)
	if not ranged:
		melee_reach = clampf(float(motion.definition(0).get("reach", 2.1)), 1.55, 2.35)
	var look: Dictionary = recruit.get("look", {})
	if not look.is_empty(): avatar.cutout.apply_look(look)

func place(at: Vector3) -> void:
	position = at
	velocity = Vector3.ZERO
	dash_left = 0.0
	dash_scan_left = 0.0
	motion.reset()
	attack_target = null
	retreat_left = 0.0
	target = null
	target_refresh_left = 0.0

func recalling() -> bool:
	return not downed and retreat_left > 0.0

func recall() -> void:
	if downed: return
	retreat_left = RETREAT_DURATION
	motion.reset()
	attack_target = null

func max_health() -> float:
	return stats.value("max_health")

func receive_hit(amount: float) -> void:
	if downed or hurt_left > 0.0 or dash_left > Dash.DURATION - Rewards.DODGE_IFRAMES or amount <= 0.0: return
	var low_health := max_health() * LOW_HEALTH_FRACTION
	var was_above_low_health := health > low_health
	health = maxf(0.0, health - amount)
	hurt_left = .38
	if health <= 0.0:
		downed = true
		dash_left = 0.0
		velocity = Vector3.ZERO
		motion.reset()
	elif was_above_low_health and health <= low_health:
		recall()

func receive_forest_poison(amount: float, integrity_loss: float) -> void:
	var previous := health
	receive_hit(amount)
	if health < previous: avatar.anatomy.reduce_all_integrity(integrity_loss)


func can_revive_from(origin: Vector3) -> bool:
	return downed and origin.distance_squared_to(global_position) <= REVIVE_RANGE * REVIVE_RANGE and _line_clear(origin)

func revive() -> void:
	if not downed: return
	downed = false
	health = max_health() * REVIVE_FRACTION
	hurt_left = .75
	retreat_left = .75
	cooldown = .35
	target = null
	target_refresh_left = 0.0

func tick(delta: float, game) -> void:
	hurt_left = maxf(0.0, hurt_left - delta)
	if downed: return
	retreat_left = maxf(0.0, retreat_left - delta)
	cooldown = maxf(0.0, cooldown - delta)
	dash_recharge = maxf(0.0, dash_recharge - delta)
	stamina = energy.recover(stamina, delta, stats, dash_left > 0.0, false)
	if dash_left <= 0.0 and dash_recharge <= 0.0 and stamina >= Rewards.DODGE_COST:
		dash_scan_left -= delta
		if dash_scan_left <= 0.0:
			dash_scan_left = DASH_SCAN_INTERVAL
			_try_dodge(game)
	if dash_left > 0.0:
		_move(dash_direction * Rewards.DODGE_SPEED, minf(delta, dash_left), game)
		dash_left = maxf(0.0, dash_left - delta)
		return
	if motion.busy:
		var step: Dictionary = motion.advance(delta)
		if step.get("projectile_ready", false) or (not ranged and step.get("damage_ready", step.get("entered_active", false))):
			_commit_attack(game)
		var step_toward := Vector3.ZERO
		if not ranged and motion.busy and motion.elapsed < float(motion.definition(0).get("windup", 0.0)) and is_instance_valid(attack_target) and not attack_target.dead:
			var offset := attack_target.global_position - global_position
			offset.y = 0.0
			if offset.length_squared() > melee_reach * melee_reach * .65 and offset.dot(facing) > 0.0:
				step_toward = offset.normalized() * 2.4
		_move(step_toward, delta, game)
		return

	var leader: Vector3 = game.player.global_position
	var side: float = -1.0 if slot == 0 else 1.0
	var across := Vector3(-game.aim.z, 0, game.aim.x)
	var home: Vector3 = leader - game.aim * .9 + across * side * (1.8 if recalling() else (3.3 if ranged else 1.3))
	var ground_order: bool = not recalling() and game.party_mark_left > 0.0
	var marked: Node3D = game.party_mark_target
	if is_instance_valid(marked) and marked.dead: marked = null
	if ground_order:
		home = game.party_mark_point + Vector3.RIGHT * side * .65
		var toward := home - global_position
		toward.y = 0.0
		if toward.length_squared() > 1.0:
			facing = toward.normalized()
			_move(game.arena.steer_around_cover(global_position, facing * 5.7, toward.length()), delta, game)
			return
	var can_engage := not recalling() and (marked != null or ground_order or leader.distance_squared_to(global_position) < FOLLOW_RADIUS * FOLLOW_RADIUS)
	target_refresh_left -= delta
	if can_engage:
		if marked != null:
			target = marked
			target_refresh_left = 0.0
		elif target_refresh_left <= 0.0:
			target = _choose_target(game, home if ground_order else leader)
			target_refresh_left = .12

	var move := home - global_position
	if can_engage and is_instance_valid(target) and not target.dead:
		var offset := target.global_position - global_position
		offset.y = 0
		var distance := offset.length()
		facing = offset.normalized() if distance > .02 else facing
		var in_range := distance <= (RANGED_REACH if ranged else melee_reach)
		if in_range and _line_clear(target.global_position):
			move = Vector3.ZERO
			if cooldown <= 0.0:
				attack_target = target
				cooldown = .98 if ranged else .82
				if not motion.start(0, atan2(facing.z, facing.x)): _commit_attack(game)
			elif ranged and distance < 2.4:
				move = -facing + across * side * .5
		elif ground_order:
			move = home - global_position
		elif ranged and in_range:
			move = across * side + facing * .6
		else:
			move = offset
	elif move.length_squared() > .45:
		facing = Vector3(move.x, 0, move.z).normalized()
	if move.length_squared() > .18:
		var speed := 5.7 if recalling() or not can_engage else (3.7 if ranged else 4.8)
		move = game.arena.steer_around_cover(global_position, move.normalized() * speed, move.length())
	else:
		move = Vector3.ZERO
	_move(move, delta, game)

func _try_dodge(game) -> void:
	var imminent: Array[Node3D] = []
	var threat: Node3D
	var earliest := INF
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.state != "windup" or enemy.attack_data.is_empty(): continue
		if enemy.telegraph_left > DODGE_LOOKAHEAD or global_position.distance_squared_to(enemy.global_position) > 144.0: continue
		imminent.append(enemy)
		if enemy.telegraph_left >= earliest or not _in_attack_zone(enemy, global_position) or not _line_clear(enemy.global_position): continue
		threat = enemy
		earliest = enemy.telegraph_left
	if threat == null: return

	var away := global_position - threat.global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > .001 else -facing
	for angle: float in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
		var direction := away.rotated(Vector3.UP, deg_to_rad(angle))
		var travel := direction * Rewards.DODGE_SPEED * Dash.DURATION
		var destination := global_position + travel
		if imminent.any(func(enemy: Node3D) -> bool: return _in_attack_zone(enemy, destination)): continue
		if test_move(global_transform, travel, null, .001): continue
		dash_left = Dash.DURATION
		dash_recharge = Rewards.DODGE_RECHARGE
		dash_direction = direction
		stamina -= Rewards.DODGE_COST
		motion.reset()
		attack_target = null
		target_refresh_left = 0.0
		cooldown = minf(cooldown, .18)
		return

func _in_attack_zone(enemy, point: Vector3) -> bool:
	if enemy.has_method("windup_threatens"): return enemy.windup_threatens(point)
	if enemy.attack_data.get("projectiles", 0) == 0 and enemy.has_method("threatens"):
		return enemy.threatens(point)
	return Attacks.contains(enemy.global_position, enemy.attack_angle, point, enemy.attack_data)

func _choose_target(game, leader: Vector3) -> Node3D:
	var best: Node3D
	var best_score := INF
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var leader_distance := leader.distance_squared_to(enemy.global_position)
		if leader_distance > FOLLOW_RADIUS * FOLLOW_RADIUS: continue
		var score := global_position.distance_squared_to(enemy.global_position) + leader_distance * .15
		if score >= best_score: continue
		if not _line_clear(enemy.global_position): score += 24.0
		if score < best_score:
			best = enemy
			best_score = score
	return best

func _move(motion_: Vector3, delta: float, game) -> void:
	velocity = motion_
	if dash_left <= 0.0 and game.encounter_mode == "dungeon" and is_instance_valid(game.arena.hazards):
		var terrain = game.arena.hazards
		velocity = terrain.companion_motion(global_position, velocity) * terrain.speed_scale(global_position)
	velocity.y = -2.0
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))

func _commit_attack(game) -> void:
	if not is_instance_valid(attack_target) or attack_target.dead or not _line_clear(attack_target.global_position): return
	var offset := attack_target.global_position - global_position
	offset.y = 0
	if ranged:
		var direction := offset.normalized() if offset.length_squared() > .001 else facing
		var origin := global_position + Vector3.UP * .83
		var shot := {"damage": 13.0, "element": "fire" if family == "staff" else "physical",
			"projectile_speed": 19.0, "projectile_range": 8.0, "projectile_radius": .12,
			"knockback": .45, "launch_origin": origin}
		if family in ["bow", "crossbow"]: shot.projectile_visual = "arrow" if family == "bow" else "bolt"
		if game.staff_flight.spawn_fireball(origin + direction * .48, direction, shot, game.camera):
			attacks_committed += 1
			game.audio.play("fire_cast" if family == "staff" else ("equip" if family in ["bow","crossbow"] else "gun"))
	elif offset.length() <= melee_reach + .2 and offset.dot(facing) >= -.08:
		attacks_committed += 1
		game.enemy_hit(attack_target, 13.0, facing * .65, "physical")

func _line_clear(to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * .7, to + Vector3.UP * .7, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func present(camera: Camera3D, delta: float, revive_available: bool) -> void:
	var sample: Dictionary = motion.sample()
	var dodge := Dash.sample(dash_left, facing, dash_direction, camera)
	avatar.update_pose(camera, facing, Vector2(velocity.x, velocity.z).length_squared() > .1,
		sample, 2.1, hurt_left, dash_left, delta, downed, dodge)
	avatar.set_equipment_visible(not downed)
	avatar.update_cutout(null)
	revive_marker.visible = downed
	if downed: revive_marker.text = "[E ค้าง] ชุบ" if revive_available else "ล้มอยู่"
