extends SceneTree
var checks := 0
var failures: Array[String] = []
var game

class ContactLifecycleGame extends "res://scripts/game.gd":
	var contact_action := ""
	func enemy_hit(enemy, damage: float, knock: Vector3, element: String = "") -> void:
		super.enemy_hit(enemy, damage, knock, element)
		if active_skill_id == "armor_pierce" and skill_cut_index == 1:
			if contact_action == "death": damage_player(1000)
			elif contact_action == "restart": restart()

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func _run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(true)
	var enemy = game.enemies[0]
	check(enemy.has_method("calculate_incoming_damage"), "real enemies expose armor damage calculation")
	check(ResourceLoader.exists("res://scripts/armor_pierce_motion.gd"), "Armor Pierce has its independent motion")
	if enemy.has_method("calculate_incoming_damage"):
		_test_armor(enemy)
	if ResourceLoader.exists("res://scripts/armor_pierce_motion.gd"):
		_test_motion()
		_test_contact_order()
	game.queue_free()
	await process_frame
	print("ARMOR PIERCE UNIT TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _test_armor(enemy) -> void:
	check(is_equal_approx(enemy.armor_rating, 100), "all ordinary enemies retain neutral 100 armor")
	check(is_equal_approx(enemy.calculate_incoming_damage(18, ""), 18), "neutral melee remains unchanged")
	check(enemy.apply_armor_break(), "valid break applies")
	check(is_equal_approx(enemy.effective_armor(), 80), "twenty percent armor break is 100 to 80")
	check(is_equal_approx(enemy.calculate_incoming_damage(18, ""), 22.5), "melee receives 1.25 physical multiplier")
	check(is_equal_approx(enemy.calculate_incoming_damage(20, "physical"), 25), "gun physical uses real armor")
	check(is_equal_approx(enemy.calculate_incoming_damage(20, "fire"), 20), "fire ignores armor")
	check(enemy.calculate_incoming_damage(0, "") == 0 and enemy.calculate_incoming_damage(-3, "") == 0, "nonpositive damage does not heal")
	check(enemy.calculate_incoming_damage(NAN, "") == 0 and enemy.calculate_incoming_damage(INF, "") == 0, "nonfinite damage rejects")
	for fraction in [0.0, -0.2, 1.0, INF, NAN]:
		check(not enemy.apply_armor_break(fraction, 4), "invalid fraction rejected: %s" % fraction)
	for duration in [0.0, -2.0, INF, NAN]:
		check(not enemy.apply_armor_break(.2, duration), "invalid duration rejected: %s" % duration)
	game.tick(1)
	check(is_equal_approx(enemy.armor_break_remaining, 3), "break consumes simulation time")
	game.toggle_pause()
	game.tick(5)
	check(is_equal_approx(enemy.armor_break_remaining, 3), "pause freezes status")
	game.toggle_pause()
	check(enemy.apply_armor_break(), "refresh applies")
	check(is_equal_approx(enemy.armor_break_fraction, .2) and is_equal_approx(enemy.armor_break_remaining, 4), "refresh does not stack")
	game.enemy_hit(enemy, 20, Vector3.ZERO, "physical")
	check(is_equal_approx(game.total_damage, 25) and is_equal_approx(enemy.health, 975), "resolved damage used once for health and totals")
	game.tick(.3)
	check(enemy.health == enemy.max_health and enemy.armor_break_remaining > 0, "dummy healing preserves armor break")
	game.tick(3.71)
	check(enemy.armor_break_remaining == 0 and enemy.armor_break_fraction == 0 and enemy.effective_armor() == 100, "expiry restores neutral armor")
	enemy.armor_rating = 200
	check(enemy.calculate_incoming_damage(20, "") == 10, "armor rating is functional independently of break")
	enemy.armor_rating = 0
	check(enemy.calculate_incoming_damage(20, "") == 0 and not enemy.apply_armor_break(), "invalid armor cannot accept damage or break")
	enemy.armor_rating = 100
	enemy.apply_armor_break()
	enemy.receive_damage(2000, Vector3.ZERO)
	check(enemy.dead and enemy.armor_break_remaining == 0 and enemy.armor_break_fraction == 0, "death clears status")
	check(not enemy.apply_armor_break(), "dead target rejects status")

func _test_motion() -> void:
	var model = load("res://scripts/armor_pierce_motion.gd").new()
	var ordinary = load("res://scripts/sword_motion.gd").new()
	for field in ["damage", "reach", "arc", "windup", "active", "recovery"]:
		check(is_equal_approx(model.definition(0)[field], ordinary.definition(0)[field]), "first slash matches ordinary " + field)
	check(not model.start(2, 0) and not model.start(0, NAN), "invalid stage and aim reject")
	model.start(0, 2.7)
	ordinary.start(0, 2.7)
	for dt in [.04, .09, .04, .07, .1]:
		model.advance(dt)
		ordinary.advance(dt)
		for field in ["angle", "radius", "pitch", "blade_length", "grip_height"]:
			check(is_equal_approx(model.sample()[field], ordinary.sample()[field]), "ordinary slash pose preserved " + field)
	model.reset()
	check(model.start(1, 0), "stab begins")
	var early: Dictionary = model.advance(.203)
	check(not early.damage_ready, "stab cannot damage before .204 contact")
	var contact: Dictionary = model.advance(.001)
	check(contact.damage_ready and is_equal_approx(contact.contact_pose.radius + contact.contact_pose.blade_length, 2.25), "contact uses exact visible 2.25 blade tip")
	check(is_equal_approx(contact.contact_pose.lunge_offset, .65), "cumulative lunge finishes at contact")
	check(not model.advance(.001).damage_ready, "stab contact emitted once")
	check(model.sample().blade_length == 1.9 and model.sample().grip_height == .68, "stab retains rigid blade and grip height")
	check(model.is_target_hit(Vector3.ZERO, Vector3(2.2, 0, .27), 0, 0, 0), "narrow forward lane includes in-width target")
	check(not model.is_target_hit(Vector3.ZERO, Vector3(2.2, 0, .7), .1, 0, 0), "lateral target outside rounded lane misses")
	check(not model.is_target_hit(Vector3.ZERO, Vector3(-1, 0, 0), .1, 0, 0), "rear target misses")
	check(not model.is_target_hit(Vector3.ZERO, Vector3(INF, 0, 0), .1, 0, 0), "nonfinite target misses")
	model.reset()
	model.start(1, 1)
	var hitch: Dictionary = model.advance(5)
	check(hitch.damage_ready and hitch.finished and is_equal_approx(hitch.contact_pose.lunge_offset, .65), "hitch preserves one exact contact snapshot")
	check(not model.advance(1).damage_ready, "finished hitch cannot repeat hit")

func _test_contact_order() -> void:
	var trial = ContactLifecycleGame.new()
	root.add_child(trial)
	trial.set_physics_process(false)
	for action in ["", "death", "restart"]:
		trial.start_run(true)
		trial.test_aim = Vector3.RIGHT
		var target = trial.enemies[0]
		target.position.x = 8
		trial.request_armor_skill()
		trial.tick(.52)
		check(trial.skill_cut_index == 1 and is_equal_approx(trial.motion.elapsed, .1), "contact fixture reaches stab active start")
		target.position.x = 2
		if action.is_empty(): target.apply_armor_break(.2, .05)
		trial.contact_action = action
		trial.tick(.104)
		if action.is_empty():
			check(is_equal_approx(trial.total_damage, 24), "break expired before contact cannot amplify that contact")
			check(is_equal_approx(target.armor_break_remaining, 4), "fresh contact break starts at four seconds")
		else:
			check(target.armor_break_remaining == 0, "contact " + action + " invalidates pending break")
			check(not trial.skill_active, "contact " + action + " cannot resurrect cancelled cast")
			if action == "restart":
				check(trial.enemies[0].armor_break_remaining == 0, "restart target never inherits stale break")
	trial.queue_free()
