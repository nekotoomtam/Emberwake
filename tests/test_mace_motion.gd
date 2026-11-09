extends SceneTree

var checks := 0
var failures: Array[String] = []
var motion_script: Script

func _initialize() -> void:
	motion_script = load("res://scripts/weapon_motion.gd")
	var probe = motion_script.new()
	_check(FileAccess.file_exists("res://scripts/mace_motion.gd"), "mace motion module exists")
	_check(probe.set_family("mace"), "wrapper selects mace family")
	if failures.is_empty():
		_test_rhythm_and_contact_pulses()
		_test_contact_geometry()
		_test_sword_reach_parity_and_boundaries()
		_test_rigid_length_through_all_phases()
		_test_lunge_budget_and_subdivision()
		_test_chain_and_reaim_continuity()
		_test_invalid_inputs_and_dispatch()
	if failures.is_empty():
		print("PASS: mace motion (%d checks)" % checks)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _near(actual: float, expected: float, message: String, tolerance := 0.0001) -> void:
	_check(absf(actual - expected) < tolerance, "%s (got %.6f, expected %.6f)" % [message, actual, expected])

func _mace():
	var motion = motion_script.new()
	motion.set_family("mace")
	return motion

func _test_rhythm_and_contact_pulses() -> void:
	# Catches wrong timing, damage dispatch and active-window repeat damage.
	var totals := [0.57, 0.32, 0.63]
	var damage := [34.0, 12.0, 46.0]
	var contacts := [0.29177482523, 0.154, 0.345]
	var kinds := ["lift", "lunge", "slam"]
	for index in range(3):
		var motion = _mace()
		var attack: Dictionary = motion.definition(index)
		_near(attack.damage, damage[index], "stage %d has its heavy/light damage" % index)
		_near(attack.windup + attack.active + attack.recovery, totals[index], "stage %d slow/quick/slow duration" % index)
		_check(attack.kind == kinds[index], "stage kind dispatches physical contact")
		_check(motion.start(index, 0.4), "start alone begins automatic attack")
		_check(not motion.advance(attack.windup).damage_ready, "active entrance cannot damage before contact")
		_check(not motion.advance(contacts[index] - attack.windup - 0.00001).damage_ready, "approaching physical contact cannot damage early")
		var impact: Dictionary = motion.advance(0.00002)
		_check(impact.active and impact.damage_ready, "crossing physical contact emits damage")
		_check(impact.contact_pose.phase == "active", "damage pulse carries physical contact pose")
		_check(not motion.advance(0.001).damage_ready, "continuing contact never repeats its pulse")
		var done: Dictionary = motion.advance(totals[index])
		_check(done.finished and not motion.busy and motion.sample().phase == "idle", "single click finishes without release or charge input")
		_check(not motion.advance(10.0).damage_ready, "finished attack cannot hit again")
		var whole = _mace()
		whole.start(index, 0.4)
		var large: Dictionary = whole.advance(20.0)
		_check(large.active and large.damage_ready and large.finished, "high dt retains contact while finishing attack")
		_assert_pose(large.contact_pose, impact.contact_pose, "large step carries exact contact rather than terminal idle pose")
		_near(whole.elapsed, totals[index], "public elapsed clamps to authored total")
		_near(whole.aim_angle, 0.4, "wrapper exposes committed aim")
		_check(whole.stage == index and not whole.busy, "wrapper exposes terminal state")
		_assert_pose(whole.sample(), motion.sample(), "subdivision preserves terminal pose")
		var clone: Dictionary = motion.definition(index)
		clone.damage = 999.0
		_near(motion.definition(index).damage, damage[index], "definition copy cannot mutate tuning")

