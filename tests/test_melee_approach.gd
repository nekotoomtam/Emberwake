extends SceneTree
## Selection contracts through real actors, with real physics for line of sight.

const Enemy = preload("res://scripts/enemy.gd")
const Motion = preload("res://scripts/weapon_motion.gd")
const BASES := {"sword": [0.18, 0.20, 0.30], "greatsword": [0.28, 0.30, 0.42], "mace": [0.16, 0.75, 0.24]}
var Approach
var AttackStep
var actors: Array[Node] = []
var checks := 0
var failures: Array[String] = []

class InvalidEnemy extends Node3D:
	var dead := false
	var health := 10.0
	var kind := "dummy"


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (got %.6f, expected %.6f)" % [message, actual, expected])


func _run() -> void:
	_check(ResourceLoader.exists("res://scripts/melee_approach.gd"), "target-aware melee selector is available")
	if failures.is_empty():
		Approach = load("res://scripts/melee_approach.gd")
		AttackStep = load("res://scripts/attack_step.gd")
		_test_base_and_required_travel()
		_test_priority_and_ties()
		_test_cone_and_double_reach()
		_test_invalid_and_dead_targets()
		_test_snapshot_and_invalid_inputs()
		_test_override_budget()
		await _test_assisted_windup_budget()
		await _test_world_occlusion()
	for actor in actors:
		if is_instance_valid(actor): actor.queue_free()
	await process_frame
	print("MELEE APPROACH TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _definition(family: String, stage: int) -> Dictionary:
	var motion = Motion.new()
	motion.set_family(family)
	return motion.definition(stage)


func _target(point: Vector3, kind: String = "dummy"):
	var actor = Enemy.new()
	actor.kind = kind
	actor.position = point
	root.add_child(actor)
	actors.append(actor)
	return actor


func _choose(targets: Array, family: String = "sword", stage: int = 0, world: World3D = null) -> Dictionary:
	return Approach.new().choose(family, stage, Vector3.ZERO, Vector3.RIGHT, _definition(family, stage), targets, world)


func _test_base_and_required_travel() -> void:
	# Losing authored fallback, safety inset, or reading another stage's reach breaks these.
	for family in BASES:
		for stage in range(3):
			var definition: Dictionary = _definition(family, stage)
			var empty := _choose([], family, stage)
			_check(not empty.assisted and empty.target_id == 0 and empty.direction == Vector3.RIGHT, "%s stage %d empty selection preserves mouse aim" % [family, stage])
			_near(empty.distance, BASES[family][stage], "empty selection preserves this stroke's ordinary budget")
			_near(float(empty.get("search_radius", -1.0)), float(definition.reach) * 2.0, "empty selection still exposes this stroke's doubled detection radius")
			_near(float(empty.get("distance_limit", -1.0)), maxf(BASES[family][stage], float(definition.reach) + 0.12), "selected motion limit follows current strike reach")
			var in_range = _target(Vector3.RIGHT * (definition.reach + 0.26))
			var inside := _choose([in_range], family, stage)
			_check(not inside.assisted and inside.direction == Vector3.RIGHT, "an in-range enemy keeps ordinary attack direction")
			_near(inside.distance, BASES[family][stage], "an in-range enemy keeps ordinary travel")
			var beyond = _target(Vector3.RIGHT * (definition.reach + 0.36 + 0.45))
			var plan := _choose([beyond], family, stage)
			_check(plan.assisted and plan.target_id == beyond.get_instance_id(), "%s stage %d selects a reachable beyond-range enemy" % [family, stage])
			_near(plan.distance, 0.75 if family == "mace" and stage == 1 else 0.57, "selected travel closes the gap with the .12 inset and preserves Mace's old path")
	var short_gap = _target(Vector3.RIGHT * 2.37)
	var short_plan: Dictionary = Approach.new().choose("sword", 2, Vector3.ZERO, Vector3.RIGHT, {"reach": 2.0}, [short_gap])
	_near(short_plan.distance, 0.30, "a just-outside target cannot shorten an existing third-stroke step")
	var elite = _target(Vector3.RIGHT * 2.95, "elite")
	var elite_plan: Dictionary = Approach.new().choose("greatsword", 0, Vector3.ZERO, Vector3.RIGHT, {"reach": 2.0}, [elite])
	_near(elite_plan.distance, 0.52, "elite selection uses its .55 hit radius")
	var close_side = _target(Vector3(2.1, 0, 0.4))
	var close_plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, {"reach": 2.0}, [close_side])
	_check(not close_plan.assisted and close_plan.direction == Vector3.RIGHT, "in-range off-axis target cannot rotate the ordinary mouse-aimed stroke")


