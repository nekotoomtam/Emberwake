extends SceneTree
const Motion = preload("res://scripts/sword_skill_motion.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	for id in Motion.SKILLS:
		var motion = Motion.new()
		check(motion.configure(id), "valid skill configures")
		check(not motion.configure("missing"), "unknown ID rejected")
		for index in range(motion.stage_count()):
			check(motion.start(index, .43), "every stage starts")
			check(not motion.start(index, .0), "busy rejects restart")
			var d: Dictionary = motion.definition(index)
			check(d.windup > 0 and d.active > 0 and d.recovery > 0, "finite positive timings")
			var last_lunge := .0
			var events := 0
			for delta in [d.windup * .5, d.windup * .5, d.active * .5, d.active * .5, d.recovery * .5, d.recovery * .5, 1.0]:
				var r: Dictionary = motion.advance(delta)
				if r.projectile_ready: events += 1
				var pose: Dictionary = motion.sample()
				for key in ["progress", "angle", "radius", "pitch", "grip_height", "blade_length", "body_lean", "lunge_offset", "body_spin"]:
					check(is_finite(pose[key]), "%s %d finite %s" % [id, index, key])
				check(pose.lunge_offset >= last_lunge - .00001, "travel never moves actor backward")
				last_lunge = pose.lunge_offset
			check(events == (1 if d.projectile else 0), "single projectile release per wave stage")
			check(not motion.busy, "stage terminates")
			var split_pose: Dictionary = motion.sample()
			motion.reset()
			motion.start(index, .43)
			var large: Dictionary = motion.advance(50)
			check(large.finished and large.active, "large delta preserves active interval")
			check(large.projectile_ready == d.projectile, "large delta releases wave once")
			check(absf(motion.sample().angle - split_pose.angle) < .00001, "final pose subdivision invariant")
			check(absf(large.trail_from.progress) < .00001 and absf(large.trail_to.progress - 1) < .00001, "trace clips active boundaries")
			if d.spin:
				check(absf(large.current_angle - large.previous_angle) >= TAU - .00001, "spin preserves full revolution")
				for a in [0.0, PI * .5, PI, PI * 1.5]:
					check(motion.is_target_hit(Vector3.ZERO, Vector3(cos(a) * 2, 0, sin(a) * 2), .0, large.previous_angle, large.current_angle), "full spin reaches each quadrant")
			motion.reset()
	var thrust = Motion.new()
	thrust.start(0, 0)
	check(not thrust.is_target_hit(Vector3.ZERO, Vector3(2, 0, 0), .0, 0, 0), "windup cannot hit with thrust")
	thrust.advance(thrust.definition(0).windup)
	check(thrust.is_target_hit(Vector3.ZERO, Vector3(2, 0, .1), .0, 0, 0), "narrow thrust center capsule hits")
	check(not thrust.is_target_hit(Vector3.ZERO, Vector3(2, 0, .4), .0, 0, 0), "narrow thrust rejects side target")
	check(thrust.is_target_hit(Vector3.ZERO, Vector3(2, 0, .3), .2, 0, 0), "thrust includes target radius")
	check(not thrust.is_target_hit(Vector3.ZERO, Vector3(-.5, 0, 0), .1, 0, 0), "thrust rejects rear target")
	check(not thrust.is_target_hit(Vector3.ZERO, Vector3(2.5, 0, 0), .0, 0, 0), "far edge cannot hit before visible tip arrives")
	thrust.advance(thrust.definition(0).active * .5)
	check(not thrust.is_target_hit(Vector3.ZERO, Vector3(2.5, 0, 0), .0, 0, 0), "partially extended tip still misses far edge")
	thrust.advance(thrust.definition(0).active * .5)
	check(thrust.is_target_hit(Vector3.ZERO, Vector3(2.5, 0, 0), .0, 0, 0), "extended visible tip hits far edge")
	thrust.reset()
	thrust.start(0, 0)
	var crossed: Dictionary = thrust.advance(50)
	check(thrust.is_target_hit(Vector3.ZERO, Vector3(2.5, 0, 0), .0, crossed.previous_angle, crossed.current_angle), "large frame preserves swept thrust reach")
	thrust.configure("square_off")
	thrust.reset()
	thrust.configure("square_off")
	thrust.start(0, 0)
	check(not thrust.advance(10).damage_ready, "stance never damages")
	check(not thrust.is_target_hit(Vector3.ZERO, Vector3(1, 0, 0), .2, -1, 1), "stance has no hit geometry")
	check(not thrust.advance(INF).projectile_ready, "invalid delta safe")
	_test_entry_pose()
	_test_revised_skills()
	_test_attribute_scaling()
	if failures.is_empty(): print("PASS: sword skill motion (%d checks)" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _test_attribute_scaling() -> void:
	var motion = Motion.new()
	var stats := {"strength": 8, "dexterity": 8, "intelligence": 8}
	var cases := {
		"impaling_thrust": [51 * 1.15],
		"double_slash": [27 * 1.10, 31 * 1.10],
		"square_off": [0, 57 * 1.10, 66 * 1.10],
		"sword_dance": [29 * 1.10, 29 * 1.10, 45 * 1.10],
		"spinning_slash": [36 * 1.15, 36 * 1.15],
		"storm_blade": [0],
		"stormcaller": [31 * 1.10, 36 * 1.10, 42 * 1.15],
		"vacuum_slice": [84 * 1.10],
	}
	for id: String in cases:
		check(motion.configure(id, stats), "configure scaling for " + id)
		for index in range(motion.stage_count()):
			check(is_equal_approx(motion.definition(index).damage, cases[id][index]), "scaled damage for %s stage %d" % [id, index])
		check(motion.configure(id, stats, 24), "configure upgraded sword for " + id)
		for index in range(motion.stage_count()):
			check(is_equal_approx(motion.definition(index).damage, cases[id][index] * 1.2), "weapon power reaches %s stage %d" % [id, index])
	motion.configure("storm_blade", {"intelligence": 8}, 24)
	check(motion.definition(0).wave_damage.is_equal_approx(Vector3(16.8, 19.2, 22.8) * 1.10), "weapon power and INT reach all three buff waves")
	motion.configure("double_slash", stats)
	var quick: Dictionary = motion.definition(1)
	check(is_equal_approx(quick.windup + quick.active + quick.recovery, .255 * .9375), "DEX shortens each double slash phase")
	motion.configure("square_off", stats)
	check(motion.definition(0).active == 1.15 and is_equal_approx(motion.definition(1).windup, .12 * .9625), "DEX leaves the stance choice window intact")
	motion.configure("stormcaller", stats)
	check(motion.definition(1).recovery == .2 and is_equal_approx(motion.definition(2).recovery, .2 * .9625), "DEX preserves step gaps and speeds final recovery")
	motion.configure("vacuum_slice", stats)
	check(is_equal_approx(motion.definition(0).projectile_speed, 8.4) and motion.definition(0).projectile_radius == .8, "INT increases wave speed at the original width")
	check(Motion.mana_cost("vacuum_slice", stats) == 31.5 and Motion.mana_cost("storm_blade", stats) == 21.5, "INT discounts the two wave skills")
	check(Motion.mana_cost("stormcaller", stats) == 38, "stormcaller keeps its base cost")
	motion.configure("vacuum_slice", {"intelligence": 100, "dexterity": 100})
	check(is_equal_approx(motion.definition(0).damage, 117.6) and is_equal_approx(motion.definition(0).projectile_speed, 9.2), "damage and projectile speed respect caps")
	check(is_equal_approx(motion.definition(0).windup, .65 * .85) and is_equal_approx(Motion.mana_cost("vacuum_slice", {"intelligence": 100}), 27.2), "timing and mana discounts respect caps")

func _test_entry_pose() -> void:
	for aim in [0.0, PI * .5, PI, -PI * .5]:
		var motion = Motion.new()
		motion.configure("double_slash")
		motion.start(0, aim)
		check(absf(wrapf(motion.sample().angle - aim - .35, -PI, PI)) < .00001, "fresh windup starts in requested facing")
		motion.advance(50)
		var held: Dictionary = motion.sample()
		motion.start(1, aim)
		for key in ["angle", "radius", "pitch", "grip_height", "body_lean"]:
			check(absf(motion.sample()[key] - held[key]) < .00001, "chained stage preserves entry %s" % key)
		motion.advance(50)
		held = motion.sample()
		motion.configure("vacuum_slice")
		motion.seed_pose(held)
		motion.start(0, aim)
		for key in ["angle", "radius", "pitch", "grip_height", "body_lean"]:
			check(absf(motion.sample()[key] - held[key]) < .00001, "new skill preserves seeded entry %s" % key)

func _test_revised_skills() -> void:
	var motion = Motion.new()
	motion.configure("double_slash")
	var duration := .0
	for index in range(2):
		var d: Dictionary = motion.definition(index)
		duration += d.windup + d.active + d.recovery
		motion.start(index, 0.0)
		var sweep: Dictionary = motion.advance(d.windup + d.active)
		var edge_target := Vector3(cos(1.02), 0.0, sin(1.02)) * 2.1
		var outside_target := Vector3(cos(1.2), 0.0, sin(1.2)) * 2.1
		check(motion.is_target_hit(Vector3.ZERO, edge_target, 0.0, sweep.previous_angle, sweep.current_angle), "both double-slash cuts reach beyond the old arc")
		check(not motion.is_target_hit(Vector3.ZERO, outside_target, 0.0, sweep.previous_angle, sweep.current_angle), "double slash still misses beyond the wider arc")
		motion.reset()
	check(absf(duration - .51) < .00001, "double slash lasts .51 seconds for both authored cuts")
	check(duration < .88 and duration > .4, "double slash is quicker than ordinary cuts without becoming instant")
	motion.configure("sword_dance")
	check(not motion.definition(0).spin and not motion.definition(1).spin, "dance begins with two cuts")
	check(motion.definition(2).spin and absf(motion.definition(2).arc - TAU) < .00001, "dance ends with exactly one full spin")
	motion.configure("storm_blade")
	var buff: Dictionary = motion.definition(0)
	check(buff.buff_duration == 5.0 and buff.damage == 0 and not buff.projectile, "storm blade activates five-second buff without direct attack")
	motion.start(0, 0)
	var activation: Dictionary = motion.advance(50)
	check(not activation.damage_ready and not activation.projectile_ready, "buff activation emits neither direct damage nor wave")
	motion.reset()
	motion.configure("stormcaller")
	for index in range(3):
		var d: Dictionary = motion.definition(index)
		check(d.radial and d.spin and is_equal_approx(d.arc, TAU), "each stormcaller ring accompanies one full body spin")
		check(absf(d.effect_radius - (2.4 + index * .8)) < .00001, "successive rings expand to larger radii")
		check(d.push == (index == 2) and d.knockback == (9.0 if index == 2 else 1.1), "only final ring has forceful push")
		motion.start(index, 0)
		check(not motion.is_target_hit(Vector3.ZERO, Vector3(1, 0, 0), 0, 0, 0), "ring cannot hit before active")
		motion.advance(d.windup * .75)
		var planted: float = motion.sample().lunge_offset
		check(is_equal_approx(planted, .35 if index == 0 else .0), "only the opening windup steps forward")
		motion.advance(d.windup * .25 + d.active * .25)
		var pose: Dictionary = motion.sample()
		check(absf(pose.effect_radius - d.effect_radius * .25) < .00001, "visible ring grows with active progress")
		check(is_equal_approx(pose.lunge_offset, planted) and pose.radius < .35 and pose.blade_length == 1.9, "the opening step ends before the rigid blade spins")
		check(not motion.is_target_hit(Vector3.ZERO, Vector3(d.effect_radius * .9, 0, 0), 0, 0, 0), "ring misses far target before expansion arrives")
		check(motion.is_target_hit(Vector3.ZERO, Vector3(d.effect_radius * .2, 0, 0), 0, 0, 0), "crossed inner ring radius hits")
		var expanded: Dictionary = motion.advance(d.active * .75 + d.recovery)
		check(motion.is_target_hit(Vector3.ZERO, Vector3(d.effect_radius * .9, 0, 0), 0, expanded.previous_angle, expanded.current_angle), "swept annulus hits far target once expansion arrives")
		check(not motion.is_target_hit(Vector3.ZERO, Vector3(.01, 0, 0), 0, 0, 0), "expanding annulus excludes already passed center")
		motion.reset()
		motion.start(index, 0)
		var large: Dictionary = motion.advance(50)
		check(large.effect_radius_from == 0 and absf(large.effect_radius_to - d.effect_radius) < .00001, "large frame carries complete ring sweep")
		check(motion.is_target_hit(Vector3.ZERO, Vector3(d.effect_radius * .9, 0, 0), 0, 0, 0), "large frame retains distant ring contact")
		motion.reset()
	motion.configure("vacuum_slice")
	check(motion.definition(0).stagger_duration > 0 and motion.definition(0).stagger_duration < 1, "vacuum slice carries short stagger metadata")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
