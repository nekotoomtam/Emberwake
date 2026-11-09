extends Node3D
const ParryClash=preload("res://scripts/parry_clash_visual.gd")
var clashes: Array[Node3D]=[]
var visibility_test: Callable
var clash_count:=0
var last_clash:=Vector3.ZERO
const FireBlastVisual = preload("res://scripts/fire_blast_visual.gd")
var particles: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var fire_blasts: Array[Node3D] = []

func fire_blast(where: Vector3, radius: float, element: String) -> void:
	if element != "fire" or not where.is_finite() or not is_finite(radius) or radius <= 0: return
	var blast := FireBlastVisual.new()
	blast.configure(where, radius, element)
	add_child(blast)
	fire_blasts.append(blast)

func parry_clash(where: Vector3,perfect: bool=true) -> void:
	if not where.is_finite():return
	var clash:=ParryClash.new();clash.perfect=perfect;add_child(clash);clash.global_position=where
	clashes.append(clash);clash_count+=1;last_clash=where

func clear_transients() -> void:
	for clash in clashes:_remove_transient(clash)
	clashes.clear()
	for collection: Array in [particles, trails]:
		for entry: Dictionary in collection:
			_remove_transient(entry.node)
		collection.clear()
	for blast: Node3D in fire_blasts: _remove_transient(blast)
	fire_blasts.clear()

func _remove_transient(node: Node) -> void:
	if not is_instance_valid(node): return
	if node.get_parent() == self: remove_child(node)
	node.queue_free()

func tint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material

func sector(origin: Vector3, radius: float, from_angle: float, to_angle: float, color: Color, inner: float = 0.0, lifetime: float = 0.12) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var a: float = lerpf(from_angle, to_angle, i / 16.0)
		var b: float = lerpf(from_angle, to_angle, (i + 1) / 16.0)
		var pa := Vector3(cos(a), 0, sin(a))
		var pb := Vector3(cos(b), 0, sin(b))
		for v in [pa * inner, pa * radius, pb * radius, pa * inner, pb * radius, pb * inner]:
			mesh.surface_add_vertex(v)
	mesh.surface_end()
	instance.mesh = mesh
	instance.material_override = tint(color)
	instance.position = origin
	add_child(instance)
	trails.append({"node": instance, "life": lifetime, "total": lifetime, "color": color})
	return instance

func legacy_sword_trail(origin: Vector3, reach: float, previous_angle: float, current_angle: float) -> void:
	var swing_sign := signf(current_angle - previous_angle)
	if swing_sign == 0.0: return
	# Exact two-layer fan from the archived ordinary Sword's first two cuts.
	sector(origin + Vector3(0, .68, 0), reach, current_angle - swing_sign * .72, current_angle, Color(.55, .95, .91, .7), reach * .5, .12)
	sector(origin + Vector3(0, .69, 0), reach, current_angle - swing_sign * .4, current_angle, Color(1, 1, .85, .9), reach - .07, .09)

func ring(where: Vector3, radius: float, color: Color, lifetime: float = 0.2) -> void:
	sector(where + Vector3(0, 0.035, 0), radius, 0, TAU, color, radius - 0.05, lifetime)

func sword_edge(origin: Vector3, from_pose: Dictionary, to_pose: Dictionary, color: Color, lifetime: float) -> void:
	_blade_sweep(origin, from_pose, to_pose, color, lifetime, .86, .28)

func sword_swing_wind(origin: Vector3, from_pose: Dictionary, to_pose: Dictionary, heavy: bool) -> void:
	# Reconstruct the recent authored sweep so emission cadence leaves no gaps.
	var from_release := pow(float(from_pose.get("progress", 0)), 2)
	var to_release := pow(float(to_pose.get("progress", 0)), 2)
	if to_release - from_release <= .000001: return
	var turn := wrapf(float(to_pose.angle) - float(from_pose.angle), -PI, PI)
	var slope := turn / (to_release - from_release)
	if absf(slope) <= .000001: return
	var recent_release := maxf(0, to_release - .60 / absf(slope))
	var recent := to_pose.duplicate()
	recent.angle = float(to_pose.angle) - slope * (to_release - recent_release)
	recent.pitch = lerpf(.32, -.24, recent_release) if heavy else 0.0
	var reach := float(to_pose.radius) + cos(float(to_pose.pitch)) * float(to_pose.blade_length)
	recent.radius = reach - cos(float(recent.pitch)) * float(to_pose.blade_length)
	var body := Color(1, .76, .32, .35) if heavy else Color(.55, .95, .91, .30)
	_blade_sweep(origin, recent, to_pose, body, .15 if heavy else .12, .45, .85)
	_blade_sweep(origin, recent, to_pose, Color(1, 1, .85, .75), .11 if heavy else .09, .94, .65)

