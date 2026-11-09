extends SceneTree

var failures: Array[String] = []
var checks := 0
var motion_script: Script

func _initialize() -> void:
	if not FileAccess.file_exists("res://scripts/weapon_motion.gd"):
		push_error("FAIL: weapon motion module is missing")
		quit(1)
		return
	motion_script = load("res://scripts/weapon_motion.gd")
	if motion_script == null or not motion_script.can_instantiate():
		push_error("FAIL: weapon motion module cannot instantiate")
		quit(1)
		return
	_test_lifecycle_and_boundaries()
	_test_large_step_preserves_entire_damage_sweep()
	_test_acceleration_and_reverse_swing()
	_test_swept_sector_and_collision_radius()
	_test_invalid_inputs_and_reset()
	if failures.is_empty():
		print("PASS: weapon motion (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (got %.5f, expected %.5f)" % [message, actual, expected])

func _test_lifecycle_and_boundaries() -> void:
	var motion = motion_script.new()
	_check(not motion.busy and motion.sample().phase == "idle", "new motion is idle")
	_check(motion.start(0, 0.4), "first swing starts")
	_check(not motion.start(1, 2.0), "busy swing refuses replacement")
	_check(motion.stage == 0, "refused replacement retains first swing")
	_near(motion.aim_angle, 0.4, "refused replacement retains locked aim")
	_check(motion.sample().phase == "windup" and not motion.sample().trail, "windup has no damaging trail")
	var before = motion.advance(0.12)
	_check(not before.active and not before.entered_active, "windup cannot deal damage")
	var boundary = motion.advance(0.01)
	_check(boundary.entered_active and boundary.active, "exact windup boundary enters active once")
	_near(boundary.previous_angle, 1.075, "entering active clips away windup angles")
	_near(boundary.current_angle, 1.075, "exact active entrance has zero swept width")
	_check(motion.sample().phase == "active" and motion.sample().trail, "active sample enables trail")
	var middle = motion.advance(0.055)
	_check(middle.active and not middle.entered_active, "active continuation does not re-enter")
	var recovery = motion.advance(0.065)
	_check(recovery.active and motion.sample().phase == "recovery", "step crossing active end retains final hit segment")
	_near(recovery.current_angle, -0.275, "final damage angle stops at active endpoint")
	_check(not motion.sample().trail, "recovery disables trail")
	var after = motion.advance(0.02)
	_check(not after.active, "pure recovery cannot deal damage")
	var done = motion.advance(1.0)
	_check(done.finished and not motion.busy and motion.sample().phase == "idle", "completed recovery returns to idle")
	_check(not motion.advance(1.0).finished, "finish event is emitted only once")
	_check(motion.start(1, -0.4), "next attack can start after recovery")

func _test_large_step_preserves_entire_damage_sweep() -> void:
	var motion = motion_script.new()
	motion.start(2, 0.7)
	var result = motion.advance(5.0)
	_check(result.entered_active and result.active and result.finished, "one large step reports crossed active window and finish")
	_near(result.previous_angle, 1.475, "large step starts at heavy swing damaging edge")
	_near(result.current_angle, -0.075, "large step ends at heavy swing damaging edge")
	_check(motion.is_target_hit(Vector3.ZERO, Vector3(cos(0.7), 0.0, sin(0.7)) * 2.5, 0.0, result.previous_angle, result.current_angle), "large-step full arc retains a forward target at heavy reach")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3(-3.0, 0.0, 0.0), 0.0, result.previous_angle, result.current_angle), "large-step sweep does not become a full circle")
	_check(not motion.advance(1.0).active, "finished swing cannot keep causing damage")
	var heavy = motion.definition(2)
	_check(heavy.windup > motion.definition(0).windup and heavy.recovery > motion.definition(0).recovery, "heavy swing commits longer before and after impact")
	_check(heavy.damage > motion.definition(1).damage and heavy.reach > motion.definition(1).reach, "heavy commitment yields greater damage and reach")
	heavy.damage = 999.0
	_check(motion.definition(2).damage < 999.0, "external definition edits cannot mutate attack tuning")

