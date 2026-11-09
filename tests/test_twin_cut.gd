extends SceneTree
## Live Game integration plus an independent archived pose oracle.
var checks := 0
var failures: Array[String] = []
var game

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
	check(game.has_method("request_skill"), "Game exposes the Sword skill request")
	if game.has_method("request_skill"):
		_test_legacy_model()
		_test_live_sequence()
		_test_dodge_cancellation()
	game.queue_free()
	await process_frame
	print("TWIN CUT TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func fresh() -> void:
	game.start_run(true)
	game.test_aim = Vector3.RIGHT
	game.clear_actors()
	game.set_weapon_family("sword")
	game.spawn_enemy("dummy", Vector3(10, .03, 0))

func _test_legacy_model() -> void:
	var skill = load("res://scripts/twin_cut_motion.gd").new()
	var oracle_path := "res://reference/legacy-sword/weapon_motion.gd"
	if not FileAccess.file_exists(oracle_path):
		# Export intentionally excludes the archive. An external test helper
		# resolves its source-side oracle while live modules remain in the PCK.
		var source_root: String = get_script().resource_path.get_base_dir().get_base_dir()
		oracle_path = source_root.path_join("reference/legacy-sword/weapon_motion.gd")
	if not FileAccess.file_exists(oracle_path):
		check(false, "required archived pose oracle is missing: " + oracle_path)
		return
	var oracle_script = load(oracle_path)
	if oracle_script == null or not oracle_script.can_instantiate():
		check(false, "required archived pose oracle cannot load: " + oracle_path)
		return
	var oracle = oracle_script.new()
	for cut in [0, 1]:
		var old: Dictionary = oracle.definition(cut)
		var definition: Dictionary = skill.definition(cut)
		var timings := [[.055, .050, .045], [.040, .055, .105]]
		var ordinary = load("res://scripts/sword_motion.gd").new()
		var basic: Dictionary = ordinary.definition(cut)
		check(definition.windup < basic.windup and definition.active < basic.active, "Q prepares and releases faster than corresponding basic cut")
		check(definition.windup + definition.active + definition.recovery < basic.windup + basic.active + basic.recovery, "Q cut faster than ordinary cut")
		for index in range(3):
			var field: String = ["windup", "active", "recovery"][index]
			check(is_equal_approx(definition[field], timings[cut][index]), "cut %d rapid %s" % [cut, field])
		for field in ["damage", "reach", "arc"]:
			check(is_equal_approx(definition[field], old[field]), "cut %d original %s" % [cut, field])
		var duration: float = old.windup + old.active + old.recovery
		for fraction in [.0, .13, .32, .4, .5, .61, .8, .99]:
			skill.reset()
			oracle.reset()
			skill.start(cut, 2.9)
			oracle.start(cut, 2.9)
			var old_time: float = duration * fraction
			var new_time: float
			if old_time < old.windup:
				new_time = definition.windup * old_time / old.windup
			elif old_time < old.windup + old.active:
				new_time = definition.windup + definition.active * (old_time - old.windup) / old.active
			else:
				new_time = definition.windup + definition.active + definition.recovery * (old_time - old.windup - old.active) / old.recovery
			skill.advance(new_time)
			oracle.advance(duration * fraction)
			var actual: Dictionary = skill.sample()
			var expected: Dictionary = oracle.sample()
			check(actual.phase == expected.phase, "legacy phase at %d/%f" % [cut, fraction])
			for field in ["angle", "radius", "body_lean", "progress"]:
				var expected_value: float = old.reach - 1.9 if field == "radius" else expected[field]
				check(is_equal_approx(actual[field], expected_value), "legacy tip orbit compatibility %s at %d/%f" % [field, cut, fraction])
			check(actual.has("pitch") and actual.has("grip_height") and actual.has("blade_length"), "current hero compatible grip")
			check(is_equal_approx(actual.blade_length, 1.9), "current Sword retains rigid authored length")
			var visible_ground_tip: float = actual.radius + cos(actual.pitch) * actual.blade_length
			check(is_equal_approx(visible_ground_tip, old.reach), "visible rigid blade tip follows original reach at %d/%f" % [cut, fraction])
		skill.reset()
		skill.start(cut, 0)
		var sweep: Dictionary = skill.advance(3.0)
		check(sweep.active and sweep.finished, "hitch crosses full active and recovery")
		check(skill.is_target_hit(Vector3.ZERO, Vector3(2, 0, 0), .1, sweep.previous_angle, sweep.current_angle), "full legacy sweep includes forward target")
		check(not skill.is_target_hit(Vector3.ZERO, Vector3(-2, 0, 0), .1, sweep.previous_angle, sweep.current_angle), "legacy sweep excludes rear")
		check(not skill.is_target_hit(Vector3.ZERO, Vector3(2.6, 0, 0), .1, sweep.previous_angle, sweep.current_angle), "finite legacy reach")
		var tip: float = skill.sample().radius + skill.sample().blade_length
		# Vector3 stores float32, so derive radius from the represented endpoint
		# rather than introduce decimal-rounding error into an exact tangency.
		var touching := Vector3(tip + .1, 0, 0)
		var touching_radius: float = touching.x - tip
		check(skill.is_target_hit(Vector3.ZERO, touching, touching_radius, sweep.previous_angle, sweep.current_angle), "visible tip contact boundary hits")
		check(not skill.is_target_hit(Vector3.ZERO, Vector3(tip + .101, 0, 0), .1, sweep.previous_angle, sweep.current_angle), "outside visible tip contact boundary misses")
	check(not skill.start(2, 0), "no third cut")
	var total := 0.0
	for cut in [0, 1]:
		var d: Dictionary = skill.definition(cut)
		total += d.windup + d.active + d.recovery
	check(is_equal_approx(total, .35) and total < .42, "both Q cuts finish faster than the first normal attack")

func _test_live_sequence() -> void:
	fresh()
	game._next_combo = 2
	var basic = game.motion
	check(game.request_skill(), "one skill request accepted")
	check(not game.request_attack() and not game.request_skill(), "cannot overlap a skill")
	game.tick(.149)
	check(game.skill_active and game.skill_cut_index == 0, "first cut remains until .150")
	game.tick(.001)
	check(game.skill_active and game.skill_cut_index == 1, "second cut begins automatically")
	game.tick(.199)
	check(game.skill_active, "second cut remains until .350")
	game.tick(.001)
	check(not game.skill_active and game.motion == basic, "completion restores independent basic motion")
	check(game._next_combo == 2, "skill preserves earned basic stage")
	check(game.request_attack() and game.motion.stage == 2, "next LMB uses earned stage")
	for hitch in [false, true]:
		fresh()
		var target = game.spawn_enemy("dummy", Vector3(1.7, .03, 0))
		check(game.request_skill(), "damage skill begins")
		if hitch:
			game.tick(.95)
		else:
			for frame in range(150):
				game._hit_stop = 0
				game.tick(.008)
		check(game.hits == 2 and is_equal_approx(game.total_damage, 37), "two cuts each damage target once, hitch=%s" % hitch)
		check(not game.skill_active, "sequence completes, hitch=%s" % hitch)
		check(game.request_skill(), "skill immediately reusable, no MP or cooldown")

func _test_dodge_cancellation() -> void:
	fresh()
	game.request_skill()
	game.tick(.18)
	game.stamina = 29
	var elapsed: float = game.motion.elapsed
	check(not game.request_dodge() and game.skill_active and game.motion.elapsed == elapsed, "rejected dodge leaves skill intact")
	game.stamina = 100
	game._hit_stop = .1
	check(game.request_dodge(), "dodge interrupts second cut even during hitstop")
	check(not game.skill_active and not game.motion.busy and game.motion.stage == -1, "dodge clears skill and resets motion")
	check(game._hit_stop == 0 and game._next_combo == 0, "dodge clears hitstop and basic chain")
	game.tick(1.0)
	check(game.hits == 0, "cancelled second cut cannot fire later")
