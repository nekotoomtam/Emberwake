extends SceneTree

var checks := 0
var failures: Array[String] = []
var scene: Node3D
var manager
var camera: Camera3D
var wave_hits: Array[String] = []
var generic_hits := 0

class Target extends Node3D:
	var health := 100.0
	var dead := false
	func hurt_regions() -> Array:
		return [{"position": global_position, "radius": 0.2}]

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _run() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	camera = Camera3D.new()
	scene.add_child(camera)
	manager = load("res://scripts/staff_projectiles.gd").new()
	scene.add_child(manager)
	_check(manager.has_signal("sword_wave_hit"), "manager exposes the dedicated wave impact signal")
	if manager.has_signal("sword_wave_hit"):
		manager.sword_wave_hit.connect(func(enemy, damage: float, _knock: Vector3, kind: String):
			wave_hits.append(kind)
			enemy.health -= damage)
	manager.damage_hit.connect(func(_enemy, _damage, _knock, _element): generic_hits += 1)
	for radius in [0.45, 0.7]:
		_spawn(radius)
		var wave: Node3D = manager.active[0].node
		_check(wave.get_script().resource_path == "res://scripts/sword_wave_visual.gd", "sword skill chooses the distinct wave visual")
		if wave.get_script().resource_path == "res://scripts/sword_wave_visual.gd":
			var crest: Sprite3D = wave.get_node("wind_crest")
			_check(crest.frame == 0 and crest.hframes * crest.vframes == 4, "wave starts with the forming wind crest")
			var start_offset := crest.offset
			wave.update_visual(camera, Vector3.FORWARD, 0.25)
			var span: float = wave.ART_SPAN * crest.pixel_size * crest.global_basis.x.length()
			_check(span > radius * 2.0 and is_equal_approx(manager.active[0].radius, radius), "wind widens visually and preserves the swept radius")
			_check(crest.frame == 2 and crest.offset != start_offset, "rolling crest advances and uses its registered front")
			_check(crest.global_basis.y.normalized().dot(Vector3.FORWARD) > 0.999, "crest faces along ground aim")
			wave.update_visual(camera, Vector3.RIGHT, 0.5)
			_check(crest.frame == 3 and crest.modulate.a < 1.0, "wind breaks and fades during flight")
		manager.clear()
	var near_target := Target.new()
	var far_target := Target.new()
	scene.add_child(near_target)
	scene.add_child(far_target)
	near_target.position = Vector3(2, 0.9, 0)
	far_target.position = Vector3(3, 0.9, 0)
	_spawn(0.45)
	manager.tick(10.0, [far_target, near_target], scene.get_world_3d(), Callable(), camera)
	_check(near_target.health == 88.0 and far_target.health == 100.0, "wave damages only first enemy using shared swept contact")
	_check(manager.active.is_empty() and manager.resolved.back().reason == "enemy", "first enemy consumes wave")
	_check(wave_hits == ["sword_wave"] and generic_hits == 0, "ordinary wave emits one dedicated hit and no generic damage")
	manager.clear()
	near_target.health = 100.0
	var vacuum_definition := {"element": "physical", "projectile_visual": "vacuum_wave", "damage": 12.0, "projectile_radius": 0.8, "projectile_speed": 8.0, "projectile_range": 4.0}
	var wake: Array[Vector3] = []
	var wake_starts: Array[Vector3] = []
	manager.vacuum_wake_segment.connect(func(from: Vector3, to: Vector3):
		wake_starts.append(from)
		wake.append(to))
	_check(manager.spawn_fireball(Vector3(0, 0.9, 0), Vector3.RIGHT, vacuum_definition, camera), "vacuum wave spawns")
	var vacuum: Node3D = manager.active[0].node
	var foot_offset: float = vacuum.ground_anchor(Vector3.ZERO, Vector3.RIGHT, .8, 0).x
	_check(vacuum.get_script().resource_path == "res://scripts/vacuum_wave_visual.gd", "vacuum uses its upright split air blade visual")
	if vacuum.get_script().resource_path == "res://scripts/vacuum_wave_visual.gd":
		var blade: MeshInstance3D = vacuum.get_node("spine")
		_check(blade.mesh.get_aabb().size.y > 1.5, "vacuum blade has upright height distinct from flat crescent")
		var fork: Node3D = vacuum.get_node("wisps")
		var prior := fork.basis
		vacuum.update_visual(camera, Vector3.RIGHT, 0.3)
		_check(not fork.basis.is_equal_approx(prior), "vacuum wind forks twist through flight")
	# Shot payload must be captured at spawn, independent of subsequent caster state.
	vacuum_definition.projectile_visual = "sword_wave"
	vacuum_definition.damage = 99.0
	manager.tick(0.25, [far_target, near_target], scene.get_world_3d(), Callable(), camera)
	_check(near_target.health == 88.0 and not manager.active.is_empty(), "vacuum continues past the first target")
	var spine: MeshInstance3D = vacuum.get_node("spine")
	var vertices: PackedVector3Array = spine.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var foot := vertices[0]
	for vertex in vertices:
		if vertex.y < foot.y: foot = vertex
	_check(not wake.is_empty() and wake.back().distance_to(spine.to_global(foot)) < 0.0001, "wake attaches to the actual bottom vertex of the wind blade")
	_check(is_zero_approx(wake_starts.front().x), "wake starts at the launch point rather than behind the caster")
	manager.tick(10.0, [far_target, near_target], scene.get_world_3d(), Callable(), camera)
	_check(near_target.health == 88.0 and far_target.health == 88.0, "vacuum uses launched damage once on each target")
	_check(wave_hits == ["sword_wave", "vacuum_wave", "vacuum_wave"] and generic_hits == 0, "each pierced enemy receives one dedicated damage event")
	_check(manager.resolved.back().reason == "range" and manager.resolved.back().hitids == [near_target.get_instance_id(), far_target.get_instance_id()], "piercing reaches full range and tracks targets in contact order")
	_check(not wake.is_empty() and is_equal_approx(wake.back().x, 4.0 + foot_offset), "wake ends at the blade base at full range")
	manager.clear()
	_spawn(0.7)
	manager.tick(100.0, [], scene.get_world_3d(), _hit, camera)
	_check(manager.active.is_empty() and manager.resolved.back().reason == "range", "unhit wave expires at finite range")
	_check(is_equal_approx(manager.resolved.back().position.x, 4.0), "large delta retains exact range")
	manager.clear()
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2, 3)
	shape.shape = box
	wall.add_child(shape)
	scene.add_child(wall)
	wall.position = Vector3(1, 0.9, 0)
	await physics_frame
	await physics_frame
	_spawn(0.45)
	manager.tick(10.0, [near_target], scene.get_world_3d(), _hit, camera)
	_check(manager.active.is_empty() and manager.resolved.back().reason == "cover", "wall consumes wave before enemy")
	_check(near_target.health == 88.0, "wave cannot damage through solid wall")
	manager.clear()
	wake.clear()
	vacuum_definition.projectile_visual = "vacuum_wave"
	_check(manager.spawn_fireball(Vector3(0, 0.9, 0), Vector3.RIGHT, vacuum_definition, camera), "piercing wave can spawn against cover")
	manager.tick(10.0, [near_target, far_target], scene.get_world_3d(), Callable(), camera)
	_check(manager.active.is_empty() and manager.resolved.back().reason == "cover", "vacuum pierces enemies and stops at cover")
	_check(not wake.is_empty() and is_equal_approx(wake.back().x, manager.resolved.back().position.x + foot_offset) and near_target.health == 88.0, "wake stops at the blade base when it reaches cover")
	scene.free()
	print("SWORD_WAVE: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _spawn(radius: float) -> void:
	_check(manager.spawn_fireball(Vector3(0, 0.9, 0), Vector3.RIGHT, {"element": "physical", "projectile_visual": "sword_wave", "damage": 12.0, "projectile_radius": radius, "projectile_speed": 8.0, "projectile_range": 4.0}, camera), "wave spawns")

func _hit(enemy, damage: float, _knock: Vector3) -> void:
	enemy.health -= damage
