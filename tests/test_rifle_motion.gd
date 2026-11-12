extends SceneTree

var checks := 0
var failures: Array[String] = []
var motion_script: Script

func _initialize() -> void:
	_check(FileAccess.file_exists("res://scripts/rifle_motion.gd"), "rifle motion module exists")
	if failures.is_empty():
		motion_script = load("res://scripts/rifle_motion.gd")
		_test_release_and_cadence()
		_test_large_steps_and_subdivision()
		_test_recoil_curve_and_frame_invariance()
		_test_locked_aim_and_rigid_pose()
		_test_continuity_and_repeat()
		_test_guards_pause_and_reset()
	if failures.is_empty():
		print("PASS: rifle motion (%d checks)" % checks)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _near(actual: float, expected: float, message: String, tolerance := 0.0001) -> void:
	_check(is_finite(actual) and absf(actual - expected) < tolerance, "%s (got %.6f, expected %.6f)" % [message, actual, expected])

func _motion():
	return motion_script.new()

func _test_release_and_cadence() -> void:
	# Catches wrong projectile payload, early/repeated fire and melee dispatch.
	var motion = _motion()
	var attack: Dictionary = motion.definition(0)
	_check(attack.kind == "projectile" and attack.element == "physical", "release dispatches one physical projectile")
	_near(attack.damage, 52.0, "projectile consumer receives the rifle's base damage")
	_near(attack.reach, 9.0, "range indicator receives rifle reach")
	_near(attack.projectile_range, 9.0, "bullet travel is bounded")
	_near(attack.projectile_speed, 22.0, "projectile consumer receives visible flight speed")
	_near(attack.projectile_radius, 0.10, "projectile consumer receives swept radius")
	_near(attack.knockback, 2.0, "projectile consumer receives rifle knockback")
	_near(attack.pierce_after_exit, 0.55, "projectile consumer receives bounded penetration beyond first exit")
	_check(attack.magazine_capacity == 5, "caller configures five round magazine")
	_near(attack.reload_time, 1.2, "caller configures longer reload")
	_near(attack.windup, 0.16, "shot has a committed windup")
	_near(attack.active, 0.08, "shot has a short active interval")
	_near(attack.recovery, 0.66, "recovery controls slow repetition")
	_near(attack.recoil_distance, 0.22, "caller receives backward movement budget")
	_near(attack.recoil_duration, 0.12, "caller receives backward movement duration")
	_check(motion.start(0, 0.4), "single click starts the basic shot")
	_check(motion.busy and motion.stage == 0, "public state exposes committed shot")
	_near(motion.aim_angle, 0.4, "public state exposes shot aim")
	var before: Dictionary = motion.advance(0.1599)
	_assert_result(before)
	_check(not before.projectile_ready and not before.entered_active and not before.damage_ready, "windup cannot release or damage early")
	_check(before.release_pose.is_empty(), "nonrelease steps carry no muzzle snapshot")
	var release: Dictionary = motion.advance(attack.windup - motion.elapsed)
	_assert_result(release)
	_check(release.projectile_ready and release.entered_active and release.active, "crossing 0.16 seconds releases once")
	_check(not release.damage_ready, "rifle never emits melee damage")
	_check(release.release_pose.phase == "active", "release snapshot represents exact active entrance")
	_near(release.release_pose.progress, 0.0, "release snapshot captures exact release instant")
	_assert_rest_geometry(release.release_pose, "release")
	_near(release.release_pose.recoil_offset, 0.0, "release snapshot precedes backward movement")
	_near(release.previous_angle, 0.4, "event previous angle is locked aim")
	_near(release.current_angle, 0.4, "event current angle is locked aim")
	var active: Dictionary = motion.advance(0.04)
	_check(active.active and not active.projectile_ready and not active.entered_active, "active recoil cannot create another bullet")
	_check(not active.damage_ready and active.release_pose.is_empty(), "continued recoil carries no stale release")
	_check(motion.sample().pitch > 0.0 and motion.sample().pitch <= 0.13, "recoil lifts the barrel subtly after release")
	motion.advance(0.04)
	_check(motion.sample().phase == "recovery" and motion.busy, "recovery starts at 0.24 seconds")
	_near(motion.sample().pitch, 0.13, "barrel lift reaches its small peak at recovery")
	_check(not motion.start(0, -1.0), "repeat cannot interrupt recovery")
	motion.advance(0.6599)
	_check(motion.busy and not motion.start(0, -1.0), "slow cadence remains committed before 0.90 seconds")
	var done: Dictionary = motion.advance(attack.windup + attack.active + attack.recovery - motion.elapsed)
	_check(done.finished and not done.projectile_ready and not motion.busy, "shot finishes at 0.90 seconds")
	_near(motion.elapsed, 0.90, "elapsed clamps to full shot duration")
	_check(motion.stage == 0 and motion.sample().phase == "idle", "terminal state retains stage and returns to idle")
	_assert_rest_geometry(motion.sample(), "recovered")
	_near(motion.sample().recoil_offset, 0.22, "terminal idle retains final recoil budget for caller")
	var idle: Dictionary = motion.advance(5.0)
	_assert_result(idle)
	_check(not idle.projectile_ready and not idle.finished and not idle.active and not idle.damage_ready, "idle emits no duplicate event")
	attack.damage = 999.0
	attack.magazine_capacity = 999
	attack.recoil_distance = 999.0
	_near(motion.definition(0).damage, 52.0, "consumer cannot mutate future projectile damage")
	_check(motion.definition(0).magazine_capacity == 5, "consumer cannot mutate future magazine configuration")
	_near(motion.definition(0).recoil_distance, 0.22, "consumer cannot mutate future movement budget")

