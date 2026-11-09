extends SceneTree

var checks := 0
var failures: Array[String] = []
var motion_script: Script

func _initialize() -> void:
	_check(FileAccess.file_exists("res://scripts/staff_motion.gd"), "staff motion module exists")
	if failures.is_empty():
		motion_script = load("res://scripts/staff_motion.gd")
		_test_single_release_and_rhythm()
		_test_large_steps_and_subdivision()
		_test_cardinal_aim_and_rigid_pose()
		_test_phase_continuity_and_repeat()
		_test_guards_pause_and_reset()
	if failures.is_empty():
		print("PASS: staff motion (%d checks)" % checks)
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

func _test_single_release_and_rhythm() -> void:
	# Catches early/repeated projectile emission and accidental melee dispatch.
	var motion = _motion()
	var attack: Dictionary = motion.definition(0)
	_check(attack.kind == "projectile" and attack.element == "fire", "shot explicitly dispatches a fire projectile")
	_near(attack.damage, 72.0, "projectile consumer receives direct fire damage")
	_near(attack.reach, 6.0, "range indicator receives finite projectile reach")
	_near(attack.projectile_range, 6.0, "projectile travel is bounded")
	_near(attack.projectile_speed, 5.5, "projectile consumer receives flight speed")
	_near(attack.projectile_radius, 0.18, "projectile consumer receives collision radius")
	_near(attack.knockback, 1.4, "projectile contact receives modest knockback")
	_near(attack.windup, 0.28, "release waits for the committed windup")
	_near(attack.active, 0.10, "release pose has a short active hold")
	_near(attack.recovery, 0.82, "recovery controls held-fire repeat rhythm")
	_check(motion.start(0, 0.4), "single click starts one committed shot")
	_check(motion.busy and motion.stage == 0, "public state exposes the committed shot")
	_near(motion.aim_angle, 0.4, "public state exposes shot aim")
	var before: Dictionary = motion.advance(0.2799)
	_check(not before.projectile_ready and not before.entered_active and not before.damage_ready, "windup cannot release or damage early")
	_check(before.release_pose.is_empty(), "nonrelease steps carry no muzzle snapshot")
	var release: Dictionary = motion.advance(0.0001)
	_check(release.projectile_ready and release.entered_active and release.active, "crossing 0.28 seconds releases exactly once")
	_check(not release.damage_ready, "fire shot never emits melee damage")
	_check(release.release_pose.phase == "active", "release snapshot represents exact active entrance")
	_near(release.release_pose.progress, 0.0, "release snapshot is captured at the release instant")
	_near(release.release_pose.pitch, 0.60, "muzzle presents staff forward at release")
	_near(release.release_pose.radius, 0.38, "muzzle release uses extended hand position")
	_near(release.previous_angle, 0.4, "release previous angle is shot aim")
	_near(release.current_angle, 0.4, "release current angle is shot aim")
	var active: Dictionary = motion.advance(0.05)
	_check(active.active and not active.entered_active and not active.projectile_ready, "continued active pose does not spawn another projectile")
	_check(not active.damage_ready and active.release_pose.is_empty(), "continued active pose carries no damage or release snapshot")
	motion.advance(0.05)
	_check(motion.sample().phase == "recovery" and motion.busy, "active ends at 0.38 without ending recovery")
	_check(not motion.start(0, 0.4), "hold-repeat cannot interrupt recovery")
	var done: Dictionary = motion.advance(0.82)
	_check(done.finished and not done.projectile_ready and not motion.busy, "single shot finishes at 1.20 seconds")
	_near(motion.elapsed, 1.20, "elapsed clamps to the full shot duration")
	_check(motion.stage == 0 and motion.sample().phase == "idle", "terminal state retains shot stage while returning to idle")
	var idle: Dictionary = motion.advance(9.0)
	_check(not idle.projectile_ready and not idle.finished and not idle.active and not idle.damage_ready, "idle produces no duplicate event")
	attack.damage = 999.0
	_near(motion.definition(0).damage, 72.0, "consumer mutation cannot change the next shot definition")