func _test_contact_geometry() -> void:
	# Catches mismatched visual tip/collision reach and lane rotation errors.
	var contacts := [0.29177482523, 0.154, 0.345]
	var reaches := [2.1, 2.2, 2.55]
	var hand_radii := [0.2, 0.3, 0.764642892864]
	var knockback := [2.3, 0.8, 5.5]
	for aim in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var forward := Vector3(cos(aim), 0.0, sin(aim))
		var side := Vector3(-sin(aim), 0.0, cos(aim))
		var origin := Vector3(-4.0, 0.0, 7.0)
		for index in range(3):
			var motion = _mace()
			motion.start(index, aim)
			motion.advance(contacts[index])
			var pose: Dictionary = motion.sample()
			_near(pose.blade_length, 1.9, "mace remains a rigid 1.9 unit weapon")
			_near(pose.radius, hand_radii[index], "contact hand position gives the authored physical reach")
			_near(pose.radius + cos(pose.pitch) * pose.blade_length, reaches[index], "contact collision reaches visible rigid head")
			_near(motion.definition(index).reach, reaches[index], "attack reach matches physical contact")
			_near(motion.definition(index).knockback, knockback[index], "heavy/light contact applies bounded knockback")
			_near(wrapf(pose.angle - aim, -PI, PI), 0.0, "vertical strike follows committed cardinal aim")
			if index == 2:
				_near(pose.grip_height + sin(pose.pitch) * pose.blade_length, 0.0, "slam head touches ground at damage contact")
			else:
				_near(pose.pitch, 0.0, "lift and shove meet enemy at forward horizontal reach")
			_check(motion.is_target_hit(origin, origin + forward * (reaches[index] - 0.001), 0.0, aim - 2.0, aim + 2.0), "lane reaches physical head regardless of caller arc")
			_check(not motion.is_target_hit(origin, origin + forward * (reaches[index] + 0.01), 0.0, aim, aim), "lane cannot damage beyond physical reach")
			_check(motion.is_target_hit(origin, origin + forward * 1.0 + side * 0.349, 0.0, aim, aim), "lane includes authored 0.7 width")
			_check(not motion.is_target_hit(origin, origin + forward * 1.0 + side * 0.351, 0.0, aim, aim), "lane excludes target outside width")
			_check(not motion.is_target_hit(origin, origin - forward * 0.01, 0.0, aim, aim), "lane excludes targets behind hero")
			_check(motion.is_target_hit(origin, origin + forward * (reaches[index] + 0.05), 0.06, aim, aim), "target circle may overlap head endpoint")
			_check(not motion.is_target_hit(origin, origin + forward * (reaches[index] + 0.06) + side * 0.41, 0.08, aim, aim), "front corner uses circle distance rather than rectangular padding")
	var raised = _mace()
	raised.start(2, 0.0)
	raised.advance(0.24)
	_near(raised.sample().pitch, 1.25, "slam preparation raises head overhead")
	_near(raised.sample().grip_height, 2.3, "slam grip rises above head")

func _test_sword_reach_parity_and_boundaries() -> void:
	# Catches a long invisible lane, an unchanged old short lane, or reach drift
	# from the actual ordinary sword while preserving targets near the old edge.
	var old_reaches := [1.84, 1.8, 1.68995967676]
	for aim in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var origin := Vector3(3.0, 0.0, -2.0)
		var forward := Vector3(cos(aim), 0.0, sin(aim))
		for index in range(3):
			var sword = motion_script.new()
			sword.start(index, aim)
			var reference_reach: float = sword.definition(index).reach
			var motion = _mace()
			motion.start(index, aim)
			var event: Dictionary = motion.advance(2.0)
			var pose: Dictionary = event.contact_pose
			_near(motion.definition(index).reach, reference_reach, "mace strike matches corresponding ordinary sword reach")
			_near(pose.radius + cos(pose.pitch) * pose.blade_length, reference_reach, "damage event carries the physical head at sword reach")
			for distance in [old_reaches[index] - 0.001, reference_reach - 0.001]:
				var target: Vector3 = origin + forward * distance
				_check(sword.is_target_hit(origin, target, 0.0, aim - 0.01, aim + 0.01), "ordinary sword reaches reference lane fixture")
				_check(motion.is_target_hit(origin, target, 0.0, aim, aim), "mace covers old edge and newly matched sword edge")
			var beyond: Vector3 = origin + forward * (reference_reach + 0.01)
			_check(not sword.is_target_hit(origin, beyond, 0.0, aim - 0.01, aim + 0.01), "ordinary sword excludes beyond reference edge")
			_check(not motion.is_target_hit(origin, beyond, 0.0, aim, aim), "mace excludes beyond newly matched sword edge")