func _test_large_steps_and_subdivision() -> void:
	# Catches skipped or stale release pose when a frame crosses the whole shot.
	for step in [0.16, 0.20, 0.90, 20.0, 1.0e300]:
		var motion = _motion()
		motion.start(0, -0.6)
		var event: Dictionary = motion.advance(step)
		_assert_result(event)
		_check(event.projectile_ready and event.entered_active and event.active, "large step retains crossed release")
		_check(not event.damage_ready, "large step never converts bullet to melee")
		_near(event.release_pose.angle, -0.6, "large step retains release aim")
		_near(event.release_pose.progress, 0.0, "large step uses exact release time")
		_near(event.release_pose.recoil_offset, 0.0, "large step snapshots zero release recoil")
		_assert_rest_geometry(event.release_pose, "overshoot release")
		_check(not motion.advance(2.0).projectile_ready, "postovershoot step cannot repeat bullet")
		_near(motion.elapsed, 0.90, "overshoot remains bounded")
		_near(motion.sample().recoil_offset, 0.22, "overshoot preserves full movement budget")
	for dt in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0]:
		var motion = _motion()
		motion.start(0, 0.8)
		var releases := 0
		var finishes := 0
		var guard := 0
		while motion.busy and guard < 300:
			var event: Dictionary = motion.advance(dt)
			releases += 1 if event.projectile_ready else 0
			finishes += 1 if event.finished else 0
			_check(not event.damage_ready, "every frame subdivision excludes melee damage")
			if event.projectile_ready:
				_assert_rest_geometry(event.release_pose, "subdivided release")
			guard += 1
		_check(releases == 1 and finishes == 1 and not motion.busy, "each frame rate emits one bullet and completion")
		_near(motion.elapsed, 0.90, "frame rates share terminal time")
		_assert_rest_geometry(motion.sample(), "subdivided rest")
		_near(motion.sample().recoil_offset, 0.22, "subdivided completion retains movement budget")

func _test_recoil_curve_and_frame_invariance() -> void:
	# Catches motion before release, frame-sized recoil and budget lost at completion.
	var cases := [
		[0.08, 0.0], [0.159, 0.0], [0.16, 0.0],
		[0.19, 0.034375], [0.22, 0.11], [0.25, 0.185625],
		[0.28, 0.22], [0.35, 0.22], [0.899, 0.22], [0.90, 0.22],
	]
	for dt in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0, 5.0]:
		var motion = _motion()
		motion.start(0, 1.2)
		var previous := 0.0
		for fixture in cases:
			_advance_to(motion, fixture[0], dt)
			var pose: Dictionary = motion.sample()
			_near(pose.recoil_offset, fixture[1], "recoil follows hand-checked smooth curve independently of frame size")
			_check(pose.recoil_offset >= previous and pose.recoil_offset <= 0.220001, "recoil is monotonic and bounded")
			_near(pose.lunge_offset, 0.0, "recoil never becomes a forward lunge")
			previous = pose.recoil_offset
		var idle: Dictionary = motion.advance(20.0)
		_check(not idle.projectile_ready and not idle.finished, "terminal budget cannot release again")
		_near(motion.sample().recoil_offset, 0.22, "idle preserves consumed terminal budget")

