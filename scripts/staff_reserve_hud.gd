extends Control

const Charge = preload("res://scripts/staff_charge.gd")
const StaffLv20Art = preload("res://scripts/staff_lv20_art.gd")
const CORE := Vector2(177, 144)
const CORE_RADIUS := 57.0
const SLOTS := [
	Vector2(100, 150), Vector2(101, 116), Vector2(120, 87), Vector2(149, 68), Vector2(184, 64),
]
const TRAVEL_TIME := .22

var model: Charge
var _element := "fire"
var _flash := 0.0
var _orb_clock := 0.0
var _travelling: Array[Dictionary] = []

func bind(reserve: Charge) -> void:
	model = reserve
	model.orb_stored.connect(_store)
	model.orbs_spent.connect(_spend)
	model.orbs_prepended.connect(_prepend)

func _process(delta: float) -> void:
	if model == null or not is_visible_in_tree():
		_travelling.clear()
		return
	if _element != model.element:
		_element = model.element
		_flash = 1.0
	_orb_clock += delta
	_flash = move_toward(_flash, 0.0, delta * 4.0)
	for i in range(_travelling.size() - 1, -1, -1):
		var orb := _travelling[i]
		orb.elapsed += delta
		if orb.elapsed >= TRAVEL_TIME:
			if orb.slot < 0: _flash = 1.0
			_travelling.remove_at(i)
	queue_redraw()

func _store(slot: int, element: String) -> void:
	_flash = 1.0
	_move_orb(CORE - Vector2(9, 9), SLOTS[slot], element, slot, 5.0, 10.0)

func _take_travel_positions() -> Dictionary:
	var starts: Dictionary = {}
	for orb in _travelling:
		if orb.slot >= 0:
			starts[orb.slot] = _travel_position(orb)
	_travelling.clear()
	return starts

func _spend(previous: Array[String], removed: Array[int]) -> void:
	var starts := _take_travel_positions()
	var next_slot := 0
	for index in previous.size():
		var element := previous[index]
		if element.is_empty(): continue
		var from: Vector2 = starts.get(index, SLOTS[index])
		if index in removed:
			_move_orb(from, CORE - Vector2(9, 9), element, -1, 10.0, 5.0)
		else:
			var target: Vector2 = SLOTS[next_slot]
			if not from.is_equal_approx(target):
				_move_orb(from, target, element, next_slot, 10.0, 10.0)
			next_slot += 1

func _prepend(previous: Array[String], count: int) -> void:
	var starts := _take_travel_positions()
	var next_slot := count
	for index in previous.size():
		var element := previous[index]
		if element.is_empty(): continue
		var from: Vector2 = starts.get(index, SLOTS[index])
		if next_slot < SLOTS.size():
			_move_orb(from, SLOTS[next_slot], element, next_slot, 10.0, 10.0)
		else:
			var exit_point: Vector2 = SLOTS.back() + Vector2(38, -12)
			_move_orb(from, exit_point, element, -1, 10.0, 2.0)
		next_slot += 1
	for index in range(count):
		_store(index, Charge.NEUTRAL)

func _move_orb(from: Vector2, to: Vector2, element: String, slot: int, from_radius: float, to_radius: float) -> void:
	_travelling.append({"from": from, "to": to, "element": element, "slot": slot,
		"from_radius": from_radius, "to_radius": to_radius, "elapsed": 0.0})

func _travel_position(orb: Dictionary) -> Vector2:
	return orb.from.lerp(orb.to, smoothstep(0.0, 1.0, orb.elapsed / TRAVEL_TIME))