func _test_priority_and_ties() -> void:
	# Alignment-first selection and unstable list-order ties break these fixtures.
	var aligned = _target(Vector3.RIGHT * 2.70)
	var closer = _target(Vector3(cos(deg_to_rad(20.0)), 0, sin(deg_to_rad(20.0))) * 2.45)
	var definition := {"reach": 2.0}
	for candidates in [[closer, aligned], [aligned, closer]]:
		var plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, candidates)
		_check(plan.target_id == closer.get_instance_id(), "nearest enemy wins before mouse alignment regardless of target order")
	var far = _target(Vector3.RIGHT * 2.90)
	for candidates in [[far, aligned], [aligned, far]]:
		var plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, candidates)
		_check(plan.target_id == aligned.get_instance_id(), "equal-angle candidates choose the nearer target regardless of order")
	var equal_distance_side = _target(Vector3(cos(deg_to_rad(20.0)), 0, sin(deg_to_rad(20.0))) * 2.7)
	for candidates in [[equal_distance_side, aligned], [aligned, equal_distance_side]]:
		var plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, candidates)
		_check(plan.target_id == aligned.get_instance_id(), "equal-distance candidates use best mouse alignment before instance id")
	var nearby_in_range = _target(Vector3(cos(deg_to_rad(25.0)), 0, sin(deg_to_rad(25.0))) * 2.2)
	var in_range_plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, [aligned, nearby_in_range])
	_check(in_range_plan.target_id == nearby_in_range.get_instance_id() and not in_range_plan.assisted and in_range_plan.direction == Vector3.RIGHT, "nearest in-range enemy preserves ordinary stroke instead of pulling toward a farther aligned enemy")
	var low_id = _target(Vector3(2.7, 0, 0.1))
	var high_id = _target(Vector3(2.7, 0, -0.1))
	for candidates in [[low_id, high_id], [high_id, low_id]]:
		var plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, candidates)
		_check(plan.target_id == mini(low_id.get_instance_id(), high_id.get_instance_id()), "identical angle and distance ties have stable instance-id ordering")


func _test_cone_and_double_reach() -> void:
	# Detection must use target centres at twice current reach, independent of hit radius.
	var definition := {"reach": 2.0}
	for angle in [0.0, 29.9, 30.0]:
		var target = _target(Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle))) * 2.8)
		var plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, [target])
		_check(plan.assisted, "enemy at %.1f degrees is inside the inclusive cone" % angle)
	for point in [Vector3(-2.6, 0, 0), Vector3(0, 0, 2.6), Vector3(cos(deg_to_rad(30.1)), 0, sin(deg_to_rad(30.1))) * 2.8, Vector3(4.001, 0, 0)]:
		var plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, [_target(point)])
		_check(not plan.assisted and plan.target_id == 0, "behind, outside-cone and beyond-detection targets fall back without turning")
		_near(plan.distance, 0.18, "rejected target leaves ordinary step distance")
	for family in BASES:
		for stage in range(3):
			var boundary_target = _target(Vector3(4, 0, 0))
			var boundary: Dictionary = Approach.new().choose(family, stage, Vector3.ZERO, Vector3.RIGHT, definition, [boundary_target])
			_check(boundary.assisted and boundary.target_id == boundary_target.get_instance_id(), "%s stage %d includes the exact double-reach boundary" % [family, stage])
			_near(boundary.distance, 1.76, "far-edge approach closes to the normal hit radius plus inset")
			_near(float(boundary.get("search_radius", -1.0)), 4.0, "detection radius doubles reach without adding enemy radius")
			_near(float(boundary.get("distance_limit", -1.0)), 2.12, "reach-based travel limit replaces the old .85 cap")
	var elite_inside = _target(Vector3(4, 0, 0), "elite")
	var elite_plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, [elite_inside])
	_check(elite_plan.assisted, "elite centre exactly at double reach is eligible")
	_near(elite_plan.distance, 1.57, "elite radius affects approach distance only")
	var elite_outside = _target(Vector3(4.01, 0, 0), "elite")
	var elite_outside_plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, [elite_outside])
	_check(not elite_outside_plan.assisted and elite_outside_plan.target_id == 0, "elite radius cannot expand target-centre detection")
	var too_far = _target(Vector3(4.01, 0, 0))
	var viable = _target(Vector3(2.65, 0, 0.4))
	var viable_plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, [too_far, viable])
	_check(viable_plan.target_id == viable.get_instance_id(), "unreachable best-angle enemy cannot hide a reachable cone candidate")


