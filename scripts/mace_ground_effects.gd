extends RefCounted
## The placed rift keeps its world origin after the cast ends.
const EPSILON := .00000001
const RIFT_DURATION := 10.0
const RIFT_ECHO_DELAY := .24
const RIFT_CHARGES := 3
const RIFT_DAMAGE_FRACTION := .70
const LEAP_COLOR := Color("#efae63")
const LANDING_COLORS := [Color("#e9c28f"), Color("#ffb85f"), Color("#fff0bc")]
const GATHER_COLORS := [Color("#79b7ae"), Color("#78dfd0"), Color("#b9fff1")]
var generation := 0
var rift: Dictionary = {}
var echoes: Array[Dictionary] = []
var landing_markers: Array[MeshInstance3D] = []
var _landing_grade := 0

func show_charge_preview(fx, center: Vector3, angle: float, footprint: Dictionary, grade: int) -> void:
	if grade != _landing_grade:
		clear_landing()
		_landing_grade = grade
		var half_arc: float = footprint.arc * .5
		var radius: float = footprint.area_radius
		landing_markers.append(fx.sector(center, radius, -half_arc, half_arc, Color.WHITE, radius - .055, 0.0))
		if footprint.has("core_radius"):
			var core: float = footprint.core_radius
			landing_markers.append(fx.sector(center, core, -half_arc, half_arc, Color.WHITE, core - .035, 0.0))
		landing_markers.append(fx.sector(center, radius, -half_arc, half_arc, Color.WHITE, 0.0, 0.0))
		for marker in landing_markers:
			marker.material_override.no_depth_test = false
	var palette := LANDING_COLORS if footprint.has("core_radius") else GATHER_COLORS
	var color: Color = palette[grade - 1]
	for marker in landing_markers:
		marker.rotation.y = -angle
		marker.position = center + Vector3.UP * .055
	var fill: MeshInstance3D = landing_markers.back()
	fill.position.y -= .008
	landing_markers[0].material_override.albedo_color = Color(color, .9)
	if footprint.has("core_radius"):
		landing_markers[1].material_override.albedo_color = Color(color, .52)
	fill.material_override.albedo_color = Color(color, .16)

func clear_landing() -> void:
	_landing_grade = 0
	for marker in landing_markers:
		if is_instance_valid(marker):
			marker.hide()
			marker.queue_free()
	landing_markers.clear()

func place_rift(center: Vector3, radius: float, visual: Sprite3D = null, angle: float = 0.0) -> void:
	_clear_rift()
	rift = {"center": center, "radius": radius, "visual": visual, "angle": angle,
		"remaining": RIFT_DURATION, "charges": RIFT_CHARGES}

func advance_rift(delta: float) -> void:
	if rift.is_empty(): return
	rift.remaining -= delta
	if is_instance_valid(rift.visual):
		rift.visual.tick(delta)
	if rift.remaining <= EPSILON: _clear_rift()

func can_trigger_rift(contact: Vector3) -> bool:
	if rift.is_empty(): return false
	var center: Vector3 = rift.center
	return Vector2(contact.x - center.x, contact.z - center.z).length_squared() <= float(rift.radius) ** 2

func queue_rift_echo(hit_damage: Dictionary) -> void:
	echoes.append({"center": rift.center, "radius": rift.radius, "angle": rift.angle,
		"hit_damage": hit_damage, "remaining": RIFT_ECHO_DELAY})
	if not hit_damage.is_empty():
		rift.charges -= 1
		if rift.charges == 0: _clear_rift()

func advance_echoes(delta: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	for echo in echoes:
		echo.remaining -= delta
		if echo.remaining <= EPSILON:
			due.append(echo)
	for echo in due:
		echoes.erase(echo)
	return due

func _clear_rift() -> void:
	if rift.is_empty(): return
	if is_instance_valid(rift.visual):
		rift.visual.hide()
		rift.visual.queue_free()
	rift.clear()

func clear() -> void:
	_clear_rift()
	echoes.clear()
	clear_landing()
	generation += 1