func _test_large_steps_and_subdivision() -> void:
	# Catches a skipped release when a frame jumps over active or entire attack.
	for step in [0.28, 0.3, 1.20, 20.0, 1.0e300]:
		var whole = _motion()
		whole.start(0, -0.6)
		var release: Dictionary = whole.advance(step)
		_check(release.projectile_ready and release.entered_active and release.active, "large delta retains crossed release interval")
		_check(not release.damage_ready, "large delta cannot convert shot into melee damage")
		_near(release.release_pose.angle, -0.6, "large delta retains release aim")
		_near(release.release_pose.pitch, 0.60, "large delta snapshot uses release pitch rather than final pose")
		_near(release.release_pose.radius, 0.38, "large delta snapshot uses release radius rather than final pose")
		_near(release.release_pose.grip_height, 0.76, "large delta snapshot retains muzzle height")
		_check(not whole.advance(2.0).projectile_ready, "postovershoot recovery cannot duplicate projectile")
		_near(whole.elapsed, 1.20, "large delta remains bounded at terminal elapsed")
	for dt in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0]:
		var motion = _motion()
		motion.start(0, 0.8)
		var releases := 0
		var finishes := 0
		var guard := 0
		while motion.busy and guard < 400:
			var event: Dictionary = motion.advance(dt)
			releases += 1 if event.projectile_ready else 0
			finishes += 1 if event.finished else 0
			_check(not event.damage_ready, "every frame subdivision excludes melee damage")
			if event.projectile_ready:
				_near(event.release_pose.pitch, 0.60, "every subdivision uses exact release instant")
				_near(event.release_pose.radius, 0.38, "every subdivision uses exact muzzle extension")
			guard += 1
		_check(releases == 1 and finishes == 1 and not motion.busy, "all frame rates emit one shot and one completion")
		_near(motion.elapsed, 1.20, "all frame rates end at the same time")
		_near(motion.sample().pitch, 1.1, "all frame rates recover to rest")

func _test_cardinal_aim_and_rigid_pose() -> void:
	# Catches a rotating committed shot, telescoping staff and melee contact.
	for aim in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var motion = _motion()
		_check(motion.rebase_idle_aim(aim), "idle staff accepts each cardinal aim")
		var rest: Dictionary = motion.sample()
		_near(wrapf(rest.angle - aim, -PI, PI), 0.0, "idle points at aim without sword rest offset")
		_near(rest.pitch, 1.1, "idle holds the staff upright")
		_near(rest.radius, 0.28, "idle keeps the staff close to the hand")
		_near(rest.grip_height, 0.72, "idle staff grip uses heroine hand height")
		motion.start(0, aim)
		motion.aim_angle = NAN
		var guard := 0
		while motion.busy and guard < 400:
			motion.advance(1.0 / 240.0)
			var pose: Dictionary = motion.sample()
			_assert_finite_pose(pose)
			_near(wrapf(pose.angle - aim, -PI, PI), 0.0, "committed shot ignores public aim mutation")
			_near(pose.blade_length, 1.45, "every phase retains a rigid staff")
			var grip := Vector3(cos(pose.angle) * pose.radius, pose.grip_height, sin(pose.angle) * pose.radius)
			var tip: Vector3 = grip + Vector3(cos(pose.angle) * cos(pose.pitch), sin(pose.pitch), sin(pose.angle) * cos(pose.pitch)) * pose.blade_length
			_near(grip.distance_to(tip), 1.45, "rendered grip-to-head length stays rigid in all four directions")
			_check(not pose.trail and absf(pose.body_lean) <= 0.06, "firing uses subtle body motion with no sword trail")
			_near(pose.lunge_offset, 0.0, "staff never moves the actor forward")
			_check(not motion.is_target_hit(Vector3.ZERO, Vector3(cos(aim), 0.0, sin(aim)), 2.0, aim - 1.0, aim + 1.0), "staff cannot hit nearby monsters through melee geometry")
			guard += 1
		_check(not motion.busy, "cardinal shot terminates")
		_near(wrapf(motion.sample().angle - aim, -PI, PI), 0.0, "terminal idle retains last committed direction")

