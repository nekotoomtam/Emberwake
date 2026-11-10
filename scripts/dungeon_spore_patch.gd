extends Node3D
## One independently triggered cluster of poison spores.
const CloudShader = preload("res://shaders/dungeon_spore_cloud.gdshader")
const TRIGGER := 1.30
const RADIUS := 1.55
const WARNING := .55
const ACTIVE := 2.60
const COOLDOWN := 2.4
const PULSE := .65
const SANITY_PER_PULSE := 4
const PUFF_COUNT := 7
var cloud: Node3D
var ring: MeshInstance3D
var _cloud_material: ShaderMaterial
var _haze_material: ShaderMaterial
var _haze: MeshInstance3D
var _puffs: Array[MeshInstance3D] = []
var _puff_origins := PackedVector3Array()
var _cycle := -1.0
var _next_pulse := WARNING


func setup(seed_: int) -> void:
	cloud = Node3D.new()
	add_child(cloud)
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = CloudShader
	_cloud_material.render_priority = -1
	_haze_material = ShaderMaterial.new()
	_haze_material.shader = CloudShader
	_haze_material.render_priority = -2
	_haze_material.set_shader_parameter("ground_haze", true)
	var haze_mesh := PlaneMesh.new()
	haze_mesh.size = Vector2.ONE * (RADIUS * 2.0)
	_haze = _mesh(haze_mesh, _haze_material, Vector3.UP * .12)
	cloud.add_child(_haze)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var puff_mesh := QuadMesh.new()
	puff_mesh.size = Vector2(1.44, 1.24)
	for i in PUFF_COUNT:
		var angle := TAU * i / PUFF_COUNT + rng.randf_range(-.22, .22)
		var distance := rng.randf_range(.22, .77)
		var origin := Vector3(cos(angle) * distance, rng.randf_range(.23, .78), sin(angle) * distance)
		var puff := _mesh(puff_mesh, _cloud_material, origin)
		cloud.add_child(puff)
		_puffs.append(puff)
		_puff_origins.append(origin)
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


func _animate_cloud(elapsed: float) -> void:
	var fade_out := 1.0 - smoothstep(ACTIVE - .65, ACTIVE, elapsed)
	var density := smoothstep(0.0, .30, elapsed) * fade_out
	_cloud_material.set_shader_parameter("density", density)
	var rise := clampf(elapsed / ACTIVE, 0.0, 1.0)
	var haze_spread := smoothstep(0.0, .24, elapsed)
	_haze_material.set_shader_parameter("density", lerpf(.4, 1.0, haze_spread) * fade_out)
	_haze.scale = Vector3.ONE * lerpf(.94, 1.0, haze_spread)
	for i in _puffs.size():
		var puff := _puffs[i]
		var origin := _puff_origins[i]
		var sway := elapsed * 2.0 + i * 1.7
		puff.position = Vector3(origin.x * (.75 + rise * .40), origin.y + rise * .62, origin.z)
		puff.position += Vector3(sin(sway), sin(sway * .6), cos(sway)) * .10
		puff.scale = Vector3.ONE * (.76 + rise * .34 + .12 * sin(i * 2.3))


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
	if active:
		_animate_cloud(_cycle - WARNING)
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
		var available: int = game.SANITY_REVELATION - game.sanity
		if available > 0:
			game.add_sanity(mini(SANITY_PER_PULSE, available))
