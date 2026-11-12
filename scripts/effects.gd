extends Node3D
const StaffIceVolleyArt = preload("res://scripts/staff_ice_volley_art.gd")
const StaffLv10Art = preload("res://scripts/staff_lv10_art.gd")
const StaffLv15Art = preload("res://scripts/staff_lv15_art.gd")
const StaffLv20Art = preload("res://scripts/staff_lv20_art.gd")
var _staff_breath_sprite: Sprite3D
const ParryClash=preload("res://scripts/parry_clash_visual.gd")
var clashes: Array[Node3D]=[]
var visibility_test: Callable
var clash_count:=0
var last_clash:=Vector3.ZERO
const FireBlastVisual = preload("res://scripts/fire_blast_visual.gd")
const FireballVisual = preload("res://scripts/fireball_visual.gd")
const MaceImpactVisual = preload("res://scripts/mace_impact_visual.gd")
const MaceBasicFlash = preload("res://scripts/mace_basic_flash.gd")
const MaceSweepVisual = preload("res://scripts/mace_sweep_visual.gd")
const MacePullVisual = preload("res://scripts/mace_pull_visual.gd")
const MaceFireScoopVisual = preload("res://scripts/mace_fire_scoop_visual.gd")
const MaceRiftVisual = preload("res://scripts/mace_rift_visual.gd")
const RifleCartridgeArt = preload("res://scripts/rifle_cartridge_art.gd")
const MaceLeapWaveVisual = preload("res://scripts/mace_leap_wave_visual.gd")
const BasicSwordSlash = preload("res://scripts/basic_sword_slash.gd")
const StormBladeCoat = preload("res://scripts/storm_blade_coat.gd")
const StormcallerRing = preload("res://scripts/stormcaller_ring_visual.gd")
const MACE_TRAIL_COLORS := {
	"basic_lift": Color("#c7d2da"), "basic_slam": Color("#dce3e8"),
	"mace_impact": Color("#d7a46d"), "mace_sweep": Color("#e9b260"),
	"mace_double_impact": Color("#ffae54"), "mace_gather": Color("#7af2d7"),
	"mace_fissure": Color("#ff6e34"), "mace_aftershock": Color("#6bc8b4"),
	"mace_earth_wave": Color("#ffcf77"), "mace_armor_counter": Color("#c7e5ed"),
}
var particles: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var fire_blasts: Array[Node3D] = []
var mace_impacts: Array[Sprite3D] = []
var _basic_slash: Node3D
var _double_slash: Node3D
var _spin_slash: Node3D
var _double_slash_spark_cast := -1
var _storm_blade_coat: MeshInstance3D
var _stormcaller_ring: Sprite3D
var _mace_swing_key := Vector2i(-1, -1)
var _mace_swing_blade: Dictionary = {}
var _mace_embers: Node3D
var _ember_gradient: GradientTexture2D
var mace_basic_flash: Sprite3D
var mace_sweep_flash: Sprite3D

func mace_impact_sprite(center: Vector3, radius: float, style: MaceImpactVisual.Style = MaceImpactVisual.Style.STANDARD) -> Sprite3D:
	var impact := MaceImpactVisual.new()
	impact.configure(center, radius, style)
	add_child(impact)
	mace_impacts.append(impact)
	return impact

func mace_ground_contact(center: Vector3, radius: float, strength: float) -> Sprite3D:
	var impact := MaceImpactVisual.new()
	impact.configure_contact(center, radius, strength)
	add_child(impact)
	mace_impacts.append(impact)
	return impact

func mace_pull_vortex(center: Vector3, radius: float) -> void:
	var vortex := MacePullVisual.new()
	vortex.configure(center, radius)
	add_child(vortex)
	mace_impacts.append(vortex)

func mace_rift_decal(center: Vector3, radius: float, angle: float, phase: MaceRiftVisual.Phase, duration: float) -> Sprite3D:
	var decal := MaceRiftVisual.new()
	decal.configure(center, radius, angle, phase, duration)
	add_child(decal, true)
	if phase != MaceRiftVisual.Phase.PLACEMENT:
		mace_impacts.append(decal)
	return decal