func _test_acceleration_and_reverse_swing() -> void:
	var first = motion_script.new()
	first.start(0, 0.0)
	first.advance(0.13)
	var first_edge: float = first.sample().angle
	first.advance(0.055)
	var middle: float = first.sample().angle
	first.advance(0.055)
	var last_edge: float = first.sample().angle
	_check(absf(middle - first_edge) < absf(last_edge - middle), "blade accelerates across its active sweep")
	_check(absf(first.sample().body_lean) <= 0.0451, "body motion stays subordinate to blade motion")
	var reverse = motion_script.new()
	reverse.start(1, 0.0)
	var sweep = reverse.advance(0.32)
	_check(sweep.previous_angle < sweep.current_angle, "second swing reverses blade direction")
	_near(sweep.current_angle - sweep.previous_angle, 1.45, "reverse damage arc remains bounded")
	var aim_lock = motion_script.new()
	aim_lock.start(0, 1.0)
	aim_lock.aim_angle = -2.0
	aim_lock.advance(0.13)
	_near(aim_lock.sample().angle, 1.675, "in-progress blade remains locked to start aim")
	var recovery_motion = motion_script.new()
	recovery_motion.start(0, 0.0)
	recovery_motion.advance(0.24)
	var end_angle: float = recovery_motion.sample().angle
	recovery_motion.advance(0.02)
	_check(recovery_motion.sample().angle < end_angle, "blade carries momentum briefly after its active sweep")
	_check(recovery_motion.sample().radius >= 0.19 and recovery_motion.sample().radius <= 0.31, "small hand and weapon root stays near player")

func _test_swept_sector_and_collision_radius() -> void:
	var motion = motion_script.new()
	motion.start(0, 0.0)
	_check(motion.is_target_hit(Vector3.ZERO, Vector3(1.5, 0.0, 0.0), 0.0, -0.3, 0.3), "forward target lies inside swept sector")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3(-1.0, 0.0, 0.0), 0.0, -0.3, 0.3), "target behind blade arc is missed")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3(2.31, 0.0, 0.0), 0.2, -0.3, 0.3), "target beyond reach plus radius is missed")
	_check(motion.is_target_hit(Vector3.ZERO, Vector3(2.29, 0.0, 0.0), 0.2, -0.3, 0.3), "target radius can overlap blade tip")
	_check(motion.is_target_hit(Vector3.ZERO, Vector3(1.0, 0.0, 0.19), 0.2, 0.0, 0.0), "circle touching a zero-width radial blade is hit")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3(1.0, 0.0, 0.21), 0.2, 0.0, 0.0), "circle outside blade boundary is missed")
	_check(motion.is_target_hit(Vector3.ZERO, Vector3(-1.0, 0.0, 0.0), 0.0, 3.0, -3.0), "wrapped angles sweep across negative X by shortest arc")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 0.0, 3.0, -3.0), "wrapped endpoints do not produce a nearly full circle")
	_check(motion.is_target_hit(Vector3(10.0, 0.0, 5.0), Vector3(11.0, 0.0, 5.0), 0.0, 0.3, -0.3), "translated origin and reverse sweep retain same sector")
	_check(motion.is_target_hit(Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 0.1), "sector includes its origin without dividing by zero")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3(2.2, 0.0, 0.1), 0.11, 0.0, 0.0), "radial endpoint uses circle distance, not independent range and angle padding")

func _test_invalid_inputs_and_reset() -> void:
	var motion = motion_script.new()
	_check(not motion.start(-1, 0.0) and not motion.start(3, 0.0), "invalid attack indices are refused")
	_check(not motion.start(0, NAN) and not motion.start(0, INF), "nonfinite aim is refused")
	_check(motion.definition(-1).is_empty(), "invalid definition returns no attack")
	motion.start(0, 0.0)
	motion.advance(0.1)
	var angle_before: float = motion.sample().angle
	for invalid_delta in [-1.0, NAN, INF, 0.0]:
		var result = motion.advance(invalid_delta)
		_check(not result.active and not result.finished, "invalid or empty time step emits no events")
	_near(motion.elapsed, 0.1, "invalid time cannot advance attack")
	_near(motion.sample().angle, angle_before, "invalid time cannot move blade")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3.ONE, -0.1, 0.0, 0.3), "negative target radius is rejected")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3.ONE, NAN, 0.0, 0.3), "nonfinite target radius is rejected")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3.ONE, 0.1, NAN, 0.3), "nonfinite sweep is rejected")
	motion.reset()
	_check(not motion.busy and motion.stage == -1 and motion.sample().phase == "idle", "reset discards in-flight attack")
	_check(not motion.is_target_hit(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 0.0, 0.0, 0.3), "reset has no damage definition")
	_check(motion.start(2, 0.0), "reset allows a fresh attack")
