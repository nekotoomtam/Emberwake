extends Node3D
## One independently triggered cluster of poison spores.
const CloudShader = preload("res://shaders/dungeon_spore_cloud.gdshader")
const TRIGGER := 1.30
const RADIUS := 1.55
const WARNING := .55
const ACTIVE := 2.60
const COOLDOWN := 2.4
const PULSE := .65
const DAMAGE := 4.0
const INTEGRITY_LOSS := 1.0
var cloud: Node3D
var ring: MeshInstance3D
var _cycle := -1.0
var _next_pulse := WARNING


func setup(seed_: int) -> void:
	cloud = Node3D.new()
	add_child(cloud)
	var fog := PlaneMesh.new()
	fog.size = Vector2.ONE * (RADIUS * 2.0)
	_cloud_layer(fog, Vector3.UP * .13, 0.0, seed_)
	var plume := QuadMesh.new()
	plume.size = Vector2(RADIUS * 2.0, 1.43)
	_cloud_layer(plume, Vector3(0, .62, 0), -.58, seed_)
	cloud.hide()

	var outline := TorusMesh.new()
	outline.inner_radius = RADIUS - .045
	outline.outer_radius = RADIUS
	outline.rings = 40
	outline.ring_segments = 5
	var warning := StandardMaterial3D.new()
	warning.albedo_color = Color("#ebbd69")
	warning.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring = _mesh(outline, warning, Vector3.UP * .058)
	add_child(ring)
	ring.hide()


func _cloud_layer(mesh: Mesh, at: Vector3, tilt: float, seed_: int) -> void:
	var material := ShaderMaterial.new()
	material.shader = CloudShader
	material.render_priority = -1
	material.set_shader_parameter("phase", float(posmod(seed_, 628)) * .01)
	material.set_shader_parameter("plume", mesh is QuadMesh)
	var layer := _mesh(mesh, material, at)
	layer.rotation.x = tilt
	cloud.add_child(layer)


func _mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _in_spores(at: Vector3, radius: float) -> bool:
	var offset := at - global_position
	return Vector2(offset.x, offset.z).length_squared() <= radius * radius


func companion_motion(at: Vector3, motion: Vector3) -> Vector3:
	var offset := at - global_position
	offset.y = 0.0
	var forward := motion.normalized()
	var reach := clampf(-offset.dot(forward), 0.0, 2.75)
	var clearance := RADIUS + .44
	if (offset + forward * reach).length_squared() >= clearance * clearance: return motion
	if offset.length_squared() < .001: return Vector3.RIGHT * maxf(motion.length(), 3.0)
	var outward := offset.normalized()
	if offset.length() < RADIUS and _cycle >= 0.0 and _cycle < WARNING + ACTIVE:
		return outward * maxf(motion.length(), 3.0)
	if reach <= 0.0: return motion
	var tangent := Vector3(-outward.z, 0, outward.x)
	if tangent.dot(forward) < 0.0: tangent = -tangent
	return (tangent + outward * .35).normalized() * motion.length()


func tick(delta: float, game) -> void:
	if _cycle < 0.0:
		if not _has_trigger(game): return
		_cycle = 0.0
		_next_pulse = WARNING
	_cycle += delta
	while _next_pulse <= _cycle and _next_pulse < WARNING + ACTIVE:
		_poison(game)
		_next_pulse += PULSE
	var warning := _cycle < WARNING
	var active := not warning and _cycle < WARNING + ACTIVE
	ring.visible = warning
	cloud.visible = active
	if _cycle >= WARNING + ACTIVE + COOLDOWN: _cycle = -1.0


func _has_trigger(game) -> bool:
	if _in_spores(game.player.global_position, TRIGGER): return true
	for actor in game.companions:
		if not actor.downed and _in_spores(actor.global_position, TRIGGER): return true
	for actor in game.enemies:
		if is_instance_valid(actor) and not actor.dead and _in_spores(actor.global_position, TRIGGER): return true
	return false


func _poison(game) -> void:
	if _in_spores(game.player.global_position, RADIUS):
		game.receive_forest_poison(DAMAGE, INTEGRITY_LOSS)
	for actor in game.companions:
		if not actor.downed and _in_spores(actor.global_position, RADIUS):
			actor.receive_forest_poison(DAMAGE, INTEGRITY_LOSS)
	for actor in game.enemies:
		if is_instance_valid(actor) and not actor.dead and _in_spores(actor.global_position, RADIUS):
			actor.receive_burn(DAMAGE)