func mace_leap_wave(center: Vector3, radius: float, angle: float, arc: float, strength: float) -> void:
	var wave := MaceLeapWaveVisual.new()
	wave.configure(center, radius, angle, arc, strength)
	add_child(wave, true)
	mace_impacts.append(wave)

func mace_fire_scoop(origin: Vector3, mirrored: bool, soil: bool = false) -> Sprite3D:
	var flare := MaceFireScoopVisual.new()
	flare.configure(origin, mirrored, soil)
	add_child(flare)
	mace_impacts.append(flare)
	return flare

func mace_ember_impact(point: Vector3, direction: Vector3, leg: int, on_floor: bool) -> void:
	var strength: float = [1.0, .80, .66][leg]
	if on_floor:
		var impact := MaceImpactVisual.new()
		impact.name = "MaceEmberContact"
		impact.configure_ember_contact(point, .85 * strength)
		add_child(impact, true)
		mace_impacts.append(impact)
	mace_ember_spray(point, direction, strength, false)

func mace_ember_spray(point: Vector3, direction: Vector3, strength: float, scoop: bool) -> void:
	var center := point + Vector3.UP * .065
	var spark_count := roundi(11.0 * strength)
	for index in range(spark_count):
		var spread := lerpf(-1.2, 1.2, float(index) / (spark_count - 1))
		var speed := 1.05 + .49 * float(index % 4)
		var lift := .95 + .52 * float((index * 3) % 5)
		var drift := direction.rotated(Vector3.UP, spread) * speed
		var hot := index % 3 != 0
		var size := .14 if hot else .21
		var color := Color("#ffd084") if hot else Color("#be491d")
		_add_ember_mote(center, (drift + Vector3.UP * lift) * strength, size, color, .23 + .026 * float(index % 4), 5.0)
	if scoop:
		var glow := _add_ember_mote(center, Vector3.ZERO, 1.25, Color("#ff8a30", .85), .16)
		glow.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		glow.rotation.x = -PI * .5

func mace_ember_trail(point: Vector3, direction: Vector3, age: float) -> void:
	var offset := Vector3.UP * (sin(age * 90.0) * .08)
	_add_ember_mote(point - direction * .14 + offset, -direction * .48 + Vector3.UP * .11,
		.15, Color("#ffac54"), .18)
	if int(round(age / .036)) % 2 == 0:
		_add_ember_mote(point - direction * .22 - offset, Vector3.UP * .33 - direction * .36,
			.37, Color("#a94624", .67), .27)

func _add_ember_mote(point: Vector3, velocity: Vector3, size: float, color: Color, life: float, gravity: float = 0.0) -> Sprite3D:
	if _ember_gradient == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, .21, .56, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, .91, .65, .92),
			Color(1.0, .62, .33, .35), Color(1.0, .38, .20, 0.0)])
		_ember_gradient = GradientTexture2D.new()
		_ember_gradient.width = 32
		_ember_gradient.height = 32
		_ember_gradient.gradient = gradient
		_ember_gradient.fill = GradientTexture2D.FILL_RADIAL
		_ember_gradient.fill_from = Vector2(.5, .5)
		_ember_gradient.fill_to = Vector2(1.0, .5)
	var mote := Sprite3D.new()
	mote.texture = _ember_gradient
	mote.pixel_size = size / _ember_gradient.width
	mote.modulate = color
	mote.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mote)
	mote.global_position = point
	particles.append({"node": mote, "velocity": velocity, "life": life, "total": life,
		"gravity": gravity, "ember_opacity": color.a, "sight_point": point})
	return mote

func mace_basic_head(camera: Camera3D, tip: Vector3, forward: Vector3, progress: float, stage: int, left_hand: bool) -> void:
	if mace_basic_flash == null:
		mace_basic_flash = MaceBasicFlash.new()
		add_child(mace_basic_flash)
	mace_basic_flash.follow(camera, tip, forward, progress, stage, left_hand)