func _test_locked_aim_and_rigid_pose() -> void:
	# Catches steering during commitment, telescoping and actor/body movement.
	for direction in range(16):
		var aim := float(direction) * TAU / 16.0
		var motion = _motion()
		_check(motion.rebase_idle_aim(aim), "idle accepts every tested direction")
		_near(wrapf(motion.sample().angle - aim, -PI, PI), 0.0, "idle points directly at aim")
		_assert_rest_geometry(motion.sample(), "directional rest")
		motion.start(0, aim)
		motion.aim_angle = NAN
		var guard := 0
		while motion.busy and guard < 300:
			var event: Dictionary = motion.advance(1.0 / 240.0)
			_assert_result(event)
			var pose: Dictionary = motion.sample()
			_assert_finite_pose(pose)
			_near(wrapf(pose.angle - aim, -PI, PI), 0.0, "committed shot ignores public aim mutation")
			_near(pose.blade_length, 1.35, "every phase retains rigid grip-to-muzzle length")
			var grip := Vector3(cos(pose.angle) * pose.radius, pose.grip_height, sin(pose.angle) * pose.radius)
			var tip: Vector3 = grip + Vector3(cos(pose.angle) * cos(pose.pitch), sin(pose.pitch), sin(pose.angle) * cos(pose.pitch)) * pose.blade_length
			_near(grip.distance_to(tip), 1.35, "rendered muzzle remains rigid at every direction")
			_near(pose.radius, 0.42, "firing keeps attached hand radius fixed")
			_near(pose.grip_height, 0.80, "firing keeps attached hand height fixed")
			_near(pose.lunge_offset, 0.0, "rifle model never moves actor forward")
			_near(pose.body_lean, 0.0, "rifle model never moves actor body")
			_check(not pose.trail, "rifle excludes melee trail")
			_check(pose.pitch >= 0.0 and pose.pitch <= 0.130001, "barrel lift stays subtle")
			_check(not motion.is_target_hit(Vector3.ZERO, Vector3.ONE, 9.0, -PI, PI), "rifle cannot cause melee contact")
			guard += 1
		_check(not motion.busy, "directional shot terminates")
		_near(wrapf(motion.sample().angle - aim, -PI, PI), 0.0, "terminal idle retains committed direction")

func _test_continuity_and_repeat() -> void:
	# Catches release/recovery/idle snaps, stale release data and ammo/combo ownership.
	for boundary in [0.16, 0.24, 0.28, 0.90]:
		var motion = _motion()
		motion.rebase_idle_aim(0.5)
		var rest: Dictionary = motion.sample()
		motion.start(0, 0.5)
		_assert_pose(motion.sample(), rest, "shot starts continuously from idle")
		motion.advance(boundary - 0.000001)
		var before: Dictionary = motion.sample()
		motion.advance(0.000002)
		_assert_pose(motion.sample(), before, "phase boundary has continuous physical pose", 0.001)
		_near(motion.sample().recoil_offset, before.recoil_offset, "phase boundary has continuous recoil", 0.001)
	var repeat = _motion()
	repeat.start(0, 0.1)
	var first: Dictionary = repeat.advance(0.16)
	first.release_pose.pitch = 99.0
	first.release_pose.recoil_offset = 99.0
	_near(repeat.sample().pitch, 0.0, "release snapshot mutation cannot corrupt barrel pose")
	_near(repeat.sample().recoil_offset, 0.0, "release snapshot mutation cannot corrupt recoil budget")
	repeat.advance(2.0)
	_check(repeat.start(0, 0.1), "new start can rebase terminal recoil without an idle aim call")
	_near(repeat.sample().recoil_offset, 0.0, "new start begins a fresh cumulative recoil budget")
	_near(repeat.sample().lunge_offset, 0.0, "new start never commands a compensating lunge")
	repeat.advance(2.0)
	_check(repeat.rebase_idle_aim(-2.4), "idle accepts fresh direction for next shot")
	var rebased: Dictionary = repeat.sample()
	_near(rebased.recoil_offset, 0.0, "idle aim rebase clears stale recoil budget")
	_assert_rest_geometry(rebased, "rebased idle")
	for shot in range(7):
		_check(repeat.start(0, -2.4), "caller can start every repeated shot regardless of magazine bookkeeping")
		_assert_pose(repeat.sample(), rebased, "repeated shot starts from recovered physical pose")
		var next: Dictionary = repeat.advance(0.16)
		_check(next.projectile_ready and not next.damage_ready, "each new start emits one physical projectile")
		_near(next.release_pose.angle, -2.4, "new shot uses refreshed aim")
		_near(next.release_pose.recoil_offset, 0.0, "each release has fresh cumulative budget")
		_check(not repeat.start(0, -2.4), "held firing cannot bypass commitment")
		var finish: Dictionary = repeat.advance(0.74)
		_check(finish.finished and not finish.projectile_ready, "each repeated cycle finishes after 0.90 seconds")