func _test_invalid_and_dead_targets() -> void:
	# Dead or corrupt closest actors must not steal selection from a living enemy.
	var dead = _target(Vector3(2.60, 0, 0))
	dead.dead = true
	var zero_health = _target(Vector3(2.60, 0, 0))
	zero_health.health = 0.0
	# No visual/physics children: corrupt data can be rejected without sending a
	# deliberately nonfinite transform into Godot's renderer or physics server.
	var corrupt := InvalidEnemy.new()
	root.add_child(corrupt)
	actors.append(corrupt)
	corrupt.position.x = NAN
	var removed = Enemy.new()
	removed.free()
	var ordinary_node := Node3D.new()
	root.add_child(ordinary_node)
	actors.append(ordinary_node)
	var viable = _target(Vector3(2.6, 0, 0.1))
	var plan: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, {"reach": 2.0}, [dead, zero_health, corrupt, null, removed, ordinary_node, 7, {}, Vector3.ZERO, viable])
	_check(plan.target_id == viable.get_instance_id(), "invalid, dead, empty-health and nonfinite entries are ignored safely")


func _test_snapshot_and_invalid_inputs() -> void:
	# Retaining live target references, using world Y, or accepting corrupt inputs breaks this.
	var target = _target(Vector3(2.7, 8, 0.1))
	var plan: Dictionary = Approach.new().choose("sword", 0, Vector3(0, 8, 0), Vector3(4, 0, 0), {"reach": 2.0}, [target])
	var locked: Vector3 = plan.direction
	var selected_position: Vector3 = plan.target_position
	_check(plan.assisted and locked.y == 0.0 and absf(locked.length() - 1.0) < 0.0001, "ground-plane aim is normalized and independent of actor elevation")
	target.position = Vector3(0, 8, 3)
	_check(plan.direction == locked and plan.target_position == selected_position, "plan snapshots target position and direction without homing")
	_check(typeof(plan.target_id) == TYPE_INT and typeof(plan.reason) == TYPE_STRING and not plan.reason.is_empty(), "public plan carries a serializable id and explanatory reason")
	for aim in [Vector3.ZERO, Vector3(NAN, 0, 0), Vector3(INF, 0, 0)]:
		var invalid: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, aim, {"reach": 2.0}, [target])
		_check(not invalid.assisted and invalid.direction.is_finite(), "invalid aim cannot choose or emit nonfinite travel")
	for definition in [{}, {"reach": -1.0}, {"reach": NAN}, {"reach": "bad"}]:
		var invalid: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, definition, [target])
		_check(not invalid.assisted, "invalid reach cannot choose an approach")
	for entry in [["staff", 0], ["pistol", 0], ["rifle", 0], ["sword", -1], ["sword", 3]]:
		var invalid: Dictionary = Approach.new().choose(entry[0], entry[1], Vector3.ZERO, Vector3.RIGHT, {"reach": 2.0}, [target])
		_check(not invalid.assisted and is_zero_approx(invalid.distance), "unsupported family or stage cannot receive melee travel")
	var invalid_origin: Dictionary = Approach.new().choose("sword", 0, Vector3(INF, 0, 0), Vector3.RIGHT, {"reach": 2.0}, [target])
	_check(not invalid_origin.assisted, "invalid origin cannot choose an approach")