func mace_sweep_head(camera: Camera3D, tip: Vector3, tangent: Vector3, progress: float, strike: Vector2i, style: MaceSweepVisual.Style = MaceSweepVisual.Style.SWEEP) -> void:
	if mace_sweep_flash == null:
		mace_sweep_flash = MaceSweepVisual.new()
		add_child(mace_sweep_flash)
	mace_sweep_flash.follow(camera, tip, tangent, progress, strike, style)

func mace_swing(blade: Dictionary, key: Vector2i, skill_id: String) -> void:
	var previous := _mace_swing_blade
	_mace_swing_blade = blade
	if key != _mace_swing_key or blade.is_empty() or previous.is_empty():
		_mace_swing_key = key
		return
	var tip: Vector3 = blade.tip
	var old_tip: Vector3 = previous.tip
	var travel := tip.distance_squared_to(old_tip)
	if travel < .0004 or travel > 1.44: return
	var color: Color = MACE_TRAIL_COLORS[skill_id]
	var basic := skill_id in ["basic_lift", "basic_slam"]
	var basic_finisher := skill_id == "basic_slam"
	var lifetime := .15 if key.y == 1 or skill_id == "mace_earth_wave" else .105
	if basic: lifetime = .085 if key.y == 0 else .12
	var mark := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for inner_fraction: float in [.49 if basic_finisher else .61, .84 if basic_finisher else .91]:
		var old_inner: Vector3 = previous.grip.lerp(old_tip, inner_fraction)
		var inner: Vector3 = blade.grip.lerp(tip, inner_fraction)
		var rim := inner_fraction > .8
		var tint_color := Color("#fff0ca", .82) if rim else Color(color, .40)
		if basic: tint_color = Color("#f9fbff", .83 if basic_finisher else .72) if rim else Color(color, .46 if basic_finisher else .28)
		mesh.surface_set_color(tint_color)
		for point: Vector3 in [old_inner, old_tip, tip, old_inner, tip, inner]:
			mesh.surface_add_vertex(point - tip)
	mesh.surface_end()
	mark.mesh = mesh
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.material_override = tint(Color.WHITE)
	mark.material_override.vertex_color_use_as_albedo = true
	add_child(mark)
	mark.global_position = tip
	trails.append({"node": mark, "life": lifetime, "total": lifetime, "color": Color.WHITE})

func mace_ember_coat(camera: Camera3D, blade: Dictionary, time: float) -> void:
	if blade.is_empty():
		if _mace_embers != null: _mace_embers.hide()
		return
	if _mace_embers == null:
		_mace_embers = FireballVisual.new()
		_mace_embers.configure_contact(.10)
		add_child(_mace_embers)
	_mace_embers.global_position = blade.grip.lerp(blade.tip, .93)
	_mace_embers.update_visual(camera, Vector3.UP, time)
	_mace_embers.show()

func mace_ground_pulse(center: Vector3, radius: float, angle: float, arc: float, color: Color, inward: bool = false) -> void:
	var half_arc := arc * .5
	for band in [Vector3(.79, .36, .30), Vector3(.95, .90, .24)]:
		var rim_color := Color(color.lerp(Color.WHITE, .34 if band.x > .9 else .0), band.y)
		var rim := sector(center + Vector3.UP * (.07 if band.x > .9 else .05),
			radius, angle - half_arc, angle + half_arc, rim_color, radius * band.x, band.z, .08)
		rim.material_override.no_depth_test = false
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var scale_range := Vector2(1.0, .12) if inward else Vector2(.22, 1.0)
		rim.scale = Vector3(scale_range.x, 1.0, scale_range.x)
		trails.back()["radial_scale"] = scale_range
		trails.back()["sight_point"] = center

func basic_sword_slash(camera: Camera3D, grip: Vector3, tip: Vector3, progress: float, stage: int, left_hand: bool) -> void:
	if _basic_slash == null:
		_basic_slash = BasicSwordSlash.new()
		add_child(_basic_slash)
	_basic_slash.follow(camera, grip, tip, progress, stage, left_hand)