func _test_guards_pause_and_reset() -> void:
	# Catches invalid input corruption, paused release repeats and stale reset budget.
	var motion = _motion()
	for index in [-2, -1, 1, 2, 3, 99]:
		_check(not motion.start(index, 0.0), "only basic stage zero can start")
		_check(motion.definition(index).is_empty(), "unsupported stages have no definition")
	for angle in [NAN, INF, -INF]:
		_check(not motion.start(0, angle), "nonfinite shot aim is refused")
		_check(not motion.rebase_idle_aim(angle), "nonfinite idle aim is refused")
	_check(not motion.busy and motion.stage == -1, "invalid starts leave initial state intact")
	_check(motion.rebase_idle_aim(1.0e300), "finite large aim wraps safely")
	_assert_finite_pose(motion.sample())
	_check(motion.start(0, 0.7), "valid start works after invalid input")
	motion.advance(0.02)
	var before: Dictionary = motion.sample()
	_check(not motion.start(0, -0.4), "busy shot refuses replacement")
	_check(not motion.rebase_idle_aim(-0.4), "busy shot refuses steering")
	for dt in [0.0, -0.1, NAN, INF, -INF]:
		var event: Dictionary = motion.advance(dt)
		_assert_result(event)
		_check(not event.projectile_ready and not event.entered_active and not event.active and not event.damage_ready and not event.finished, "paused or invalid delta emits no event")
		_check(event.release_pose.is_empty(), "paused step has no stale release pose")
	_near(motion.elapsed, 0.02, "invalid and paused steps preserve time")
	_assert_pose(motion.sample(), before, "invalid and paused steps preserve pose")
	motion.reset()
	_check(not motion.busy and motion.stage == -1, "reset cancels shot")
	_near(motion.elapsed, 0.0, "reset clears time")
	_near(motion.aim_angle, 0.0, "reset clears exposed aim")
	_near(motion.sample().angle, 0.0, "reset clears physical aim")
	_near(motion.sample().recoil_offset, 0.0, "reset clears movement budget")
	_check(not motion.advance(3.0).projectile_ready, "reset cannot emit delayed bullet")
	_check(motion.start(0, -0.7), "reset permits fresh shot")
	_check(motion.advance(0.16).projectile_ready, "fresh shot releases after reset")
	_check(not motion.advance(0.0).projectile_ready, "pause at release cannot repeat shot")
	motion.advance(0.06)
	var recoil_before: Dictionary = motion.sample()
	for dt in [0.0, -1.0, NAN, INF, -INF]:
		motion.advance(dt)
		_near(motion.sample().recoil_offset, recoil_before.recoil_offset, "paused or invalid steps freeze cumulative recoil")
	motion.reset()
	_check(not motion.advance(2.0).projectile_ready, "reset after release clears old event")
	_near(motion.sample().recoil_offset, 0.0, "reset after release cannot retain movement")
	_check(not motion.is_target_hit(Vector3(INF, 0, 0), Vector3(NAN, 0, 0), NAN, NAN, INF), "malformed geometry never creates melee hit")

func _advance_to(motion, target: float, step: float) -> void:
	while motion.elapsed < target:
		motion.advance(minf(step, target - motion.elapsed))

func _assert_result(event: Dictionary) -> void:
	for key in ["entered_active", "active", "damage_ready", "projectile_ready", "finished", "previous_angle", "current_angle", "release_pose", "contact_pose"]:
		_check(event.has(key), "advance result retains standard key " + key)
	_near(event.previous_angle, event.current_angle, "result angle remains locked")
	_check(event.contact_pose.is_empty(), "rifle never supplies melee contact pose")

func _assert_rest_geometry(pose: Dictionary, message: String) -> void:
	_near(pose.pitch, 0.0, message + " pitch faces forward")
	_near(pose.radius, 0.42, message + " hand radius")
	_near(pose.grip_height, 0.80, message + " hand height")
	_near(pose.blade_length, 1.35, message + " rigid muzzle length")
	_near(pose.lunge_offset, 0.0, message + " excludes forward movement")
	_near(pose.body_lean, 0.0, message + " excludes actor body movement")

func _assert_finite_pose(pose: Dictionary) -> void:
	for key in ["progress", "angle", "pitch", "radius", "grip_height", "blade_length", "body_lean", "lunge_offset", "recoil_offset"]:
		_check(is_finite(float(pose[key])), "pose field %s remains finite" % key)

func _assert_pose(actual: Dictionary, expected: Dictionary, message: String, tolerance := 0.0001) -> void:
	_check(absf(wrapf(actual.angle - expected.angle, -PI, PI)) < tolerance and absf(actual.pitch - expected.pitch) < tolerance and absf(actual.grip_height - expected.grip_height) < tolerance and absf(actual.radius - expected.radius) < tolerance and absf(actual.body_lean - expected.body_lean) < tolerance, message)
