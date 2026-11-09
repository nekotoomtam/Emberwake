extends SceneTree
## Real CharacterBody sweeps: authored budgets, release-only timing, and blockers.

const Motion = preload("res://scripts/weapon_motion.gd")
const Enemy = preload("res://scripts/enemy.gd")
const CASES: Array[Dictionary] = [
	{"family": "sword", "stage": 0, "distance": 0.18},
	{"family": "sword", "stage": 1, "distance": 0.20},
	{"family": "sword", "stage": 2, "distance": 0.30},
	{"family": "greatsword", "stage": 0, "distance": 0.28},
	{"family": "greatsword", "stage": 1, "distance": 0.30},
	{"family": "greatsword", "stage": 2, "distance": 0.42},
	{"family": "mace", "stage": 0, "distance": 0.16},
	{"family": "mace", "stage": 1, "distance": 0.0},
	{"family": "mace", "stage": 2, "distance": 0.24},
]
var Step
var body: CharacterBody3D
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_check(absf(actual - expected) <= tolerance, "%s (got %.6f, expected %.6f)" % [message, actual, expected])


func _run() -> void:
	_check(ResourceLoader.exists("res://scripts/attack_step.gd"), "bounded attack-step helper exists")
	if failures.is_empty():
		Step = load("res://scripts/attack_step.gd")
		body = CharacterBody3D.new()
		body.collision_layer = 4
		body.collision_mask = 1
		var collider := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.3
		capsule.height = 1.35
		collider.shape = capsule
		collider.position.y = 0.68
		body.add_child(collider)
		root.add_child(body)
		await physics_frame
		_test_authored_budgets()
		_test_release_curve_and_no_recovery_drift()
		_test_vertical_contact_completion()
		_test_whole_attack_overshoot()
		_test_direction_reset_and_invalid_states()
		await _test_target_blockers()
		await _test_world_blocker()
		body.queue_free()
		await process_frame
	print("ATTACK STEP TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _definition(family: String, stage: int) -> Dictionary:
	var motion = Motion.new()
	motion.set_family(family)
	return motion.definition(stage)


func _fresh_body() -> void:
	body.position = Vector3(0, 0.03, 0)


func _test_authored_budgets() -> void:
	# Reintroduced frame velocity, budget carryover, or a mace double-step breaks this.
	for rate in [30, 60, 120, 240]:
		for entry in CASES:
			_fresh_body()
			var step = Step.new()
			_check(step.begin(entry.family, entry.stage, 0.0), "%s stage %d accepts an authored budget" % [entry.family, entry.stage])
			var definition: Dictionary = _definition(entry.family, entry.stage)
			var duration: float = definition.windup + definition.active + definition.recovery
			for index in range(ceili(duration * rate) + 1):
				step.advance(body, float(index) / rate, definition, [])
			_near(body.position.x, entry.distance, "%s stage %d travels one budget at %d Hz" % [entry.family, entry.stage, rate])
			_near(step.travelled, entry.distance, "reported step travel matches real body displacement")
			_near(step.requested, entry.distance, "requested cumulative travel caps at the authored distance")
			_near(body.position.z, 0.0, "forward step has no lateral drift")


func _test_release_curve_and_no_recovery_drift() -> void:
	# Moving during windup/recovery, a linear curve, or rewind breaks this.
	_fresh_body()
	var step = Step.new()
	step.begin("sword", 0, PI / 2.0)
	var definition: Dictionary = _definition("sword", 0)
	step.advance(body, definition.windup * .5, definition, [])
	step.advance(body, definition.windup, definition, [])
	_near(step.travelled, 0.0, "windup and active-start boundary have no attack movement")
	step.advance(body, definition.windup + definition.active * .25, definition, [])
	_near(body.position.z, 0.07875, "first quarter of release consumes ease-out cumulative travel")
	step.advance(body, definition.windup + definition.active * .5, definition, [])
	_near(body.position.z, 0.135, "half release consumes three quarters of the step")
	step.advance(body, definition.windup + definition.active, definition, [])
	_near(body.position.z, 0.18, "active end completes the short step")
	for elapsed in [0.4, 0.53, 20.0, 20.0, 0.1]:
		step.advance(body, elapsed, definition, [])
	_near(body.position.z, 0.18, "recovery, idle and older elapsed values cannot drift or rewind")
	_near(body.position.x, 0.0, "locked vertical aim remains on its ground-plane axis")


func _test_vertical_contact_completion() -> void:
	# Delaying lift/slam travel beyond damage contact breaks these contact positions.
	for entry in [CASES[5], CASES[6], CASES[8]]:
		_fresh_body()
		var step = Step.new()
		step.begin(entry.family, entry.stage, 0.0)
		var definition: Dictionary = _definition(entry.family, entry.stage)
		var release_to_contact: float = definition.active * definition.impact_progress
		step.advance(body, definition.windup + release_to_contact * 0.5, definition, [])
		_near(body.position.x, entry.distance * 0.75, "vertical strike consumes three quarters of travel halfway to contact")
		step.advance(body, definition.windup + release_to_contact, definition, [])
		_near(body.position.x, entry.distance, "vertical strike finishes its full step by actual contact")
		step.advance(body, definition.windup + definition.active + definition.recovery, definition, [])
		_near(body.position.x, entry.distance, "vertical follow-through adds no further movement")


func _test_whole_attack_overshoot() -> void:
	# Reading final idle sample progress would lose all movement on this frame.
	for entry in CASES:
		_fresh_body()
		var step = Step.new()
		step.begin(entry.family, entry.stage, PI)
		var definition: Dictionary = _definition(entry.family, entry.stage)
		step.advance(body, 5.0, definition, [])
		_near(body.position.x, -entry.distance, "%s stage %d consumes crossed release even after whole-attack overshoot" % [entry.family, entry.stage])
		step.advance(body, 6.0, definition, [])
		_near(body.position.x, -entry.distance, "later idle tick cannot repeat the consumed budget")


func _test_direction_reset_and_invalid_states() -> void:
	# Missing reset, accepting malformed time/definitions, or unsupported families breaks this.
	_fresh_body()
	var step = Step.new()
	var definition: Dictionary = _definition("sword", 0)
	step.begin("sword", 0, 0.0)
	step.advance(body, definition.windup + definition.active * .5, definition, [])
	_near(step.travelled, 0.135, "fixture has a partially consumed first stroke")
	step.begin("sword", 1, -PI / 2.0)
	_near(step.travelled, 0.0, "accepted next stroke gets a fresh actual-travel counter")
	_near(step.requested, 0.0, "accepted next stroke gets a fresh desired-travel counter")
	_near(step.direction.dot(Vector3.FORWARD), 1.0, "new stroke locks its newly selected aim")
	step.advance(body, 5.0, _definition("sword", 1), [])
	_near(body.position.x, 0.135, "redirected second stroke preserves prior position")
	_near(body.position.z, -0.20, "redirected second stroke receives only its own budget")
	step.reset()
	step.advance(body, 5.0, definition, [])
	_near(step.distance + step.travelled + step.requested, 0.0, "reset clears budgets and cannot move an abandoned stroke")
	_near(step.direction.length(), 0.0, "reset clears the old direction")
	for entry in [["staff", 0, 0.0], ["pistol", 0, 0.0], ["rifle", 0, 0.0], ["sword", -1, 0.0], ["sword", 3, 0.0], ["sword", 0, NAN], ["sword", 0, INF]]:
		_check(not step.begin(entry[0], entry[1], entry[2]), "unsupported or nonfinite stroke is rejected")
		_near(step.advance(body, 5.0, definition, []), 0.0, "invalid stroke cannot move the actor")
	_fresh_body()
	step.begin("sword", 0, 0.0)
	for elapsed in [-1.0, NAN, INF, -INF, 0.0]:
		_near(step.advance(body, elapsed, definition, []), 0.0, "nonpositive or nonfinite elapsed cannot consume travel")
	for invalid in [{}, {"windup": -1.0, "active": 1.0}, {"windup": 0.0, "active": 0.0}, {"windup": NAN, "active": 0.1}, {"windup": 0.0, "active": INF}, {"windup": "bad", "active": 0.1}]:
		_near(step.advance(body, 5.0, invalid, []), 0.0, "malformed release definition cannot consume travel")
	_near(step.advance(null, 5.0, definition, []), 0.0, "missing body cannot consume travel")
	_near(step.requested, 0.0, "rejected advances preserve the fresh movement budget")
	step.advance(body, 5.0, definition, [])
	_near(body.position.x, 0.18, "valid advance still receives its full budget after rejected data")
	step.reset()
	step.begin("greatsword", 2, 0.0)
	for impact in [0.0, -0.5, 1.1, NAN, INF]:
		_near(step.advance(body, 5.0, {"kind": "slam", "windup": 0.1, "active": 0.1, "impact_progress": impact}, []), 0.0, "invalid vertical contact timing cannot consume travel")


func _test_target_blockers() -> void:
	# Nearest living target contact must consume the attempted budget, never bank it.
	_fresh_body()
	var near_target = Enemy.new()
	near_target.kind = "dummy"
	near_target.position = Vector3(0.85, 0.03, 0)
	root.add_child(near_target)
	var far_target = Enemy.new()
	far_target.kind = "dummy"
	far_target.position = Vector3(1.0, 0.03, 0)
	root.add_child(far_target)
	await physics_frame
	var step = Step.new()
	step.begin("greatsword", 2, 0.0)
	var definition: Dictionary = _definition("greatsword", 2)
	step.advance(body, 5.0, definition, [far_target, null, near_target])
	_near(body.position.x, 0.11, "nearest living target stops the swept body at combined .74 radius")
	_near(step.travelled, 0.11, "target stop reports actual clipped travel")
	_near(step.requested, 0.42, "target stop consumes the whole attempted release budget")
	near_target.position.x = 5.0
	far_target.position.x = 6.0
	step.advance(body, 6.0, definition, [near_target, far_target])
	_near(body.position.x, 0.11, "moving a blocker away in recovery cannot release banked travel")
	_fresh_body()
	near_target.dead = true
	near_target.position.x = 0.8
	far_target.position = Vector3(-0.8, 0.03, 0)
	step.begin("greatsword", 2, 0.0)
	step.advance(body, 5.0, definition, [near_target, far_target])
	_near(body.position.x, 0.42, "dead targets and targets behind the stroke do not block forward travel")
	near_target.queue_free()
	far_target.queue_free()
	await physics_frame


func _test_world_blocker() -> void:
	# A high-delta move must sweep its real capsule against the world collision layer.
	_fresh_body()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2.0, 2.0)
	collider.shape = box
	wall.add_child(collider)
	wall.position = Vector3(0.65, 0.75, 0)
	root.add_child(wall)
	await physics_frame
	var step = Step.new()
	step.begin("greatsword", 2, 0.0)
	var definition: Dictionary = _definition("greatsword", 2)
	step.advance(body, 5.0, definition, [])
	_check(body.position.x > 0.24 and body.position.x <= 0.251, "world wall stops swept capsule before its front surface")
	_near(step.travelled, body.position.x, "world collision reports actual body displacement")
	_near(step.requested, 0.42, "world collision consumes the attempted cumulative budget")
	wall.queue_free()
	await physics_frame
	var stopped: float = body.position.x
	step.advance(body, 6.0, definition, [])
	_near(body.position.x, stopped, "removed world blocker cannot cause recovery drift")
