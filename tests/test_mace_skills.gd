extends SceneTree
const MaceSkills = preload("res://scripts/mace_skill_motion.gd")

var game
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok: return
	failures += 1
	printerr("FAIL: ", description)

func fresh() -> void:
	game.start_run(true)
	game.set_weapon_family("mace")
	game.clear_actors()
	game.test_aim = Vector3.RIGHT
	game.stats.flat.critical_chance = -1.0

func dummy(x: float, z: float):
	return game.spawn_enemy("dummy", Vector3(x, .03, z))

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func release_key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	game._input(event)

func check_skill_categories() -> void:
	var ground_impacts := ["mace_impact", "mace_double_impact", "mace_gather", "mace_aftershock", "mace_earth_wave"]
	for id: String in MaceSkills.SKILLS:
		var info: Dictionary = MaceSkills.SKILLS[id]
		var tags: Array = info.get("tags", [])
		var is_ground_skill := id in ground_impacts
		check((&"area" in tags) == is_ground_skill, "%s classifies the whole skill as area only for a ground skill" % id)
		check((&"ground_impact" in tags) == (id in ground_impacts), "%s separates a ground impact from area coverage" % id)
		check((&"ground_area" in tags) == is_ground_skill, "%s identifies the primary ground effect" % id)
		var impact_tags: Array = info.get("impact_tags", [])
		check((&"area" in impact_tags) == (id == "mace_fissure"), "%s reserves secondary area for the fireball explosion" % id)
		var labels: String = game.sword_skill_ui.catalog_details[id].text
		check(labels.contains("\nพื้นที่ •") == is_ground_skill, "%s shows its primary area category correctly" % id)
		check(labels.contains("\nระเบิดลูกไฟ • พื้นที่") == (id == "mace_fissure"), "%s shows an area explosion separately" % id)
	check(&"ground_impact" in game.motion.definition(2).get("tags", []), "the basic mace finisher counts as a ground impact")

func check_armor_counter() -> void:
	fresh()
	if not game.loadout.equip_skill(2, "mace_armor_counter"):
		check(false, "the final level 20 mace skill can be equipped")
		return
	var front = dummy(1.4, 0)
	var side = dummy(1.45, .7)
	var rear = dummy(-1.3, 0)
	game._mace_ground.place_rift(Vector3.ZERO, 2.8)
	key(KEY_3)
	game.tick(.49)
	check(game.hits == 0 and front.mace_armor.stacks == 0, "the first half second is a stance without damage")
	game.tick(.23)
	check(is_equal_approx(front.max_health - front.health, 78.0) and front.mace_armor.stacks == 2 and side.mace_armor.stacks == 2 and rear.mace_armor.stacks == 0, "one forward sweep deals damage before adding two stacks")
	var normal_flash: Sprite3D = game.fx.mace_sweep_flash
	check(is_instance_valid(normal_flash) and normal_flash.visible and normal_flash.material_override is ShaderMaterial, "normal armor sweep carries the cold painted weapon-head streak")
	var normal_width := normal_flash.pixel_size if is_instance_valid(normal_flash) else 0.0
	check(game._mace_ground.rift.get("charges") == 3, "an armor-opening sweep does not trigger the ground rift")
	fresh()
	var attacker = dummy(1.5, 0)
	var bystander = dummy(1.45, .7)
	attacker.apply_mace_break()
	game.stats.flat.attack_speed = .50
	key(KEY_3)
	game.tick(.48)
	var player_hp: float = game.health
	var before_parries: int = game.readiness.parries
	game.incoming_attack(12.0, attacker.position, true, attacker)
	check(game.health == player_hp and game.readiness.parries == before_parries + 1 and attacker.mace_armor.stacks == 1, "the skill parries during the stance and waits for the hit to apply stacks")
	game.tick(.14)
	var counter_flash: Sprite3D = game.fx.mace_sweep_flash
	check(is_instance_valid(counter_flash) and counter_flash.visible and counter_flash.material_override == null and counter_flash.pixel_size > normal_width, "a successful parry produces the wider gold weapon-head streak")
	game.tick(.10)
	check(attacker.mace_armor.broken() and bystander.mace_armor.stacks == 2 and game.hits == 2, "only the parried attacker is filled to the armor cap")
	check(game.status_icons.icons_for(attacker)[0][1] == "5" and attacker.mace_armor.remaining > 9.8, "armor cap uses the existing stack icon and ten second duration")
	fresh()
	attacker = dummy(1.5, 0)
	key(KEY_3)
	game.tick(.51)
	before_parries = game.readiness.parries
	game.incoming_attack(12.0, attacker.position, true, attacker)
	game.tick(.24)
	check(game.readiness.parries == before_parries and attacker.mace_armor.stacks == 2, "a late attack cannot turn the sweep into a parry")
	fresh()
	var sparring_enemy = game.spawn_enemy("melee", Vector3(1.25, .03, 0))
	sparring_enemy.max_health = 400.0
	sparring_enemy.health = 400.0
	for frame in range(180):
		game.tick(1.0 / 120.0)
		if sparring_enemy.state == "windup" and sparring_enemy.telegraph_left <= .35: break
	key(KEY_3)
	game.tick(.43)
	check(sparring_enemy.state == "parried", "the normal enemy attack path enters the skill parry (state %s, tell %s, aim %s, position %s, elapsed %s)" % [sparring_enemy.state, sparring_enemy.telegraph_left, game.aim, sparring_enemy.position, game.motion.elapsed])
	game.tick(.27)
	check(sparring_enemy.mace_armor.broken(), "the follow-up opens the real sparring enemy's armor to its cap")