func _test_override_budget() -> void:
	# An unbounded override or a second Mace step must never reach actual motion.
	var accepts_limit := false
	for method in AttackStep.get_script_method_list():
		if method.name == "begin": accepts_limit = method.args.size() >= 5
	_check(accepts_limit, "attack helper supports an explicit finite travel maximum")
	if not accepts_limit: return
	for family in BASES:
		for stage in range(3):
			var step = AttackStep.new()
			_check(step.begin(family, stage, 0.0, 1.5), "valid melee stroke accepts a bounded travel override")
			_near(step.distance, 0.0 if family == "mace" and stage == 1 else 0.85, "omitted maximum keeps the old caller cap and cannot add a second Mace lunge")
			step.begin(family, stage, 0.0, 3.0, 2.12)
			_near(step.distance, 0.0 if family == "mace" and stage == 1 else 2.12, "explicit reach-based maximum bounds a larger selected approach without a second Mace path")
	var step = AttackStep.new()
	for override in [-1.0, NAN, INF, -INF, 0.01]:
		step.begin("sword", 2, 0.0, override)
		_near(step.distance, 0.30, "invalid or shorter override preserves authored base travel")
	step.begin("sword", 0, PI / 2.0, 0.57)
	_near(step.distance, 0.57, "valid selected approach is the exact cumulative motion budget")
	_near(step.direction.dot(Vector3.BACK), 1.0, "selected approach locks the accepted aim")
	for invalid_limit in [NAN, INF, -INF, -1.0, 0.0]:
		step.begin("sword", 0, 0.0, 3.0, invalid_limit)
		_near(step.distance, 0.85, "nonfinite or nonpositive maximum falls back to the finite legacy cap")
	step.begin("sword", 2, 0.0, 0.5, 0.1)
	_near(step.distance, 0.30, "a maximum below the authored base cannot shorten the ordinary step")


func _test_assisted_windup_budget() -> void:
	# Long approaches must arrive before a sweep crosses aim; normal attacks keep
	# their authored release curve, and Mace2 cannot gain a second movement path.
	var accepts_windup := false
	for method in AttackStep.get_script_method_list():
		if method.name == "begin": accepts_windup = method.args.size() >= 6
	_check(accepts_windup, "attack helper supports the accepted approach timeline")
	if not accepts_windup: return
	var body := CharacterBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.35
	collider.shape = capsule
	collider.position.y = 0.68
	body.add_child(collider)
	body.position = Vector3(0, 0.03, 5)
	root.add_child(body)
	actors.append(body)
	await physics_frame
	var step = AttackStep.new()
	var definition := {"kind": "sweep", "windup": 0.18, "active": 0.11}
	step.begin("greatsword", 0, 0.0, 2.4375, 3.095, true)
	step.advance(body, 0.0, definition, [])
	_near(body.position.x, 0.0, "accepting an approach cannot teleport the body")
	step.advance(body, 0.09, definition, [])
	_near(body.position.x, 1.828125, "assisted approach consumes its cumulative ease-out budget during preparation")
	step.advance(body, 0.18, definition, [])
	_near(body.position.x, 2.4375, "assisted approach is fully in position at the original active-start boundary")
	for elapsed in [0.20, 0.29, 0.54, 5.0, 0.09]:
		step.advance(body, elapsed, definition, [])
	_near(body.position.x, 2.4375, "assisted active, recovery and older clock samples cannot replay or rewind approach travel")
	body.position.x = 0.0
	step.begin("greatsword", 0, 0.0, 0.28, 3.095)
	step.advance(body, 0.09, definition, [])
	_near(body.position.x, 0.0, "a subsequent ordinary attack resets approach mode and stays stationary in preparation")
	step.advance(body, 0.235, definition, [])
	_near(body.position.x, 0.21, "ordinary attacks retain the original three-quarter budget at half release")
	body.position.x = 0.0
	step.begin("mace", 1, 0.0, 1.74, 2.32, true)
	step.advance(body, 5.0, definition, [])
	_near(body.position.x, 0.0, "assisted Mace second stroke still receives zero helper movement")
	_near(step.distance, 0.0, "Mace second stroke keeps only its separate scaled authored lunge")


func _test_world_occlusion() -> void:
	# Real mask-1 geometry must exclude an enemy, while enemy-layer geometry must not.
	var target = _target(Vector3(2.7, 0, 0))
	var world: World3D = target.get_world_3d()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 1.5, 1.0)
	collider.shape = box
	wall.add_child(collider)
	wall.position = Vector3(1.3, 0.68, 0)
	root.add_child(wall)
	actors.append(wall)
	await physics_frame
	var blocked: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, {"reach": 2.0}, [target], world)
	_check(not blocked.assisted and blocked.target_id == 0, "solid world geometry blocks target selection at actor height")
	wall.collision_layer = 2
	await physics_frame
	var clear: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, {"reach": 2.0}, [target], world)
	_check(clear.assisted and clear.target_id == target.get_instance_id(), "selection ray ignores enemy-only collision geometry")
	wall.collision_layer = 1
	wall.position.y = -0.5
	await physics_frame
	var low_wall: Dictionary = Approach.new().choose("sword", 0, Vector3.ZERO, Vector3.RIGHT, {"reach": 2.0}, [target], world)
	_check(low_wall.assisted, "selection ray stays at .68 above the ground plane")