func _test_rigid_length_through_all_phases() -> void:
	# Catches telescoping as a shortcut to reach parity, including held idle.
	var motion = _mace()
	_near(motion.sample().blade_length, 1.9, "rest has full rigid mace length")
	_near(motion.sample().radius, 0.2, "rest holds the longer mace close to the body")
	for index in range(3):
		motion.start(index, -0.7)
		while motion.busy:
			motion.advance(1.0 / 240.0)
			_near(motion.sample().blade_length, 1.9, "every windup/active/recovery sample preserves rigid mace length")
		_near(motion.sample().blade_length, 1.9, "held end pose preserves rigid mace length")

func _test_lunge_budget_and_subdivision() -> void:
	# Catches unbounded velocity integration, recovery rewind and late shove hit.
	var motion = _mace()
	motion.start(1, 0.0)
	_near(motion.definition(1).lunge_distance, 0.75, "movement consumer shares the slightly longer short travel budget")
	_near(motion.sample().lunge_offset, 0.0, "shove starts without teleporting")
	motion.advance(0.05)
	_near(motion.sample().lunge_offset, 0.0, "windup does not travel")
	motion.advance(0.065)
	_near(motion.sample().lunge_offset, 0.5625, "easeout has travelled most of its short budget at half active")
	motion.advance(0.039)
	_near(motion.sample().lunge_offset, 0.72, "light damage occurs after most forward travel")
	motion.advance(0.026)
	_near(motion.sample().lunge_offset, 0.75, "active end exhausts exactly the short travel budget")
	motion.advance(0.14)
	_near(motion.sample().lunge_offset, 0.75, "recovery and held idle do not rewind completed travel")
	motion.start(2, 0.0)
	motion.advance(2.0)
	_near(motion.sample().lunge_offset, 0.75, "finisher retains the already travelled lunge offset")
	motion.start(0, 0.0)
	motion.advance(2.0)
	motion.start(1, 0.0)
	_near(motion.sample().lunge_offset, 0.0, "a later combo grants its own lunge budget")
	motion.advance(2.0)
	_near(motion.sample().lunge_offset, 0.75, "repeated lunge cannot accumulate beyond its own budget")
	var one_step = _mace()
	one_step.start(1, 0.0)
	one_step.advance(2.0)
	_near(one_step.sample().lunge_offset, 0.75, "large dt cannot exceed lunge budget")
	for dt in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0]:
		var stepped = _mace()
		stepped.start(1, 0.0)
		var previous := 0.0
		var travel := 0.0
		var pulses := 0
		while stepped.busy:
			var event: Dictionary = stepped.advance(dt)
			var offset: float = stepped.sample().lunge_offset
			_check(offset >= previous - 0.000001 and offset <= 0.750001, "every lunge subdivision stays monotonic and bounded")
			travel += offset - previous
			previous = offset
			pulses += 1 if event.damage_ready else 0
		_near(travel, 0.75, "cumulative diff gives identical travel at any frame rate")
		_check(pulses == 1, "time subdivision emits exactly one light hit")

