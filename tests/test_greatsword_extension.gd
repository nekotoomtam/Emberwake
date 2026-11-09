extends SceneTree
## May run as an absolute external script against v10 or v11 --path.
## Constants here are the review contract, independent of production constants.

const EXPECTED_LENGTH := 2.475
const EXPECTED_SWEEP_REACH := 2.975
const OLD_SWEEP_REACH := 2.75
const EXPECTED_GROUND_REACH := 0.5 + sqrt(EXPECTED_LENGTH * EXPECTED_LENGTH - 0.8 * 0.8)
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var motion_script: Script = load("res://scripts/weapon_motion.gd")
	var hero = load("res://scripts/hero_visual.gd").new()
	hero.set_weapon_family("greatsword")
	root.add_child(hero)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 12.5, 11.5)
	camera.look_at(Vector3.ZERO)
	await process_frame
	for stage in range(2):
		var motion = motion_script.new()
		motion.set_family("greatsword")
		motion.start(stage, 0.0)
		var attack: Dictionary = motion.definition(stage)
		var segment: Dictionary = motion.advance(attack.windup + attack.active)
		var pose: Dictionary = motion.sample()
		_near(pose.blade_length, EXPECTED_LENGTH, "extended rigid blade length")
		_near(attack.reach, EXPECTED_SWEEP_REACH, "extended sweep reach")
		_check(motion.is_target_hit(Vector3.ZERO, Vector3((OLD_SWEEP_REACH + EXPECTED_SWEEP_REACH) * 0.5, 0, 0), 0.0, segment.previous_angle, segment.current_angle), "new blade hits beyond the old 2.75 boundary")
		_check(not motion.is_target_hit(Vector3.ZERO, Vector3(EXPECTED_SWEEP_REACH + 0.01, 0, 0), 0.0, segment.previous_angle, segment.current_angle), "new blade misses beyond 2.975")
		hero.update_pose(camera, Vector3.RIGHT, false, pose, attack.reach, 0, 0, 0)
		var points: Dictionary = hero.get_blade_points()
		_near(points.grip.distance_to(points.tip), EXPECTED_LENGTH, "rendered rigid blade retains the extended physical length")
	var slam = motion_script.new()
	slam.set_family("greatsword")
	slam.start(2, 0.0)
	var attack: Dictionary = slam.definition(2)
	var impact: Dictionary = slam.advance(attack.windup + attack.active * attack.impact_progress)
	var contact: Dictionary = slam.sample()
	_check(impact.damage_ready, "slam damage remains at its original contact time")
	_near(contact.blade_length, EXPECTED_LENGTH, "slam uses the same extended rigid blade")
	_near(attack.reach, EXPECTED_GROUND_REACH, "slam reach follows extended true ground contact")
	hero.update_pose(camera, Vector3.RIGHT, false, contact, attack.reach, 0, 0, 0)
	var landing: Dictionary = hero.get_blade_points()
	_near(landing.tip.y, 0.0, "rendered slam tip reaches the ground when damage begins")
	_near(landing.tip.x, EXPECTED_GROUND_REACH, "rendered slam tip matches its extended collision boundary")
	_check(slam.is_target_hit(Vector3.ZERO, Vector3(EXPECTED_GROUND_REACH - 0.01, 0, 0), 0.0, 0, 0), "slam reaches just inside its new ground tip")
	_check(not slam.is_target_hit(Vector3.ZERO, Vector3(EXPECTED_GROUND_REACH + 0.01, 0, 0), 0.0, 0, 0), "slam misses beyond its new ground tip")
	for family in ["sword", "mace"]:
		var motion = motion_script.new()
		motion.set_family(family)
		_near(motion.sample().blade_length, 1.9, "%s rigid length remains unchanged" % family)
		for stage in range(3):
			_near(motion.definition(stage).reach, [2.1, 2.2, 2.55][stage], "%s stage %d reach remains unchanged" % [family, stage])
	hero.queue_free()
	camera.queue_free()
	await process_frame
	if failures.is_empty():
		print("GREATSWORD_EXTENSION_PASS: %d checks; 2.475 rigid length; 2.975 sweep boundary; true ground slam; sword/mace reach preserved" % checks)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
