extends SceneTree

var checks := 0
var failures: Array[String] = []
var motion_script: Script

func _initialize() -> void:
	motion_script = load("res://scripts/weapon_motion.gd")
	_test_rigid_reach_and_cut_direction()
	_test_connected_chain_and_aim_rebase()
	_test_large_step_clips_edge_trace()
	if failures.is_empty():
		print("PASS: ordinary sword motion (%d checks)" % checks)
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

func _same_pose(actual: Dictionary, expected: Dictionary, message: String) -> void:
	_check(absf(wrapf(actual.angle - expected.angle, -PI, PI)) < 0.0001 and absf(actual.pitch - expected.pitch) < 0.0001 and absf(actual.grip_height - expected.grip_height) < 0.0001 and absf(actual.radius - expected.radius) < 0.0001, message)

func _test_rigid_reach_and_cut_direction() -> void:
	for aim in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var right := Vector3(cos(aim), 0.0, sin(aim)).cross(Vector3.UP)
		for index in range(3):
			var sword = motion_script.new()
			var mace = motion_script.new()
			mace.set_family("mace")
			sword.start(index, aim)
			var attack: Dictionary = sword.definition(index)
			_near(attack.reach, mace.definition(index).reach, "sword and mace retain matching stage reach")
			sword.advance(attack.windup)
			var start: Dictionary = sword.sample()
			var side: float = Vector3(cos(start.angle), 0.0, sin(start.angle)).dot(right)
			_check(side > 0.5 if index != 1 else side < -0.5, "cut starts on the correct actor side at every aim")
			for step in range(5):
				var pose: Dictionary = sword.sample()
				_near(pose.blade_length, 1.9, "blade stays rigid through each active slice")
				_near(pose.radius + cos(pose.pitch) * pose.blade_length, attack.reach, "visible projected tip stays at damage reach")
				_near(pose.grip_height, 0.68, "ordinary cut keeps its low grip")
				_check(absf(pose.body_lean) <= 0.0451, "body lean stays subordinate to the blade")
				if index < 2:
					_near(pose.pitch, 0.0, "first two cuts stay horizontal")
				_check(not pose.has("lunge_offset"), "sword motion does not inherit mace travel")
				if step < 4:
					sword.advance(attack.active * 0.25)
			var finish: Dictionary = sword.sample()
			side = Vector3(cos(finish.angle), 0.0, sin(finish.angle)).dot(right)
			_check(side < -0.5 if index != 1 else side > 0.5, "cut finishes on the opposite actor side")
			if index == 2:
				_check(start.pitch > 0.0 and finish.pitch < 0.0, "third cut descends diagonally across the actor")
				sword.advance(attack.recovery)
				_near(sword.sample().blade_length, 1.9, "diagonal recovery cannot shorten the blade")

func _test_connected_chain_and_aim_rebase() -> void:
	var motion = motion_script.new()
	for index in range(3):
		var held: Dictionary = motion.sample()
		motion.start(index, 0.0)
		_same_pose(motion.sample(), held, "next cut starts exactly from the held blade pose")
		var attack: Dictionary = motion.definition(index)
		motion.advance(attack.windup - 0.000001)
		var prepared: Dictionary = motion.sample()
		motion.advance(0.000001)
		_same_pose(motion.sample(), prepared, "windup meets active without a grip or blade jump")
		motion.advance(attack.active + attack.recovery)
		var end: Dictionary = motion.sample()
		motion.advance(1.0)
		_same_pose(motion.sample(), end, "idle gap preserves the completed pose")
	var held: Dictionary = motion.sample()
	_check(motion.rebase_idle_aim(PI * 0.5), "held blade follows idle aim")
	var turned: Dictionary = motion.sample()
	_near(turned.angle - held.angle, PI * 0.5, "aim turn preserves the held body-relative angle")
	_near(turned.radius, held.radius, "aim turn preserves grip radius")
	motion.reset()
	_near(motion.sample().angle, 0.35, "explicit pose reset restores ordinary ready pose")
	_check(motion.stage == -1 and not motion.busy, "reset clears a completed sequence")

func _test_large_step_clips_edge_trace() -> void:
	for index in range(3):
		var motion = motion_script.new()
		motion.start(index, 0.4)
		var attack: Dictionary = motion.definition(index)
		var result: Dictionary = motion.advance(5.0)
		_check(result.active and result.damage_ready and result.finished, "large delta retains active damage and completion")
		_check(result.has("trail_from") and result.has("trail_to"), "crossed active interval carries actual edge poses")
		if not result.has("trail_from") or not result.has("trail_to"):
			continue
		var from: Dictionary = result.trail_from
		var to: Dictionary = result.trail_to
		_check(from.phase == "active" and to.phase == "active", "trace endpoints exclude windup and recovery")
		_near(from.progress, 0.0, "large delta starts trace at active entrance")
		_near(to.progress, 1.0, "large delta stops trace at active exit")
		_near(from.angle, result.previous_angle, "collision and visual edge share the start angle")
		_near(to.angle, result.current_angle, "collision and visual edge share the finish angle")
		_near(from.radius + cos(from.pitch) * from.blade_length, attack.reach, "trace start uses physical damage reach")
		_near(to.radius + cos(to.pitch) * to.blade_length, attack.reach, "trace finish uses physical damage reach")
		var split = motion_script.new()
		split.start(index, 0.4)
		var windup: Dictionary = split.advance(attack.windup * 0.5)
		_check(windup.trail_from.is_empty() and windup.trail_to.is_empty(), "windup cannot emit blade-edge traces")
		split.advance(attack.windup * 0.5 + attack.active * 0.5)
		var tail: Dictionary = split.advance(attack.active * 0.5 + attack.recovery)
		_near(tail.trail_from.progress, 0.5, "partial trace starts at the prior active pose")
		_near(tail.trail_to.progress, 1.0, "partial trace clips recovery from its end")
		_same_pose(split.sample(), motion.sample(), "subdivision preserves the final held pose")