func _blade_sweep(origin: Vector3, from_pose: Dictionary, to_pose: Dictionary, color: Color, lifetime: float, inner: float, max_span: float) -> void:
	# Trace the real blade endpoints. Both edge and wind meshes have no hitbox.
	var turn := wrapf(float(to_pose.angle) - float(from_pose.angle), -PI, PI)
	var pitch_turn := float(to_pose.pitch) - float(from_pose.pitch)
	var span := maxf(absf(turn), absf(pitch_turn))
	if span <= 0.000001: return
	var begin := maxf(0.0, 1.0 - max_span / span)
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(6):
		var a := lerpf(begin, 1.0, index / 6.0)
		var b := lerpf(begin, 1.0, (index + 1) / 6.0)
		var edges: Array[Vector3] = []
		for fraction: float in [a, b]:
			var angle := float(from_pose.angle) + turn * fraction
			var pitch := lerpf(from_pose.pitch, to_pose.pitch, fraction)
			var forward := Vector3(cos(angle), 0, sin(angle))
			var grip := forward * lerpf(from_pose.radius, to_pose.radius, fraction) + Vector3.UP * lerpf(from_pose.grip_height, to_pose.grip_height, fraction)
			var blade := (forward * cos(pitch) + Vector3.UP * sin(pitch)) * float(to_pose.blade_length)
			edges.append(grip + blade * inner)
			edges.append(grip + blade)
		for point in [edges[0], edges[1], edges[3], edges[0], edges[3], edges[2]]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	instance.mesh = mesh
	instance.position = origin
	instance.material_override = tint(color)
	add_child(instance)
	trails.append({"node": instance, "life": lifetime, "total": lifetime, "color": color})

func blade_ribbon(origin: Vector3, angle: float, radius: float, length: float, from_pitch: float, to_pitch: float, from_height: float, to_height: float, color: Color, lifetime: float) -> void:
	var forward := Vector3(cos(angle), 0, sin(angle))
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(12):
		var a: float = i / 12.0
		var b: float = (i + 1) / 12.0
		var pa: float = lerpf(from_pitch, to_pitch, a)
		var pb: float = lerpf(from_pitch, to_pitch, b)
		var ga := forward * radius + Vector3.UP * lerpf(from_height, to_height, a)
		var gb := forward * radius + Vector3.UP * lerpf(from_height, to_height, b)
		var va := (forward * cos(pa) + Vector3.UP * sin(pa)) * length
		var vb := (forward * cos(pb) + Vector3.UP * sin(pb)) * length
		for point in [ga + va * 0.45, ga + va, gb + vb, ga + va * 0.45, gb + vb, gb + vb * 0.45]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	instance.mesh = mesh
	instance.position = origin
	instance.material_override = tint(color)
	add_child(instance)
	trails.append({"node": instance, "life": lifetime, "total": lifetime, "color": color})

func lane(origin: Vector3, angle: float, length: float, width: float, color: Color, lifetime: float) -> void:
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	var forward := Vector3(cos(angle), 0, sin(angle))
	var side := Vector3(-forward.z, 0, forward.x) * width * 0.5
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [-side, side, forward * length + side, -side, forward * length + side, forward * length - side]:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	instance.mesh = mesh
	instance.position = origin + Vector3(0, 0.036, 0)
	instance.material_override = tint(color)
	add_child(instance)
	trails.append({"node": instance, "life": lifetime, "total": lifetime, "color": color})

func burst(where: Vector3, color: Color, count: int = 10, sight_point: Vector3=Vector3.INF) -> void:
	for i in range(count):
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * randf_range(0.035, 0.09)
		piece.mesh = mesh
		piece.material_override = tint(color)
		piece.position = where
		add_child(piece)
		particles.append({"node": piece, "velocity": Vector3(randf_range(-2.5, 2.5), randf_range(1.0, 3.5), randf_range(-2.5, 2.5)), "life": 0.4, "total": 0.4,"sight_point":sight_point})

func number(where: Vector3, text: String, heavy: bool = false, sight_point: Vector3=Vector3.INF) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 46 if heavy else 34
	label.pixel_size = 0.005
	label.modulate = Color("#ffcf78") if heavy else Color("#fff6d4")
	label.outline_size = 8
	label.position = where
	label.no_depth_test = true
	add_child(label)
	particles.append({"node": label, "velocity": Vector3(randf_range(-0.3, 0.3), 1.1, 0), "life": 0.65, "total": 0.65,"sight_point":sight_point})

func tick(delta: float) -> void:
	for clash in clashes.duplicate():
		if not is_instance_valid(clash):clashes.erase(clash)
		elif not clash.tick(delta):
			_remove_transient(clash);clashes.erase(clash)
	for blast: Node3D in fire_blasts.duplicate():
		if not is_instance_valid(blast):
			fire_blasts.erase(blast)
		elif not blast.tick(delta):
			_remove_transient(blast)
			fire_blasts.erase(blast)
	for entry in particles.duplicate():
		entry.life -= delta
		if entry.life <= 0.0:
			entry.node.queue_free()
			particles.erase(entry)
			continue
		entry.node.position += entry.velocity * delta
		if entry.node is MeshInstance3D:
			entry.velocity.y -= float(entry.get("gravity", 6.0)) * delta
			entry.node.scale = Vector3.ONE * (entry.life / entry.total)
		else:
			entry.node.modulate.a = minf(1.0, entry.life * 4)
	for entry in trails.duplicate():
		entry.life -= delta
		if entry.life <= 0.0:
			entry.node.queue_free()
			trails.erase(entry)
			continue
		var color: Color = entry.color
		color.a *= entry.life / entry.total
		entry.node.material_override.albedo_color = color