func _test_chain_and_reaim_continuity() -> void:
	# Catches snapped shoulder/recovery poses, in-flight mouse steering and seam turns.
	for aim in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var motion = _mace()
		for index in range(3):
			var held: Dictionary = motion.sample()
			motion.start(index, aim)
			_assert_pose(motion.sample(), held, "new strike begins at exact previous held pose")
			var attack: Dictionary = motion.definition(index)
			motion.advance(attack.windup - 0.000001)
			var prepared: Dictionary = motion.sample()
			motion.advance(0.000001)
			_assert_pose(motion.sample(), prepared, "windup enters active without a visual jump", 0.001)
			motion.aim_angle = aim + 1.0
			motion.advance(attack.active + attack.recovery - 0.000001)
			var near_idle: Dictionary = motion.sample()
			motion.advance(0.000001)
			_assert_pose(motion.sample(), near_idle, "recovery ends continuously at held idle", 0.001)
			_near(wrapf(motion.sample().angle - aim, -PI, PI), 0.0, "public aim mutation cannot steer committed motion")
			var end: Dictionary = motion.sample()
			motion.advance(4.0)
			_assert_pose(motion.sample(), end, "idle preserves weight and shoulder pose")
	var turn = _mace()
	turn.start(0, 3.05)
	turn.advance(2.0)
	var held: Dictionary = turn.sample()
	_check(turn.rebase_idle_aim(-3.05), "held mace can turn across wrap seam")
	var rebased: Dictionary = turn.sample()
	_near(rebased.angle - held.angle, TAU - 6.1, "idle rebasing uses shortest turn")
	_near(rebased.pitch, held.pitch, "reaim preserves shoulder pitch")
	_near(rebased.grip_height, held.grip_height, "reaim preserves grip height")
	turn.start(1, -1.3)
	_assert_pose(turn.sample(), rebased, "fresh lunge aim begins from existing physical pose")
	_near(turn.aim_angle, -1.3, "new strike reads fresh aim")
	_check(not turn.rebase_idle_aim(1.0), "active attack refuses aim rebase")
	turn.advance(2.0)
	turn.start(2, 0.8)
	turn.advance(0.345)
	_near(turn.sample().angle, 0.8, "finisher accepts another fresh aim")

func _test_invalid_inputs_and_dispatch() -> void:
	var motion = _mace()
	_check(not motion.start(-1, 0.0) and not motion.start(3, 0.0), "invalid stage cannot start")
	_check(not motion.start(0, NAN) and not motion.start(0, INF), "nonfinite aim cannot start")
	_check(motion.definition(-1).is_empty() and motion.definition(3).is_empty(), "invalid definition is empty")
	_check(not motion.rebase_idle_aim(NAN), "nonfinite idle aim is refused")
	motion.start(0, 0.4)
	motion.advance(0.1)
	var before: Dictionary = motion.sample()
	_check(not motion.start(1, -0.4), "busy motion refuses attack replacement")
	_check(not motion.set_family("sword"), "busy mace refuses family switch")
	for dt in [0.0, -0.1, INF, NAN]:
		var result: Dictionary = motion.advance(dt)
		_check(not result.damage_ready and not result.active and not result.finished, "invalid delta emits no combat event")
	_near(motion.elapsed, 0.1, "invalid delta preserves exposed elapsed")
	_assert_pose(motion.sample(), before, "invalid input preserves physical pose")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3.ONE, -0.1, 0.0, 0.0), "negative target radius is refused")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3.ONE, NAN, 0.0, 0.0), "nonfinite target radius is refused")
	_check(not motion.is_target_hit(Vector3(INF, 0, 0), Vector3.ONE, 0.1, 0.0, 0.0), "nonfinite origin is refused")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3(NAN, 0, 0), 0.1, 0.0, 0.0), "nonfinite target is refused")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3.ONE, 0.1, NAN, 0.0), "nonfinite caller angles are refused")
	motion.reset()
	_check(motion.family == "mace" and not motion.busy and motion.stage == -1, "reset preserves selected family and clears stage")
	_near(motion.sample().lunge_offset, 0.0, "reset clears lunge budget")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3.ONE, 0.1, 0.0, 0.0), "reset motion cannot damage")
	_check(motion.set_family("sword"), "idle switch restores sword")
	_near(motion.definition(0).damage, 18.0, "legacy sword tuning survives mace dispatch")
	_check(motion.set_family("greatsword"), "idle switch restores greatsword")
	_near(motion.definition(2).damage, 85.0, "legacy greatsword tuning survives mace dispatch")
	_check(not motion.set_family("hammer"), "unknown family is refused")

func _assert_pose(actual: Dictionary, expected: Dictionary, message: String, tolerance := 0.0001) -> void:
	_check(absf(wrapf(actual.angle - expected.angle, -PI, PI)) < tolerance and absf(actual.pitch - expected.pitch) < tolerance and absf(actual.grip_height - expected.grip_height) < tolerance and absf(actual.radius - expected.radius) < tolerance, message)