func check_sweep_pose() -> void:
	var motion := MaceSkills.new()
	motion.configure("mace_sweep", motion.sample())
	motion.start(0, 0.0)
	var first := motion.definition(0)
	motion.advance(first.windup + first.active * .1)
	var first_start: float = motion.sample().angle
	motion.advance(first.active * .8)
	check(motion.sample().angle > first_start, "first sweep travels across the front")
	motion.advance(1.0)
	if motion.definition(1).is_empty():
		check(false, "the sweep has a second strike")
		return
	motion.start(1, 0.0)
	var second := motion.definition(1)
	var loop := motion.advance(second.windup * .5)
	var raised := motion.sample()
	check(raised.grip_height > 1.3 and raised.radius < .32 and not loop.damage_ready, "the return curls the raised arm without damage")
	check(raised.get("body_spin", 0.0) > 2.0 and raised.angle > first_start + float(first.arc), "body and weapon turn forward through the raised return")
	motion.advance(second.windup * .5 + second.active * .1)
	var second_start: float = motion.sample().angle
	var second_body_start: float = motion.sample().get("body_spin", 0.0)
	motion.advance(second.active * .8)
	check(is_equal_approx(second_start, first_start) and motion.sample().angle > second_start, "both sweeps start on the same side and travel in the same direction")
	check(motion.sample().get("body_spin", 0.0) > second_body_start, "the body keeps turning through the second sweep")