func spin_slash(camera: Camera3D, blade: Dictionary, progress: float, stage: int) -> void:
	if _spin_slash == null:
		_spin_slash = BasicSwordSlash.new()
		_spin_slash.smooth_spin = true
		add_child(_spin_slash)
	_spin_slash.follow(camera, blade.grip, blade.tip, progress, stage, false)

func storm_blade_coat(camera: Camera3D, blade: Dictionary, time: float, remaining: float) -> void:
	if blade.is_empty():
		if _storm_blade_coat != null: _storm_blade_coat.hide()
		return
	if _storm_blade_coat == null:
		_storm_blade_coat = StormBladeCoat.new()
		add_child(_storm_blade_coat)
	_storm_blade_coat.follow(camera, blade.grip, blade.tip, time, minf(1.0, remaining / 0.18))

func stormcaller_ring(origin: Vector3, radius: float, angle: float, final_sweep: bool) -> void:
	if _stormcaller_ring == null:
		_stormcaller_ring = StormcallerRing.new()
		add_child(_stormcaller_ring)
	_stormcaller_ring.follow(origin, radius, angle, final_sweep)

func vacuum_wake_segment(from: Vector3, to: Vector3) -> void:
	var side := from.direction_to(to).cross(Vector3.UP)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in [Vector2(0.17, 0.23), Vector2(0.035, 0.95)]:
		var across: Vector3 = side * band.x
		var lift := Vector3.ZERO if band.x < 0.1 else Vector3.DOWN * 0.003
		var end := to - from
		mesh.surface_set_color(Color("#eefaff", band.y) if band.x < 0.1 else Color("#6cbbd8", band.y))
		for vertex in [-across, across, end + across, -across, end + across, end - across]:
			mesh.surface_add_vertex(vertex + lift)
	mesh.surface_end()
	var mark := MeshInstance3D.new()
	mark.mesh = mesh
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := tint(Color.WHITE)
	material.no_depth_test = false
	material.vertex_color_use_as_albedo = true
	mark.material_override = material
	add_child(mark)
	mark.global_position = from
	trails.append({"node": mark, "life": 0.30, "total": 0.30, "color": Color.WHITE})

func staff_lightning_arc(from: Vector3, to: Vector3) -> void:
	if from.is_equal_approx(to):
		burst(to, Color("#cfb2ff"), 7)
		return
	var side := from.direction_to(to).cross(Vector3.UP).normalized()
	var points := PackedVector3Array([Vector3.ZERO])
	for index in range(1, 5):
		var shift := .15 if index % 2 == 0 else -.15
		points.append((to - from) * (index / 5.0) + side * shift + Vector3.UP * shift)
	points.append(to - from)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in [Vector2(.10, .35), Vector2(.027, .95)]:
		mesh.surface_set_color(Color("#a275ff", band.y) if band.x > .05 else Color("#f3e6ff", band.y))
		for index in range(points.size() - 1):
			var start := points[index]
			var end := points[index + 1]
			var edge: Vector3 = side * band.x
			for point in [start - edge, start + edge, end + edge, start - edge, end + edge, end - edge]:
				mesh.surface_add_vertex(point)
	mesh.surface_end()
	var arc := MeshInstance3D.new()
	arc.mesh = mesh
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := tint(Color.WHITE)
	material.no_depth_test = false
	material.vertex_color_use_as_albedo = true
	arc.material_override = material
	add_child(arc)
	arc.global_position = from
	trails.append({"node": arc, "life": .2, "total": .2, "color": Color.WHITE})
	burst(to, Color("#cfb2ff"), 7)