func _test_phase_continuity_and_repeat() -> void:
	# Catches abrupt pose snaps at lift/release/recovery and automatic combo use.
	for boundary in [0.063, 0.28, 0.38, 1.20]:
		var motion = _motion()
		motion.rebase_idle_aim(0.5)
		var rest: Dictionary = motion.sample()
		motion.start(0, 0.5)
		_assert_pose(motion.sample(), rest, "shot starts at existing idle pose")
		motion.advance(boundary - 0.000001)
		var before: Dictionary = motion.sample()
		motion.advance(0.000002)
		_assert_pose(motion.sample(), before, "authored phase boundary has continuous physical pose", 0.001)
	var repeat = _motion()
	repeat.start(0, 0.1)
	repeat.advance(0.063)
	_near(repeat.sample().pitch, 1.25, "small preparation raise precedes forward release")
	repeat.advance(2.0)
	var settled: Dictionary = repeat.sample()
	_check(repeat.rebase_idle_aim(-2.4), "idle may refresh aim for a repeated shot")
	_near(repeat.sample().pitch, settled.pitch, "fresh idle aim preserves recovered pitch")
	_near(wrapf(repeat.sample().angle + 2.4, -PI, PI), 0.0, "idle refresh takes the next shot direction")
	var rebased: Dictionary = repeat.sample()
	_check(repeat.start(0, -2.4), "held-fire consumer can repeat the same stage after completion")
	_assert_pose(repeat.sample(), rebased, "repeated firing begins continuously from recovered pose")
	var next: Dictionary = repeat.advance(0.28)
	_check(next.projectile_ready, "each new start has exactly one fresh release")
	_near(next.release_pose.angle, -2.4, "repeat uses fresh aim without changing previous shot")
	next.release_pose.pitch = 99.0
	_near(repeat.sample().pitch, 0.60, "release snapshot mutation cannot corrupt live pose")

func _test_guards_pause_and_reset() -> void:
	# Catches invalid-input corruption, paused release repeats and stale reset events.
	var motion = _motion()
	for index in [-2, -1, 1, 2, 3, 99]:
		_check(not motion.start(index, 0.0), "only basic stage zero may start")
		_check(motion.definition(index).is_empty(), "unsupported stages have no projectile definition")
	for angle in [NAN, INF, -INF]:
		_check(not motion.start(0, angle), "nonfinite shot aim is refused")
		_check(not motion.rebase_idle_aim(angle), "nonfinite idle aim is refused")
	_check(not motion.busy and motion.stage == -1, "rejected input leaves initial state intact")
	_check(motion.rebase_idle_aim(1.0e300), "finite wrapped aim is accepted")
	_assert_finite_pose(motion.sample())
	_check(motion.start(0, 0.7), "valid shot starts after rejected inputs")
	motion.advance(0.1)
	var before: Dictionary = motion.sample()
	_check(not motion.start(0, -0.4), "committed attack refuses replacement")
	_check(not motion.rebase_idle_aim(-0.4), "committed attack refuses idle steering")
	for dt in [0.0, -0.1, NAN, INF, -INF]:
		var event: Dictionary = motion.advance(dt)
		_check(not event.projectile_ready and not event.entered_active and not event.active and not event.damage_ready and not event.finished, "paused or invalid delta emits no event")
		_check(event.release_pose.is_empty(), "paused delta carries no stale release pose")
	_near(motion.elapsed, 0.1, "paused and invalid deltas preserve committed time")
	_assert_pose(motion.sample(), before, "paused and invalid deltas preserve physical pose")
	motion.reset()
	_check(not motion.busy and motion.stage == -1, "reset cancels committed shot")
	_near(motion.elapsed, 0.0, "reset clears shot time")
	_near(motion.aim_angle, 0.0, "reset clears exposed aim")
	_near(motion.sample().angle, 0.0, "reset clears physical aim")
	_check(not motion.advance(3.0).projectile_ready, "reset cannot emit a delayed projectile")
	_check(motion.start(0, -0.7), "reset permits another basic shot")
	_check(motion.advance(0.28).projectile_ready, "new shot releases after reset")
	_check(not motion.advance(0.0).projectile_ready, "pause at release does not repeat the shot")
	motion.reset()
	_check(not motion.advance(2.0).projectile_ready, "reset after release clears the old event")
	_check(not motion.is_target_hit(Vector3(INF, 0, 0), Vector3(NAN, 0, 0), NAN, NAN, INF), "staff has no melee contact even for malformed collision input")

func _assert_finite_pose(pose: Dictionary) -> void:
	for key in ["progress", "angle", "pitch", "radius", "grip_height", "blade_length", "body_lean", "lunge_offset"]:
		_check(is_finite(float(pose[key])), "pose field %s remains finite" % key)

func _assert_pose(actual: Dictionary, expected: Dictionary, message: String, tolerance := 0.0001) -> void:
	_check(absf(wrapf(actual.angle - expected.angle, -PI, PI)) < tolerance and absf(actual.pitch - expected.pitch) < tolerance and absf(actual.grip_height - expected.grip_height) < tolerance and absf(actual.radius - expected.radius) < tolerance and absf(actual.body_lean - expected.body_lean) < tolerance, message)