func run() -> void:
	check_sweep_pose()
	game = load("res://scenes/game.tscn").instantiate()
	game.loadout.save_path = ""
	root.add_child(game)
	game.set_physics_process(false)
	fresh()
	check_skill_categories()
	var front = dummy(3.4, 0.35)
	var beside_head = dummy(2.8, 1.2)
	var beside_player = dummy(0.1, 1.4)
	var starting_mana: float = game.mana
	key(KEY_1)
	check(game.active_skill_id == "mace_impact" and game.mana == starting_mana - 18, "key 1 spends 18 mana for impact")
	game.sword_skill_ui.refresh()
	check(game.sword_skill_ui.slot_buttons[0].text.contains("ก้าวกระแทก") and game.sword_skill_ui.slot_buttons[2].visible, "mace displays its three equipped slots")
	game.tick(.20)
	check(game.hits == 0 and game.fx.mace_impacts.is_empty(), "the windup has no damage or ground stamp")
	game.tick(.23)
	var head: Vector3 = game.avatar.get_blade_points().tip
	var impact = game.fx.mace_impacts.front() if not game.fx.mace_impacts.is_empty() else null
	check(impact != null and Vector2(impact.position.x - head.x, impact.position.z - head.z).length() < .03 and absf(head.y - game.player.position.y) < .03, "the painted shockwave sits under the rendered mace head at contact")
	check(impact != null and impact.scale.x < .4, "the painted ring starts compact")
	game.tick(.11)
	check(impact != null and is_equal_approx(impact.scale.x, 1.0) and is_equal_approx(impact.pixel_size * impact.ART_RADIUS, 1.35), "the painted ring expands to the actual hit radius")
	check(front.max_health - front.health == 50 and beside_head.max_health - beside_head.health == 50, "circle deals 50 around the head's landing point")
	check(beside_player.health == beside_player.max_health and game.hits == 2, "circle is centered ahead and hits each enemy once")
	check(front.mace_armor.stacks == 1 and beside_head.mace_armor.stacks == 1 and beside_player.mace_armor.stacks == 0, "the impact opens one armor stack on targets it damages")
	game.tick(.24)
	check(game.fx.mace_impacts.is_empty(), "the painted shockwave expires after the impact")
	fresh()
	var left = dummy(1.2, -1.6)
	var right = dummy(1.2, 1.6)
	var behind = dummy(-1.5, 0)
	var outside = dummy(.05, 2.5)
	key(KEY_2)
	check(game.active_skill_id == "mace_sweep" and game.mana == starting_mana - 20, "key 2 spends 20 mana for sweep")
	game.tick(.50)
	check(left.max_health - left.health == 18 and right.max_health - right.health == 18, "first fan deals 18 on both sides of the front")
	check(behind.health == behind.max_health and outside.health == outside.max_health and game.hits == 2, "fan excludes rear and outside targets")
	game.tick(.50)
	check(game.hits == 4 and left.max_health - left.health == 40 and right.max_health - right.health == 40, "second fan adds 22 damage to both targets")
	check(behind.health == behind.max_health and outside.health == outside.max_health, "the arm loop and both strikes leave rear and outside targets untouched")
	check(is_equal_approx(game.mana, starting_mana - 20 + .5), "both sweeps share one mana payment")
	game.tick(.4)
	var mana_after_sweep: float = game.mana
	key(KEY_2)
	check(not game.skill_active and game.mana == mana_after_sweep, "cooldown blocks the repeat cast without spending mana")
	fresh()
	game.mana = 17.99
	key(KEY_1)
	check(not game.skill_active and game.mana == 17.99, "insufficient mana rejects mace impact")
	fresh()
	dummy(3.4, 0)
	key(KEY_1)
	game.tick(.10)
	check(game.request_dodge(Vector3.LEFT), "dodge can cancel the mace windup")
	game.tick(.8)
	check(game.hits == 0, "cancelled impact cannot hit")
	fresh()
	check(game.loadout.equip_skill(0, "mace_double_impact"), "double slam can be equipped")
	var first_spot = dummy(3.7, 0)
	var second_spot = dummy(3.7, 1.57)
	key(KEY_1)
	game.tick(.48)
	check(first_spot.max_health - first_spot.health == 34 and second_spot.health == second_spot.max_health, "first slam hits only the first spot")
	game.tick(.33)
	check(game.motion.stage == 1 and game.motion.sample().get("body_spin", 0) > 2.0 and game.hits == 1, "the automatic follow-up turns the body before contact")
	game.tick(.42)
	check(game.hits == 3 and first_spot.max_health - first_spot.health == 76 and second_spot.max_health - second_spot.health == 42, "the second slam lands automatically with a wider circle")
	check(is_equal_approx(game.mana, starting_mana - 28 + 1.23 * .5), "the follow-up shares the initial mana payment")
	fresh()
	var steered_target = dummy(3.7, 2.25)
	key(KEY_1)
	game.tick(.48)
	check(game.hits == 0 and is_zero_approx(game.motion.aim_angle), "first slam keeps its starting aim")
	game.test_aim = Vector3.BACK
	game.tick(.47)
	check(is_equal_approx(game.motion.aim_angle, deg_to_rad(25.0)), "second windup steers toward the cursor but caps at 25 degrees")
	game.test_aim = Vector3.FORWARD
	game.tick(.28)
	check(game.hits == 1 and steered_target.max_health - steered_target.health == 42, "contact stays on the steered line once the downswing starts")
	fresh()
	check(game.loadout.equip_skill(1, "mace_gather"), "pull can be equipped")
	var inward = dummy(3.4, 1.0)
	var out_of_range = dummy(-1, 0)
	key(KEY_2)
	release_key(KEY_2)
	game.tick(.56)
	var pull_center := Vector2(2.55, 0)
	check(game.hits == 1 and inward.max_health - inward.health == 24 and Vector2(inward.position.x, inward.position.z).distance_to(pull_center) < 1.25, "plant deals damage and begins drawing the target inward")
	check(out_of_range.health == out_of_range.max_health and out_of_range.knockback.is_zero_approx(), "targets outside the circle are untouched")
	game.tick(.25)
	check(Vector2(inward.position.x, inward.position.z).distance_to(pull_center) <= .40, "the affected target gathers at the center")
	for tier in range(1, 4):
		fresh()
		var targets: Array = []
		for distance in [1.10, 1.60, 2.35, 2.70]:
			targets.append(dummy(2.55, distance))
		key(KEY_2)
		var hold: float = [.10, .50, 1.10][tier - 1]
		game.tick(hold)
		check(game.hits == 0, "holding the skill is harmless at tier %d" % tier)
		check(game.mace_charge_grade(1) == tier, "HUD reports charge tier %d" % tier)
		var markers: Array = game._mace_ground.landing_markers
		var radius: float = MaceSkills.GATHER_RADII[tier - 1]
		check(markers.size() == 2 and is_equal_approx(markers[0].mesh.get_aabb().size.x, radius * 2.0) and is_equal_approx(markers[0].mesh.get_aabb().size.z, radius * 2.0), "gather previews a full circle at the tier %d radius" % tier)
		release_key(KEY_1)
		game.tick(.05)
		check(game.hits == 0, "another key cannot release the charge")
		release_key(KEY_2)
		check(game._mace_ground.landing_markers.is_empty(), "gather preview clears on release")
		game.tick(.7)
		check(game.hits == tier, "charge tier %d uses its own hit radius" % tier)
		check(is_equal_approx(game.mana, starting_mana - 24 + (hold + .75) * .5), "all charge tiers pay once")
		var fraction: float = [.05, .10, .20][tier - 1]
		for i in range(targets.size()):
			check(targets[i].get("movement_slow") == (fraction if i < tier else 0.0), "tier %d applies the slow only inside its circle" % tier)
		var remaining: float = float(targets[0].get("movement_slow_remaining")) if targets[0].get("movement_slow_remaining") != null else 0.0
		check(remaining > 4.0 and remaining <= 5.0, "slow begins at impact and lasts five seconds")
		for index in tier:
			var position: Vector3 = targets[index].position
			check(Vector2(position.x, position.z).distance_to(pull_center) <= .40, "tier %d clusters each affected target around the impact" % tier)
		game.tick(5.0)
		check(targets[0].get("movement_slow") == 0.0, "movement slow expires")
	fresh()
	dummy(2.55, .6)
	game.sword_skill_ui.slot_buttons[1].button_down.emit()
	game.tick(.50)
	check(game.mace_charge_grade(1) == 2 and game.hits == 0, "holding the on-screen button charges without attacking")
	game.sword_skill_ui.slot_buttons[1].button_up.emit()
	game.tick(.65)
	check(game.hits == 1, "releasing the on-screen button casts")
	fresh()
	key(KEY_2)
	check(game.mana == starting_mana - 24, "mana is paid when the charge begins")
	game.move_input = Vector2.RIGHT
	game.test_aim = Vector3.BACK
	var walking_start: Vector3 = game.player.position
	var physics_step := 1.0 / Engine.physics_ticks_per_second
	for frame in range(Engine.physics_ticks_per_second / 2):
		await physics_frame
		game.tick(physics_step)
	var after_walk: Vector3 = game.player.position
	var walked := Vector2(after_walk.x - walking_start.x, after_walk.z - walking_start.z).length()
	check(walked > .55 and walked < 1.05 and game.mace_charge_grade(1) == 2 and game.hits == 0, "charge walks slowly and keeps building")
	check(game.avatar.body.animation == "walk", "charging while moving uses walking steps")
	check(is_equal_approx(game.motion.aim_angle, PI * .5), "the charged stance turns while walking")
	if not game._mace_ground.landing_markers.is_empty():
		var preview: Vector3 = game._mace_ground.landing_markers[0].global_position
		check(Vector2(preview.x - after_walk.x, preview.z - after_walk.z - 2.55).length() < .02, "gather preview tracks the current player position and locked heading")
	else:
		check(false, "gather previews while walking and turning")
	var turned_target = dummy(after_walk.x, after_walk.z + 2.55)
	var original_target = dummy(after_walk.x + 2.55, after_walk.z)
	release_key(KEY_2)
	check(is_equal_approx(game.mana, starting_mana - 24 + .25), "release takes no second payment")
	game.test_aim = Vector3.RIGHT
	for frame in range(Engine.physics_ticks_per_second / 6):
		await physics_frame
		game.tick(physics_step)
	check(Vector2(game.player.position.x - after_walk.x, game.player.position.z - after_walk.z).length() < .03, "walking stops during the released slam")
	game.move_input = Vector2.ZERO
	game.tick(.15)
	check(turned_target.max_health - turned_target.health == 24 and original_target.health == original_target.max_health, "release locks the final facing for the pull (turned %s, original %s, hits %s)" % [turned_target.max_health - turned_target.health, original_target.max_health - original_target.health, game.hits])
	fresh()
	key(KEY_2)
	game.tick(.04)
	check(game.request_dodge(Vector3.LEFT), "dodge cancels the gather charge")
	release_key(KEY_2)
	check(is_equal_approx(game.mana, starting_mana - 24 + .02) and not game.skill_active and game.hits == 0 and game._mace_ground.landing_markers.is_empty(), "cancelled windup clears the preview without refunding the cast")
	fresh()
	var movable = game.spawn_enemy("melee", Vector3(3.4, .03, 1.0))
	movable.stagger = 5.0
	var center := Vector3(2.55, .03, 0)
	var initial_distance: float = movable.position.distance_to(center)
	key(KEY_2)
	release_key(KEY_2)
	for frame in range(39):
		await physics_frame
		game.tick(1.0 / 60.0)
	check(movable.position.distance_to(center) < initial_distance - .25, "the pull actually moves a live enemy toward the impact")
	fresh()
	var walker = game.spawn_enemy("melee", Vector3(5.0, .03, 0))
	await physics_frame
	game.tick(physics_step)
	var normal_speed: float = Vector2(walker.velocity.x, walker.velocity.z).length()
	walker.apply_movement_slow(.20, 5.0)
	await physics_frame
	game.tick(physics_step)
	check(normal_speed > 0 and is_equal_approx(Vector2(walker.velocity.x, walker.velocity.z).length(), normal_speed * .80), "slow reduces actual walking velocity by 20 percent")
	var time_left: float = walker.movement_slow_remaining
	game.toggle_pause()
	game.tick(1.0)
	check(walker.movement_slow_remaining == time_left, "paused time does not consume the slow")
	game.toggle_pause()
	for kind in ["fisherman", "brinehound"]:
		fresh()
		var start := Vector3(5.0, .03, 0)
		var coastal = game.spawn_enemy(kind, start)
		coastal.engaged = true
		coastal.cooldown = 1.0
		await physics_frame
		coastal.tick(physics_step, game)
		var normal_distance: float = start.distance_to(coastal.position)
		coastal.position = start
		coastal.apply_movement_slow(.20, 5.0)
		await physics_frame
		coastal.tick(physics_step, game)
		check(normal_distance > 0.0 and absf(start.distance_to(coastal.position) - normal_distance * .80) < .0001, "%s chase slows by 20 percent" % kind)
	fresh()
	check(game.loadout.equip_skill(0, "mace_fissure"), "level 15 fissure can be equipped")
	var landing_target = dummy(5.5, 2.5)
	landing_target.armor_rating = 200.0
	var landing_points: Array[Vector3] = []
	var ember_contacts: Array[Vector3] = []
	var track_landing := func(point: Vector3, direct: Node3D, _hit_ids: Dictionary) -> void:
		if direct != null: return
		landing_points.append(point)
		var flash: Node = game.fx.mace_impacts.back() if not game.fx.mace_impacts.is_empty() else null
		if flash != null and flash.name.begins_with("MaceEmberContact"):
			ember_contacts.append(flash.position)
	game.mace_fire_lobs.detonated.connect(track_landing)
	key(KEY_1)
	check(game.mana == starting_mana - 29, "fissure pays once when started")
	game.tick(.49)
	check(game.get("mace_fire_buff_left") != null and game.mace_fire_buff_left > 4.5 and game.hits == 0, "fissure grants a five-second attack buff")
	check("ember" in game.ui.status_view.shown_effects, "ember buff has a player status icon")
	game.tick(.20)
	check(game.request_attack() and game.motion.stage == 0, "first buffed attack lifts from side one")
	game.tick(.21)
	var floor_pose: Dictionary = game.motion.sample()
	var floor_head_y: float = floor_pose.grip_height + sin(floor_pose.pitch) * floor_pose.blade_length
	check(absf(floor_head_y) < .035 and game.mace_fire_lobs.shots_fired == 0, "the first lift scrapes along the ground before releasing")
	check(game.fx.mace_impacts.size() == 1 and game.fx.mace_impacts[0].texture.resource_path.ends_with("mace_ember_soil.png"), "the scrape lifts painted burning dirt before the projectile")
	game.tick(.19)
	if game.get("mace_fire_lobs") != null:
		check(game.mace_fire_lobs.shots_fired == 1 and game.mace_fire_lobs.active.size() == 1 and game.mace_fire_lobs.active[0].node.position.y > game.player.position.y + .8, "the first hit sends one fireball above the ground")
		if game.mace_fire_lobs.active.size() == 1:
			var flight: Dictionary = game.mace_fire_lobs.active[0]
			var chord: Vector3 = flight.origin.lerp(flight.target, flight.age / game.MaceFireLobs.FLIGHT_TIME)
			check(flight.node.position.y > chord.y + .7 and game.hits == 0, "the actual projectile follows a curved arc before impact")
			check(flight.node.texture.resource_path.ends_with("mace_molten_fireball.png"), "the flying projectile uses the painted molten fireball sprite")
			var point: Vector3 = flight.target
			var lateral: Vector3 = flight.direction.cross(Vector3.UP) * .60
			landing_target.position = Vector3(point.x + lateral.x, .03, point.z + lateral.z)
			point += flight.direction * float(game.MaceFireLobs.BOUNCE_DISTANCES[0])
			dummy(point.x + lateral.x, point.z + lateral.z)
	await physics_frame
	game.tick(.65)
	check(game.hits == 1 and game.total_damage == 24 and landing_points.size() == 1, "the first landing deals one burst of fire damage")
	check(game.mace_fire_lobs.active.size() == 1, "one large fireball continues from the first landing")
	var large_pixel_size: float = game.mace_fire_lobs.active[0].node.pixel_size if not game.mace_fire_lobs.active.is_empty() else 0.0
	for frame in 45:
		if game.mace_fire_lobs.active.size() == 3: break
		game.tick(1.0 / 120.0)
	check(game.mace_fire_lobs.active.size() == 3, "the second landing splits into three visible fireballs")
	if game.mace_fire_lobs.active.size() == 3:
		var destinations: Array[Vector3] = []
		for fireball: Dictionary in game.mace_fire_lobs.active:
			check(fireball.node.pixel_size < large_pixel_size * .7, "each split fireball is smaller than the main ball")
			destinations.append(fireball.target)
		check(destinations[0].distance_to(destinations[1]) > .75 and destinations[0].distance_to(destinations[2]) > .75 and destinations[1].distance_to(destinations[2]) > 1.5, "the final fireballs spread across distinct landing spots")
		# Two flank targets and one target within two overlapping blast radii.
		for point: Vector3 in [destinations[1], destinations[2], destinations[0].lerp(destinations[1], .5)]:
			dummy(point.x + .40, point.z)
	await physics_frame
	game.tick(.38)
	check(landing_points.size() == 5 and game.mace_fire_lobs.active.is_empty(), "two large ground contacts and all three fragments resolve")
	if landing_points.size() == 5:
		check(is_equal_approx(landing_points[0].distance_to(landing_points[1]), 3.2) and is_equal_approx(landing_points[1].distance_to(landing_points[2]), 2.1), "the main path keeps its short final leg")
	check(game.hits == 5 and game.total_damage == 120, "both flank fragments deal damage and overlapping blasts hit each target only once")
	check(ember_contacts.size() == 5, "each real landing produces its own painted ember contact")
	for index in ember_contacts.size():
		check(ember_contacts[index].distance_to(landing_points[index]) < .1, "the painted flash stays at landing %d" % index)
	game.mace_fire_lobs.detonated.disconnect(track_landing)
	check(game.request_attack() and game.motion.stage == 1 and game.motion.definition(1).kind == "fire_lift", "second attack lifts from the other side")
	game.tick(.65)
	check(game.request_attack() and game.motion.stage == 0, "third attack loops back to the first side")
	game.tick(.65)
	game.tick(5.0)
	check(game.request_attack() and game.motion.definition(game.motion.stage).kind == "lift", "the original combo returns after expiry")
	fresh()
	dummy(3.0, 0)
	dummy(5.5, 0)
	await physics_frame
	var hits_before_direct: int = game.hits
	var damage_before_direct: float = game.total_damage
	game.mace_fire_lobs.launch(Vector3(2.4, .76, 0), Vector3(5.5, .04, 0), Vector3.RIGHT, game.camera)
	game.tick(.10)
	check(game.hits == hits_before_direct + 1 and game.total_damage == damage_before_direct + 24 and game.mace_fire_lobs.active.is_empty(), "a direct body impact detonates immediately and stops the whole lob")
	fresh()
	var wall := StaticBody3D.new()
	wall.position = Vector3(4.1, 2.5, 0)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.20, 5.0, 2.0)
	collider.shape = shape
	wall.add_child(collider)
	game.add_child(wall)
	dummy(5.3, 0)
	await physics_frame
	key(KEY_1)
	var hits_before_wall: int = game.hits
	game.tick(.65)
	check(game.request_attack(), "buffed attack can launch toward cover")
	game.tick(.45)
	game.tick(.65)
	check(game.mace_fire_lobs.shots_fired == 1 and game.mace_fire_lobs.active.is_empty() and game.hits == hits_before_wall, "solid cover blocks the fire lob")
	game.remove_child(wall)
	wall.queue_free()
	fresh()
	check(game.loadout.equip_skill(0, "mace_aftershock"), "level 15 rift can be equipped")
	check(game.loadout.equip_skill(1, "mace_impact"), "ground impact can be equipped beside the rift")
	var direct = dummy(3.25, 0)
	var spread = dummy(2.55, 2.40)
	var outside_rift = dummy(2.55, 3.05)
	key(KEY_1)
	check(game.mana == starting_mana - 20, "rift pays 20 mana when started")
	game.tick(.53)
	check(game.hits == 1 and game.total_damage == 14 and spread.health == spread.max_health, "placement deals 14 only at the initial impact")
	check(game._mace_ground.rift.get("radius", 0.0) == 2.8 and game._mace_ground.rift.get("charges") == 3, "placement keeps the wider rift and all three charges")
	var rift_visual = game._mace_ground.rift.get("visual")
	check(rift_visual is Sprite3D and rift_visual.texture.resource_path.ends_with("mace_rift_cracks.png"), "placing the rift anchors painted cracks to the floor")
	check(not game._mace_ground.rift.has("markers"), "the persistent rift has no drawn perimeter")
	check(game.ui.stage_text.text.contains("ทุบฝังแรง"), "the stage HUD names the actual mace skill")
	game.tick(.32)
	var health_before_finisher: float = direct.health
	game._next_combo = 2
	game.rewards.combo_left = .7
	check(game.request_attack(), "basic ground finisher starts")
	game.tick(.56)
	check(is_equal_approx(health_before_finisher - direct.health, 46.0), "direct hit keeps full damage without rift damage")
	check(spread.health == spread.max_health, "the rift waits after the slam before dealing damage")
	check(game._mace_ground.rift.charges == 2, "one basic ground hit consumes one charge")
	check(game.fx.mace_impacts.any(func(mark: Sprite3D) -> bool: return mark.name.begins_with("MaceRiftCharge")), "the queued echo gives the existing cracks a charge cue")
	check(not game.fx.mace_impacts.any(func(mark: Sprite3D) -> bool: return mark.name.begins_with("MaceRiftEcho")), "the bright crack pulse waits for the actual echo")
	game.tick(.01)
	check(is_equal_approx(health_before_finisher - direct.health, 46.0), "the echo does not fire early")
	game.tick(.04)
	check(is_equal_approx(health_before_finisher - direct.health, 78.2) and spread.health == spread.max_health and outside_rift.health == outside_rift.max_health, "the delayed echo adds 70 percent to the original target only")
	check(game.fx.mace_impacts.any(func(mark: Sprite3D) -> bool: return mark.name.begins_with("MaceRiftEcho") and mark.position.distance_to(rift_visual.position) < .08), "the echo lights the same ground footprint as the placed decal")
	game.tick(.31)
	key(KEY_2)
	check(game.active_skill_id == "mace_impact", "the skill slam starts (motion %s, elapsed %s, slots %s)" % [game.motion.busy, game.motion.elapsed, game.loadout.mace_skill_slots])
	game.tick(.85)
	check(is_equal_approx(game.total_damage, 177.2) and game._mace_ground.rift.get("charges") == 1, "a skill slam adds 70 percent to its own damage (damage %s, rift %s)" % [game.total_damage, game._mace_ground.rift])
	game._next_combo = 2
	game.rewards.combo_left = .7
	check(game.request_attack(), "a third ground hit can start")
	game.tick(.70)
	var expected_echo_total := 177.2 + 46.0 / .90 * 1.70
	check(game._mace_ground.rift.is_empty() and game._mace_ground.echoes.is_empty() and is_equal_approx(game.total_damage, expected_echo_total), "the last echo includes the increased damage against the armor opened by the previous skill (damage %s, rift %s)" % [game.total_damage, game._mace_ground.rift])
	fresh()
	dummy(2.55, 2.4)
	key(KEY_1)
	game.tick(.85)
	key(KEY_2)
	game.tick(.73)
	check(game.hits == 0 and game._mace_ground.rift.get("charges") == 3, "a slam with no direct target does not spend a charge or damage bystanders")
	check(game.fx.mace_impacts.any(func(mark: Sprite3D) -> bool: return mark.name.begins_with("MaceRiftEcho")), "an in-range empty slam still makes the rift visibly erupt")
	fresh()
	var quick_target = dummy(2.55, 0)
	key(KEY_1)
	game.tick(.85)
	var quick_hit := {quick_target.get_instance_id(): 10.0}
	var quick_center: Vector3 = game._mace_ground.rift.center
	game._trigger_mace_rift(quick_center, quick_hit)
	game.tick(.10)
	game._trigger_mace_rift(quick_center, quick_hit)
	check(game._mace_ground.rift.get("charges") == 1, "two valid contacts within .4 seconds each queue an echo")
	var damage_before_echo: float = game.total_damage
	game.tick(.15)
	check(is_equal_approx(game.total_damage, damage_before_echo + 7), "the first rapid echo keeps its own delay")
	game.tick(.10)
	check(is_equal_approx(game.total_damage, damage_before_echo + 14), "the later rapid echo resolves separately")
	fresh()
	check(game.loadout.equip_skill(2, "mace_double_impact"), "double slam can be paired with the rift")
	dummy(3.3, 0)
	key(KEY_1)
	game.tick(.85)
	key(KEY_3)
	game.tick(1.62)
	check(game.hits == 5 and is_equal_approx(game.total_damage, 143.2) and game._mace_ground.rift.get("charges") == 1, "both double slam contacts independently add their own bonus damage")
	fresh()
	key(KEY_1)
	game.tick(.53)
	game.tick(10.1)
	check(game._mace_ground.rift.is_empty(), "the rift expires ten seconds after placement")
	fresh()
	dummy(3.0, 0)
	game.tick(1.0)
	check(game.hits == 0 and game._mace_ground.rift.is_empty(), "restart clears the rift")
	fresh()
	check(game.loadout.equip_skill(2, "mace_earth_wave"), "the level 20 slam can be equipped")
	var core = dummy(.4, 0)
	var edge = dummy(1.7, .8)
	var outside_landing = dummy(0, 1.9)
	var behind_landing = dummy(-.4, 0)
	key(KEY_3)
	check(game.mace_charge_grade(2) == 1 and is_equal_approx(game.mana, starting_mana - 32.0), "the slam holds at grade one and spends mana once")
	release_key(KEY_3)
	game.tick(.56)
	check(absf(game.player.position.x) < .03 and game.hits == 2 and core.stagger > 0.0, "a tap slams in place and staggers targets in the forward fan")
	check(is_equal_approx(core.max_health - core.health, 64) and is_equal_approx(edge.max_health - edge.health, 38) and outside_landing.health == outside_landing.max_health and behind_landing.health == behind_landing.max_health, "a tap deals 64 close and 38 farther ahead and leaves the sides and rear clear")
	for tier in [2, 3]:
		fresh()
		game.test_aim = Vector3.BACK if tier == 2 else Vector3.RIGHT
		var expected := Vector3(0, 0, 2.52) if tier == 2 else Vector3(5.04, 0, 0)
		var close_point: Vector3 = expected + game.test_aim * .7
		var side := Vector3(-game.test_aim.z, 0, game.test_aim.x)
		var far_point: Vector3 = expected + game.test_aim * 1.55 + side * (1.12 if tier == 2 else 1.65)
		var longer_point: Vector3 = expected + game.test_aim * 2.8
		var beyond_tip: Vector3 = expected + game.test_aim * 3.1
		var close_target = dummy(close_point.x, close_point.z)
		var far_target = dummy(far_point.x, far_point.z)
		var longer_target = dummy(longer_point.x, longer_point.z)
		var beyond_target = dummy(beyond_tip.x, beyond_tip.z)
		key(KEY_3)
		game.tick(.45 if tier == 2 else .95)
		check(game.mace_charge_grade(2) == tier and game.hits == 0, "holding selects the tier before the jump")
		var fan: MeshInstance3D = game._mace_ground.landing_markers[0]
		check(is_equal_approx(fan.scale.x, 1.0) and (fan.basis.x.normalized().dot(game.test_aim) > .999), "the preview keeps its length and points in the leap direction")
		release_key(KEY_3)
		game.tick(.24)
		check(game.avatar.position.y > .2 and game.hits == 0, "the visible jump rises before contact")
		game.tick(.32)
		var landed: Vector3 = game.player.position
		landed.y = 0
		check(landed.distance_to(expected) < .06 and absf(game.avatar.position.y) < .001, "tier %d lands at its aimed distance" % tier)
		var waves: Array = game.fx.mace_impacts.filter(func(mark: Sprite3D) -> bool: return mark.name.begins_with("MaceLeapWave"))
		check(waves.size() == 1, "each charged landing produces a single painted forward wave")
		if waves.size() == 1:
			var wave: Sprite3D = waves[0]
			var shader: ShaderMaterial = wave.material_override
			check(wave.position.distance_to(landed) < .09 and wave.basis.x.normalized().dot(game.test_aim) > .999, "the painted wave follows the actual landing and aim")
			check(is_equal_approx(shader.get_shader_parameter("half_arc"), MaceSkills.LEAP_GRADES[tier - 1].arc * .5), "the painted wave takes its angle from the live damage footprint")
		check(is_equal_approx(close_target.max_health - close_target.health, 82 if tier == 2 else 100) and is_equal_approx(far_target.max_health - far_target.health, 49 if tier == 2 else 60) and is_equal_approx(longer_target.max_health - longer_target.health, 49 if tier == 2 else 60) and beyond_target.health == beyond_target.max_health, "tier %d keeps its angle and hits along the longer fan" % tier)
	fresh()
	game.test_aim = Vector3.ZERO
	game.tick(1.0)
	key(KEY_3)
	game.tick(.95)
	var chosen := Vector3(3.2, game.player.position.y, -1.6)
	game._mouse_position = game.camera.unproject_position(chosen)
	game.tick(.01)
	var marker: MeshInstance3D = game._mace_ground.landing_markers[0]
	check(marker.position.distance_to(chosen + Vector3.UP * .055) < .04, "full charge previews the cursor destination inside its range")
	release_key(KEY_3)
	game.tick(.56)
	check(game.player.position.distance_to(chosen) < .06 and game._mace_ground.landing_markers.is_empty(), "the leap lands on the preview and removes the marker")
	fresh()
	var leap_wall := StaticBody3D.new()
	leap_wall.position = Vector3(4.1, 2.5, 0)
	var leap_collider := CollisionShape3D.new()
	leap_collider.shape = shape
	leap_wall.add_child(leap_collider)
	game.add_child(leap_wall)
	var behind_wall = dummy(4.6, 0)
	await physics_frame
	key(KEY_3)
	game.tick(.95)
	var reachable: Vector3 = game._mace_ground.landing_markers[0].position
	release_key(KEY_3)
	game.tick(.56)
	check(reachable.x < 4.0 and absf(game.player.position.x - reachable.x) < .04 and behind_wall.health == behind_wall.max_health, "wall clips the preview and the jump and blocks the impact")
	game.remove_child(leap_wall)
	leap_wall.queue_free()
	fresh()
	var rift_direct = dummy(1.1, 0)
	var rift_edge = dummy(1.9, .8)
	var rift_spread = dummy(4.1, 0)
	key(KEY_1)
	game.tick(.90)
	key(KEY_3)
	release_key(KEY_3)
	game.tick(.56)
	check(is_equal_approx(rift_direct.max_health - rift_direct.health, 64) and is_equal_approx(rift_edge.max_health - rift_edge.health, 38) and rift_spread.health == rift_spread.max_health and game._mace_ground.rift.get("charges") == 2, "the landing spends a rift charge and queues a separate echo")
	game.tick(.24)
	check(is_equal_approx(rift_direct.max_health - rift_direct.health, 108.8) and is_equal_approx(rift_edge.max_health - rift_edge.health, 64.6) and rift_spread.health == rift_spread.max_health, "the delayed echo uses each leap target's actual damage")
	fresh()
	var full_echo_target = dummy(3.15, 0)
	key(KEY_1)
	game.tick(.90)
	var before_full_leap: float = full_echo_target.health
	game.test_aim = Vector3.ZERO
	game._mouse_position = game.camera.unproject_position(Vector3(2.6, game.player.position.y, 0))
	key(KEY_3)
	game.tick(.95)
	release_key(KEY_3)
	game.tick(.56)
	check(is_equal_approx(before_full_leap - full_echo_target.health, 100.0), "a full leap inside the rift hits for 100 first")
	game.tick(.24)
	check(is_equal_approx(before_full_leap - full_echo_target.health, 170.0), "the same full-leap target takes another 70 after the delay")
	check_armor_counter()
	fresh()
	game.set_weapon_family("sword")
	key(KEY_1)
	check(game.active_skill_id == "impaling_thrust", "switching to sword restores its original skill slots")
	game.queue_free()
	await process_frame
	print("MACE SKILLS: ", failures, " failures")
	quit(0 if failures == 0 else 1)