func staff_fire_breath(muzzle: Vector3, origin: Vector3, angle: float, half_angle: float, reach: float, camera: Camera3D, elapsed: float) -> void:
	var space := get_world_3d().direct_space_state
	var base := Vector3(origin.x, muzzle.y, origin.z)
	var muzzle_ray := PhysicsRayQueryParameters3D.create(base, muzzle, 1)
	muzzle_ray.hit_from_inside = true
	if not space.intersect_ray(muzzle_ray).is_empty():
		hide_staff_fire_breath()
		return
	var direction := Vector3(cos(angle), 0, sin(angle))
	var end := base + direction * reach
	var query := PhysicsRayQueryParameters3D.create(muzzle, end, 1)
	query.hit_from_inside = true
	var cover := space.intersect_ray(query)
	if not cover.is_empty(): end = cover.position
	var path := end - muzzle
	var projected := Vector2(camera.global_basis.x.dot(path), camera.global_basis.y.dot(path))
	if projected.length_squared() < .0025:
		hide_staff_fire_breath()
		return
	if not is_instance_valid(_staff_breath_sprite):
		_staff_breath_sprite = Sprite3D.new()
		_staff_breath_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_staff_breath_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_staff_breath_sprite.pixel_size = 1.0
		add_child(_staff_breath_sprite)
	var frame := int(elapsed * 18.0) % StaffLv10Art.FRAME_COUNT
	var length := projected.length() / StaffLv10Art.BREATH_LENGTH
	var width := minf(path.length() * .88, tan(half_angle) * reach) / StaffLv10Art.BREATH_WIDTH
	_staff_breath_sprite.texture = StaffLv10Art.breath_frame(frame)
	_staff_breath_sprite.offset = StaffLv10Art.breath_offset(frame)
	_staff_breath_sprite.global_transform = Transform3D(camera.global_basis * Basis(Vector3.BACK, projected.angle()) * Basis.from_scale(Vector3(length, width, 1)), muzzle)
	_staff_breath_sprite.show()

func hide_staff_fire_breath() -> void:
	if is_instance_valid(_staff_breath_sprite): _staff_breath_sprite.hide()

func staff_ice_volley_contact(at: Vector3) -> void:
	_staff_spell_contact(at, StaffIceVolleyArt, .0055)

func staff_chain_lightning_contact(at: Vector3) -> void:
	_staff_spell_contact(at, StaffLv10Art, .0048)

func staff_focus_flash(at: Vector3) -> void:
	_staff_spell_contact(at, StaffLv20Art, .0054, .38, StaffLv20Art.FOCUS_FLASH)

func staff_meteor_impact(center: Vector3, radius: float, camera: Camera3D) -> void:
	var visual_origin := center + Vector3.UP * .045 + camera.global_basis.z * radius * .30
	_staff_spell_contact(visual_origin, StaffLv20Art, radius / 205.0, .50)

func _staff_spell_contact(at: Vector3, art: Script, size: float, lifetime: float = .24, row: int = -1) -> void:
	if row < 0: row = art.IMPACT
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.pixel_size = size
	sprite.texture = art.frame(row, 0)
	sprite.offset = art.offset_3d(row, 0)
	add_child(sprite)
	sprite.global_position = at
	particles.append({"node": sprite, "velocity": Vector3.ZERO, "life": lifetime, "total": lifetime, "spell_art": art, "art_row": row})

func staff_ice_crystals(center: Vector3, radius: float, camera: Camera3D) -> void:
	var glow := Color("#91e5ff")
	sector(center + Vector3.UP * .06, radius, 0.0, TAU, Color(glow, .32), 0.0, .19)
	var visual_origin := center + Vector3.UP * .045 + camera.global_basis.z * radius * .30
	_staff_spell_contact(visual_origin, StaffLv15Art, radius / 260.0, .48)
	burst(center + Vector3.UP * .65, glow, 13)

func double_slash(camera: Camera3D, blade: Dictionary, pose: Dictionary, stage: int, cast_id: int) -> void:
	if _double_slash == null:
		_double_slash = BasicSwordSlash.new()
		_double_slash.double_slash = true
		add_child(_double_slash)
	_double_slash.follow(camera, blade.grip, blade.tip, pose.progress, stage, false)
	if stage == 1 and pose.progress >= 0.12 and _double_slash_spark_cast != cast_id:
		_double_slash_spark_cast = cast_id
		_double_slash_sparks(blade.tip, pose.angle)