# Visuals only: contact and armor status remain owned by Game and Enemy.
func armor_thrust(origin: Vector3, angle: float, reach: float) -> void:
	if not origin.is_finite() or not is_finite(angle) or not is_finite(reach) or reach <= 0: return
	var forward := Vector3(cos(angle), 0, sin(angle))
	var side := Vector3(-forward.z, 0, forward.x)
	# Match Q's cyan body / ivory edge, tapered along the stab's real reach.
	for layer: Dictionary in [
		{"width": .22, "height": .68, "life": .12, "color": Color(.55, .95, .91, .7)},
		{"width": .065, "height": .69, "life": .09, "color": Color(1, 1, .85, .9)}]:
		var instance := MeshInstance3D.new()
		var mesh := ImmediateMesh.new()
		var start := forward * minf(.35, reach * .2) + Vector3.UP * float(layer.height)
		var shoulder := forward * reach * .72 + Vector3.UP * float(layer.height)
		var tip := forward * reach + Vector3.UP * float(layer.height)
		var half_width := side * float(layer.width)
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for point in [start, shoulder - half_width, tip, start, tip, shoulder + half_width]:
			mesh.surface_add_vertex(point)
		mesh.surface_end()
		instance.mesh = mesh
		instance.position = origin
		instance.material_override = tint(layer.color)
		add_child(instance)
		trails.append({"node": instance, "life": layer.life, "total": layer.life, "color": layer.color})

func armor_break(where: Vector3,sight_point: Vector3=Vector3.INF) -> void:
	if not where.is_finite(): return
	# Fractured gold impact rays are independent from the persistent Enemy badge.
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(8):
		var angle := index * TAU / 8.0
		var direction := Vector3(cos(angle), sin(angle), 0)
		var tangent := Vector3(-direction.y, direction.x, 0) * .026
		var mid := direction * .20 + tangent * (2 if index % 2 else -2)
		for point in [direction * .08 - tangent, mid + tangent, mid - tangent, mid - tangent, mid + tangent, direction * .47]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	instance.mesh = mesh
	instance.position = where + Vector3.UP * .3
	var color := Color(1, .72, .22, 1)
	instance.material_override = tint(color)
	add_child(instance)
	trails.append({"node": instance, "life": .28, "total": .28, "color": color,"sight_point":sight_point})


# One burst at thrust release. Visual air only; no gameplay random state or hitbox.
func thrust_wind(origin: Vector3, angle: float, reach: float) -> void:
	if not origin.is_finite() or not is_finite(angle) or not is_finite(reach) or reach <= 0: return
	var forward := Vector3(cos(angle), 0, sin(angle))
	var side := Vector3(-forward.z, 0, forward.x)
	for index in range(10):
		var theta := index * TAU / 10.0
		var radial := side * cos(theta) + Vector3.UP * sin(theta)
		var instance := MeshInstance3D.new()
		var mesh := ImmediateMesh.new()
		var half_width := radial * (.025 if index % 2 else .045)
		var length := .50 + .10 * (index % 4)
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for point in [-half_width, half_width, forward * length]: mesh.surface_add_vertex(point)
		mesh.surface_end()
		instance.mesh = mesh
		instance.position = origin + Vector3.UP * .68 + forward * (.4 + .1 * (index % 3)) + radial * .45
		instance.material_override = tint(Color(.7, 1, .96, .8) if index % 2 else Color(1, 1, .85, .9))
		add_child(instance)
		var life := .16 + .015 * (index % 3)
		particles.append({"node": instance, "velocity": forward * maxf(0, minf(8, (reach - 1.40) / .19)) + radial * .9, "gravity": 0.0, "life": life, "total": life})
	var ring := MeshInstance3D.new()
	var ring_mesh := ImmediateMesh.new()
	ring_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(20):
		var a := index * TAU / 20.0
		var b := (index + 1) * TAU / 20.0
		var va := side * cos(a) + Vector3.UP * sin(a)
		var vb := side * cos(b) + Vector3.UP * sin(b)
		for point in [va * .54, va * .61, vb * .61, va * .54, vb * .61, vb * .54]: ring_mesh.surface_add_vertex(point)
	ring_mesh.surface_end()
	ring.mesh = ring_mesh
	ring.position = origin + Vector3.UP * .68 + forward * .55
	var color := Color(.65, 1, .95, .65)
	ring.material_override = tint(color)
	add_child(ring)
	trails.append({"node": ring, "life": .16, "total": .16, "color": color})

func refresh_visibility() -> void:
	if not visibility_test.is_valid():return
	for collection: Array in [particles,trails]:
		for entry: Dictionary in collection:
			var point: Vector3=entry.get("sight_point",Vector3.INF)
			if point.is_finite() and is_instance_valid(entry.node):entry.node.visible=visibility_test.call(point)
