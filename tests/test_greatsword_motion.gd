extends SceneTree

var checks := 0
var failures: Array[String] = []
var motion_script: Script

func _initialize() -> void:
	motion_script = load("res://scripts/weapon_motion.gd")
	var motion = motion_script.new()
	_check(motion.has_method("set_family"), "motion supports selecting greatsword")
	if failures.is_empty():
		_test_family_guards_and_reset()
		_test_timing_and_automatic_playback()
		_test_sweep_geometry_and_damage_window()
		_test_overhead_pose_and_impact_window()
		_test_narrow_slam_geometry_at_cardinal_aims()
		_test_chain_pose_continuity_at_cardinal_aims()
		_test_body_relative_sweep_direction()
		_check(motion.has_method("rebase_idle_aim"), "idle held pose supports aim rebasing")
		if motion.has_method("rebase_idle_aim"):
			_test_idle_aim_rebases_held_pose()
	if failures.is_empty():
		print("PASS: greatsword motion (%d checks)" % checks)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (got %.6f, expected %.6f)" % [message, actual, expected])

func _great():
	var motion = motion_script.new()
	motion.set_family("greatsword")
	return motion

func _test_family_guards_and_reset() -> void:
	var motion = motion_script.new()
	_check(motion.family == "sword", "legacy sword remains the default")
	_check(not motion.set_family("hammer"), "unknown family is refused")
	_check(motion.set_family("greatsword"), "idle motion selects greatsword")
	motion.start(1, 0.4)
	motion.advance(0.1)
	_check(not motion.set_family("sword"), "in-flight attack refuses family changes")
	_check(motion.family == "greatsword" and motion.stage == 1, "refused switch preserves the current attack")
	motion.reset()
	_check(motion.family == "greatsword" and motion.stage == -1 and not motion.busy, "reset retains family and clears chain")
	_near(motion.sample().angle, 0.35, "reset clears held chain angle")
	_check(motion.set_family("sword"), "idle switch returns to sword")
	_near(motion.definition(0).damage, 18.0, "switch restores sword tuning")
	_check(not motion.advance(1.0).damage_ready, "idle cannot produce a damage event")

func _test_timing_and_automatic_playback() -> void:
	# A start alone plays each full attack; there is no release/charge input to wait for.
	var totals := [0.54, 0.55, 0.67]
	var damage := [45.0, 47.5, 85.0]
	for index in range(3):
		var motion = _great()
		var attack: Dictionary = motion.definition(index)
		_near(attack.damage, damage[index], "greatsword stage %d damage" % index)
		_near(attack.windup + attack.active + attack.recovery, totals[index], "greatsword stage %d compact duration" % index)
		motion.start(index, 0.3)
		var almost: Dictionary = motion.advance(totals[index] - 0.0002)
		_check(motion.busy and not almost.finished, "attack continues automatically until full recovery")
		_check(motion.advance(0.0002).finished and not motion.busy, "single click start completes automatically at its authored time")
		var large_step = _great()
		large_step.start(index, 0.3)
		var whole: Dictionary = large_step.advance(8.0)
		_check(whole.finished and whole.active and whole.damage_ready, "large step preserves attack, impact and finish")
		_near(large_step.sample().angle, motion.sample().angle, "time subdivision does not alter final pose")
		_check(not large_step.advance(1.0).damage_ready, "completed attack does not repeat damage")

func _test_sweep_geometry_and_damage_window() -> void:
	for index in range(2):
		var motion = _great()
		motion.start(index, 0.0)
		var attack: Dictionary = motion.definition(index)
		_check(not motion.advance(attack.windup - 0.001).damage_ready, "side cut preparation cannot damage")
		var segment: Dictionary = motion.advance(attack.active + 0.002)
		_check(segment.active and segment.damage_ready, "side cut damage follows its swept active window")
		_near(absf(segment.current_angle - segment.previous_angle), 2.3 if index == 0 else 2.4, "side cut sweeps the authored arc")
		_check(segment.current_angle < segment.previous_angle if index == 0 else segment.current_angle > segment.previous_angle, "side cuts reverse direction from right to left, then left to right")
		_check(motion.is_target_hit(Vector3.ZERO, Vector3(attack.reach - 0.01, 0, 0), 0.0, segment.previous_angle, segment.current_angle), "full sweep reaches its visible blade tip")
		_check(not motion.is_target_hit(Vector3.ZERO, Vector3(attack.reach + 0.01, 0, 0), 0.0, segment.previous_angle, segment.current_angle), "side cut cannot hit beyond its authored reach")
		_check(not motion.advance(0.01).damage_ready, "side cut recovery cannot damage")
		var pose: Dictionary = motion.sample()
		_near(pose.radius + cos(pose.pitch) * pose.blade_length, attack.reach, "side cut uses a rigid horizontal blade")
	var sword = motion_script.new()
	sword.start(0, 0.0)
	_check(sword.advance(0.2).damage_ready, "legacy sword damage_ready mirrors active")