func _double_slash_sparks(tip: Vector3, angle: float) -> void:
	var swing := Vector3(-sin(angle), 0.45, cos(angle)).normalized()
	var radial := Vector3(cos(angle), 0.0, sin(angle))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.028, 0.028, 0.085)
	for i in 5:
		var spread := float(i - 2) * 0.27
		var velocity := (swing + radial * spread + Vector3.UP * spread * 0.35).normalized() * (1.55 + float(i % 3) * 0.7)
		var spark := MeshInstance3D.new()
		spark.mesh = mesh
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.material_override = tint(Color("#eefbff") if i % 2 == 0 else Color("#75d6ff"))
		add_child(spark)
		spark.global_position = tip
		spark.look_at(tip + velocity)
		var life := 0.105 + float(i % 3) * 0.02
		particles.append({"node": spark, "velocity": velocity, "gravity": 1.5, "life": life, "total": life, "sight_point": tip})

func fire_blast(where: Vector3, radius: float, element: String, charged_camera: Camera3D = null) -> void:
	if element != "fire" or not where.is_finite() or not is_finite(radius) or radius <= 0: return
	var blast := FireBlastVisual.new()
	if is_instance_valid(charged_camera): blast.configure_charged_fire(where, radius, charged_camera)
	else: blast.configure(where, radius, element)
	add_child(blast)
	fire_blasts.append(blast)

func parry_clash(where: Vector3,perfect: bool=true) -> void:
	if not where.is_finite():return
	var clash:=ParryClash.new();clash.perfect=perfect;add_child(clash);clash.global_position=where
	clashes.append(clash);clash_count+=1;last_clash=where

func clear_transients() -> void:
	hide_staff_fire_breath()
	if _basic_slash != null: _basic_slash.clear()
	if _double_slash != null: _double_slash.clear()
	if _spin_slash != null: _spin_slash.clear()
	if _storm_blade_coat != null: _storm_blade_coat.hide()
	if _stormcaller_ring != null: _stormcaller_ring.hide()
	_mace_swing_blade = {}
	if _mace_embers != null: _mace_embers.hide()
	if mace_basic_flash != null: mace_basic_flash.hide()
	if mace_sweep_flash != null: mace_sweep_flash.hide()
	for clash in clashes:_remove_transient(clash)
	clashes.clear()
	for collection: Array in [particles, trails]:
		for entry: Dictionary in collection:
			_remove_transient(entry.node)
		collection.clear()
	for blast: Node3D in fire_blasts: _remove_transient(blast)
	fire_blasts.clear()
	for impact in mace_impacts: _remove_transient(impact)
	mace_impacts.clear()

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