func _draw() -> void:
	if model == null: return
	var color: Color = Charge.ELEMENT_COLORS[model.element]
	var progress := clampf(model.load_elapsed / Charge.LOAD_TIME, 0.0, 1.0) if model.loading else 0.0
	draw_circle(CORE, CORE_RADIUS + 5.0, Color(.015, .025, .035, .85), true, -1.0, true)
	draw_circle(CORE, CORE_RADIUS, Color("#24303d"), true, -1.0, true)
	draw_circle(CORE, CORE_RADIUS - 4.0, color.darkened(.86), true, -1.0, true)
	for i in range(10):
		var radius := CORE_RADIUS - 6.0 - i * 4.0
		draw_circle(CORE - Vector2(3, 4), radius, Color(color, .023 + i * .003), true, -1.0, true)
	_draw_charge_fill(color, progress)
	draw_arc(CORE, CORE_RADIUS - 2.0, 0.0, TAU, 64, color.darkened(.38), 1.5, true)
	draw_arc(CORE, CORE_RADIUS - 8.0, PI * 1.03, PI * 1.62, 24, Color(color.lightened(.55), .55), 2.0, true)
	if progress > 0.0:
		draw_arc(CORE, CORE_RADIUS - 2.0, PI, PI + PI * .5 * progress, 24, color.lightened(.4), 3.0, true)
	if model.casting and model.cast_elapsed > 0.0:
		draw_arc(CORE, CORE_RADIUS + 3.0, PI, PI + PI * .52 * model.cast_elapsed / model.cast_time,
			24, Charge.ELEMENT_COLORS[model.cast_element].lightened(.5), 3.0, true)
	if model.focus_left > 0.0:
		draw_arc(CORE, CORE_RADIUS + 6.0, -PI / 2.0, -PI / 2.0 + TAU * model.focus_left / Charge.FOCUS_DURATION,
			64, Charge.ELEMENT_COLORS[Charge.NEUTRAL], 2.5, true)
	if model.switch_left > 0.0:
		draw_arc(CORE, CORE_RADIUS + 3.0, PI, PI + PI * .52 * model.switch_left / Charge.SWITCH_TIME,
			24, Color(color.lightened(.65), .9), 2.4, true)
	if _flash > 0.0:
		draw_arc(CORE, CORE_RADIUS + 2.0 + (1.0 - _flash) * 7.0, 0.0, TAU, 64, Color(color, _flash * .78), 3.0, true)
	_draw_glyph(model.element, CORE - Vector2(10, 10), 15.0, color.lightened(.55))
	var selected := model.casting_slots()
	for i in SLOTS.size():
		var at: Vector2 = SLOTS[i]
		draw_circle(at, 13.0, Color(.025, .04, .065, .88), true, -1.0, true)
		draw_arc(at, 12.0, 0.0, TAU, 30, Color("#566174"), 1.25, true)
		var arriving := _travelling.any(func(orb): return orb.slot == i)
		if model.slots[i] != "" and not arriving:
			_draw_orb(at, model.slots[i], 10.0, 1.0)
		if i in selected:
			var highlight: Color = Charge.ELEMENT_COLORS[model.slots[i]]
			draw_arc(at, 14.5, 0.0, TAU, 30, highlight.lightened(.55), 2.0, true)
	for orb in _travelling:
		var amount := smoothstep(0.0, 1.0, orb.elapsed / TRAVEL_TIME)
		_draw_orb(_travel_position(orb), orb.element, lerpf(orb.from_radius, orb.to_radius, amount), .92)

func _draw_charge_fill(color: Color, progress: float) -> void:
	if progress <= 0.0: return
	var radius := CORE_RADIUS - 6.0
	var start := asin(1.0 - 2.0 * progress)
	var points := PackedVector2Array()
	for i in range(37):
		var angle := lerpf(start, PI - start, i / 36.0)
		points.append(CORE + Vector2.from_angle(angle) * radius)
	draw_colored_polygon(points, Color(color, .51))
	draw_line(points[0], points[-1], color.lightened(.36), 2.0, true)

func _draw_orb(at: Vector2, element: String, radius: float, opacity: float) -> void:
	var color: Color = Charge.ELEMENT_COLORS[element]
	if element == Charge.NEUTRAL:
		var frame := int(_orb_clock * 8.0) % StaffLv20Art.FRAME_COUNT
		var texture := StaffLv20Art.frame(StaffLv20Art.FOCUS_ORB, frame)
		var size := texture.get_size() * (radius / 102.0)
		var offset := StaffLv20Art.offset(StaffLv20Art.FOCUS_ORB, frame) * (radius / 102.0)
		draw_texture_rect(texture, Rect2(at - size * .5 + offset, size), false, Color(1, 1, 1, opacity))
		draw_arc(at, radius - .6, 0.0, TAU, 24, Color(color, opacity * .72), 1.0, true)
		return
	draw_circle(at, radius, Color(color.darkened(.59), opacity), true, -1.0, true)
	draw_arc(at, radius - .6, 0.0, TAU, 24, Color(color, opacity), 1.3, true)
	draw_circle(at - Vector2(3, 4) * (radius / 10.0), radius * .17, Color(color.lightened(.6), opacity), true, -1.0, true)
	_draw_glyph(element, at, radius * .50, Color(color.lightened(.68), opacity))

func _draw_glyph(element: String, at: Vector2, radius: float, color: Color) -> void:
	match element:
		"fire":
			var flame := PackedVector2Array()
			for point in [Vector2(-.70,.42), Vector2(-.62,-.13), Vector2(-.18,-.63), Vector2(.02,-1.0),
					Vector2(.38,-.36), Vector2(.72,.05), Vector2(.64,.62), Vector2(.17,.91), Vector2(-.39,.81)]:
				flame.append(at + point * radius)
			draw_colored_polygon(flame, color)
		"ice":
			for i in 6:
				var angle := i * TAU / 6.0
				var tip := at + Vector2.from_angle(angle) * radius
				draw_line(at, tip, color, maxf(1.0, radius * .11), true)
				for side in [-1, 1]:
					draw_line(tip - Vector2.from_angle(angle) * radius * .28,
						tip - Vector2.from_angle(angle + side * .8) * radius * .35, color, 1.0, true)
		"lightning":
			var bolt := PackedVector2Array()
			for point in [Vector2(.12,-1), Vector2(-.67,.16), Vector2(-.08,.13), Vector2(-.24,1),
					Vector2(.68,-.20), Vector2(.09,-.16)]:
				bolt.append(at + point * radius)
			draw_colored_polygon(bolt, color)