func _test_overhead_pose_and_impact_window() -> void:
	var motion = _great()
	motion.start(2, 0.0)
	var prep: Dictionary = motion.advance(0.25)
	var overhead: Dictionary = motion.sample()
	_check(prep.active and not prep.damage_ready, "slam active entrance does not yet hit")
	_near(overhead.pitch, 1.25, "slam raises blade above head")
	_near(overhead.grip_height, 2.55, "overhead preparation raises hands above the character head")
	_near(overhead.blade_length, 2.475, "greatsword is one rigid extended blade")
	_check(not motion.advance(0.0974).damage_ready, "slam downstroke cannot damage before ground contact")
	var impact: Dictionary = motion.advance(0.0001)
	_check(impact.damage_ready, "slam damages at 0.3475 second contact")
	var pose: Dictionary = motion.sample()
	_near(pose.grip_height + sin(pose.pitch) * pose.blade_length, 0.0, "visible blade tip reaches the ground at damage time")
	var ground_reach: float = pose.radius + sqrt(pose.blade_length * pose.blade_length - pose.grip_height * pose.grip_height)
	_near(pose.radius + cos(pose.pitch) * pose.blade_length, ground_reach, "impact reach matches actual blade ground tip")
	_near(motion.definition(2).reach, ground_reach, "slam collision reach follows ground geometry")
	_check(motion.definition(2).kind == "slam", "overhead has its own straight collision kind")
	_check(not motion.advance(0.01).damage_ready, "continuing impact frame does not repeat damage")
	_check(not motion.advance(-1.0).damage_ready and not motion.advance(NAN).damage_ready, "invalid time never produces impact")
	var cross = _great()
	cross.start(2, 0.0)
	cross.advance(0.33)
	_check(cross.advance(0.3).damage_ready, "step spanning contact into recovery retains slam damage")

func _test_narrow_slam_geometry_at_cardinal_aims() -> void:
	for aim in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var motion = _great()
		motion.start(2, aim)
		motion.advance(0.3475)
		# Ignore caller sweep angles: slam collision stays on the locked forward line.
		var origin := Vector3(3, 0, -4)
		var forward := Vector3(cos(aim), 0, sin(aim))
		var side := Vector3(-sin(aim), 0, cos(aim))
		var reach: float = motion.definition(2).reach
		_check(motion.is_target_hit(origin, origin + forward * (reach - 0.01), 0.0, aim - 1.5, aim + 1.5), "straight overhead reaches its ground tip at cardinal aim")
		_check(motion.is_target_hit(origin, origin + forward * 1.4 + side * 0.32, 0.0, aim, aim), "slam includes its narrow 0.65 lane")
		_check(not motion.is_target_hit(origin, origin + forward * 1.4 + side * 0.34, 0.0, aim - 1.5, aim + 1.5), "slam misses beside the narrow lane despite wide caller arc")
		_check(not motion.is_target_hit(origin, origin + forward * (reach + 0.01), 0.0, aim, aim), "slam cannot damage beyond actual ground tip")
		_check(motion.is_target_hit(origin, origin + forward * (reach + 0.075), 0.1, aim, aim), "enemy radius can overlap the bounded front edge")
		_check(not motion.is_target_hit(origin, origin - forward * 0.05, 0.0, aim, aim), "slam cannot damage behind the hero")
		_check(not motion.is_target_hit(origin, origin + forward * (reach + 0.075) + side * 0.40, 0.08, aim, aim), "slam front corner uses circle distance rather than independent padding")