func sector(origin: Vector3, radius: float, from_angle: float, to_angle: float, color: Color, inner: float = 0.0, lifetime: float = 0.12, rim_height: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var a: float = lerpf(from_angle, to_angle, i / 16.0)
		var b: float = lerpf(from_angle, to_angle, (i + 1) / 16.0)
		var pa := Vector3(cos(a), 0, sin(a))
		var pb := Vector3(cos(b), 0, sin(b))
		var outer_a := pa * radius + Vector3.UP * rim_height
		var outer_b := pb * radius + Vector3.UP * rim_height
		for v in [pa * inner, outer_a, outer_b, pa * inner, outer_b, pb * inner]:
			mesh.surface_add_vertex(v)
	mesh.surface_end()
	instance.mesh = mesh
	instance.material_override = tint(color)
	instance.position = origin
	add_child(instance)
	if lifetime > 0.0: trails.append({"node": instance, "life": lifetime, "total": lifetime, "color": color})
	return instance

func spinning_slash_wisps(origin: Vector3, reach: float, angle: float, swept: float) -> void:
	var span := absf(swept)
	if span < 0.12: return
	var turn := signf(swept)
	sector(origin + Vector3.UP * 0.19, reach * 0.94,
		angle - turn * minf(span, 0.50), angle - turn * 0.08,
		Color(.84, .98, 1.0, .34), reach * 0.90, .11, .12)
	if span >= 0.24:
		sector(origin - Vector3.UP * 0.38, reach * 0.88,
			angle - turn * minf(span, 0.72), angle - turn * 0.20,
			Color(.32, .73, .90, .27), reach * 0.82, .14, -.08)

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

func ground_cracks(origin: Vector3, angle: float, arc: float, inner: float, outer: float, color: Color, lifetime: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 8 if arc >= TAU - .001 else 5
	for ray in range(count):
		var ray_angle := angle + arc * ((ray + .5) / count - .5)
		var forward := Vector3(cos(ray_angle), 0, sin(ray_angle))
		var side := Vector3(-forward.z, 0, forward.x)
		var previous := forward * inner + side * sin(inner * 8.0 + ray) * .13 * minf(inner, 1.0)
		for segment in range(1, 5):
			var distance := lerpf(inner, outer, segment / 4.0)
			var point := forward * distance + side * sin(distance * 8.0 + ray) * .13 * minf(distance, 1.0)
			var width := side * .035
			for vertex in [previous - width, previous + width, point + width, previous - width, point + width, point - width]:
				mesh.surface_add_vertex(vertex)
			previous = point
	mesh.surface_end()
	instance.mesh = mesh
	instance.position = origin + Vector3.UP * .060
	var material := tint(color)
	material.no_depth_test = false
	instance.material_override = material
	add_child(instance)
	if lifetime > 0.0: trails.append({"node": instance, "life": lifetime, "total": lifetime, "color": color})
	return instance

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

func rifle_load_round(receiver: Vector3, direction: Vector3, camera: Camera3D, round_id: String) -> void:
	const DURATION := .18
	var round_sprite := Sprite3D.new()
	round_sprite.texture = RifleCartridgeArt.texture(round_id)
	round_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	round_sprite.pixel_size = .016
	round_sprite.no_depth_test = true
	round_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(round_sprite)
	var view := camera.global_basis
	var screen := Vector2(direction.dot(view.x), direction.dot(view.y))
	round_sprite.global_basis = view.rotated(view.z, screen.angle() - PI * .5)
	var offset := -direction * .38 + Vector3.UP * .19
	round_sprite.global_position = receiver + offset
	particles.append({"node": round_sprite, "velocity": -offset / DURATION,
		"life": DURATION, "total": DURATION, "sight_point": receiver})

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
	if _basic_slash != null: _basic_slash.tick(delta)
	if _double_slash != null: _double_slash.tick(delta)
	if _spin_slash != null: _spin_slash.tick(delta)
	if _stormcaller_ring != null: _stormcaller_ring.tick(delta)
	if mace_basic_flash != null: mace_basic_flash.tick(delta)
	if mace_sweep_flash != null: mace_sweep_flash.tick(delta)
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
	for impact: Sprite3D in mace_impacts.duplicate():
		if not impact.tick(delta):
			_remove_transient(impact)
			mace_impacts.erase(impact)
	for entry in particles.duplicate():
		entry.life -= delta
		if entry.life <= 0.0:
			entry.node.queue_free()
			particles.erase(entry)
			continue
		entry.node.position += entry.velocity * delta
		if entry.has("spell_art"):
			var art: Script = entry.spell_art
			var row: int = entry.art_row
			var progress := 1.0 - float(entry.life) / float(entry.total)
			var frame := mini(int(progress * art.FRAME_COUNT), art.FRAME_COUNT - 1)
			entry.node.texture = art.frame(row, frame)
			entry.node.offset = art.offset_3d(row, frame)
			entry.node.modulate.a = 1.0 - smoothstep(.65, 1.0, progress)
		elif entry.has("ember_opacity"):
			entry.velocity.y -= float(entry.gravity) * delta
			entry.node.modulate.a = float(entry.ember_opacity) * smoothstep(0.0, float(entry.total) * .72, float(entry.life))
		elif entry.node is MeshInstance3D:
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
		if entry.has("radial_scale"):
			var range_scale: Vector2 = entry.radial_scale
			var scale_factor := lerpf(range_scale.x, range_scale.y, ease(1.0 - entry.life / entry.total, .55))
			entry.node.scale = Vector3(scale_factor, 1.0, scale_factor)

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