func _test_chain_pose_continuity_at_cardinal_aims() -> void:
	for aim in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var motion = _great()
		for index in range(3):
			var held: Dictionary = motion.sample()
			motion.start(index, aim)
			if index > 0:
				_assert_same_pose(motion.sample(), held, "starting next strike keeps previous end pose")
			var attack: Dictionary = motion.definition(index)
			if index == 2:
				motion.advance(0.00001)
				_check(absf(wrapf(motion.sample().angle - held.angle, -PI, PI)) < 0.001, "overhead preparation begins continuously from reverse cut")
				motion.advance(attack.windup - 0.00002)
				var raised: Dictionary = motion.sample()
				motion.advance(0.00002)
				_assert_same_pose(motion.sample(), raised, "windup passes continuously into overhead downstroke", 0.002)
				motion.advance(1.0)
			else:
				motion.advance(attack.windup + attack.active + attack.recovery - 0.00001)
				var before_idle: Dictionary = motion.sample()
				motion.advance(0.00001)
				_assert_same_pose(motion.sample(), before_idle, "recovery passes continuously into held idle", 0.002)
				_check(absf(wrapf(motion.sample().angle - (aim + 0.35), -PI, PI)) > 0.5, "side cut keeps its momentum end pose instead of idle rest")
				var end: Dictionary = motion.sample()
				motion.advance(2.0)
				_assert_same_pose(motion.sample(), end, "idle preserves last end pose until next start or reset")

func _assert_same_pose(actual: Dictionary, expected: Dictionary, message: String, tolerance := 0.0001) -> void:
	_check(absf(wrapf(actual.angle - expected.angle, -PI, PI)) < tolerance and absf(actual.pitch - expected.pitch) < tolerance and absf(actual.grip_height - expected.grip_height) < tolerance and absf(actual.radius - expected.radius) < tolerance, message)

func _test_body_relative_sweep_direction() -> void:
	# Actor right is independent of screen projection and remains correct at all aims.
	for aim in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var right := Vector3(cos(aim), 0, sin(aim)).cross(Vector3.UP)
		for index in range(2):
			var motion = _great()
			motion.start(index, aim)
			var attack: Dictionary = motion.definition(index)
			motion.advance(attack.windup)
			var before: Dictionary = motion.sample()
			var before_direction := Vector3(cos(before.angle), 0, sin(before.angle))
			motion.advance(attack.active)
			var after: Dictionary = motion.sample()
			var after_direction := Vector3(cos(after.angle), 0, sin(after.angle))
			_check(before_direction.dot(right) > 0.5 if index == 0 else before_direction.dot(right) < -0.5, "first cut begins on actor right; second begins on actor left")
			_check(after_direction.dot(right) < -0.5 if index == 0 else after_direction.dot(right) > 0.5, "first cut ends on actor left; second ends on actor right")

func _test_idle_aim_rebases_held_pose() -> void:
	for index in range(3):
		var motion = _great()
		motion.start(index, 3.05)
		motion.advance(2.0)
		var held: Dictionary = motion.sample()
		_check(motion.rebase_idle_aim(-3.05), "idle pose can turn through the angle wrap seam")
		var rebased: Dictionary = motion.sample()
		_near(rebased.angle - held.angle, TAU - 6.1, "held pose turns through the short angle delta")
		_near(wrapf(rebased.angle - (-3.05), -PI, PI), wrapf(held.angle - 3.05, -PI, PI), "turning aim preserves the body-relative end pose")
		_near(rebased.pitch, held.pitch, "aim rebasing preserves blade pitch")
		_near(rebased.grip_height, held.grip_height, "aim rebasing preserves grip height")
		_near(rebased.radius, held.radius, "aim rebasing preserves grip radius")
		_near(motion.aim_angle, -3.05, "rebasing updates exposed locked aim")
		_check(not motion.rebase_idle_aim(NAN) and not motion.rebase_idle_aim(INF), "nonfinite idle aim is refused")
		_assert_same_pose(motion.sample(), rebased, "invalid aim leaves held pose unchanged")
		motion.start((index + 1) % 3, -3.05)
		_assert_same_pose(motion.sample(), rebased, "next attack starts from the rebased held pose")
		motion.advance(0.05)
		var locked: Dictionary = motion.sample()
		_check(not motion.rebase_idle_aim(0.0), "busy attack refuses aim rebasing")
		_assert_same_pose(motion.sample(), locked, "busy refusal preserves in-flight pose")
		_near(motion.aim_angle, -3.05, "busy refusal preserves locked attack aim")
	var fresh = _great()
	fresh.rebase_idle_aim(PI * 0.5)
	_near(fresh.sample().angle, PI * 0.5 + 0.35, "unstarted idle pose follows aim")
