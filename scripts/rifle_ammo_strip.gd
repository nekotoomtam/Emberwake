extends HBoxContainer

const EMPTY_TINT := Color(.62, .70, .78, .38)
const SLOT_SIZE := Vector2(22, 42)
const FEED_DISTANCE := 52.0
const CartridgeArt = preload("res://scripts/rifle_cartridge_art.gd")

var _feed: Tween
var _feed_progress := 0.0
var _fired_round := ""
var _remaining: Array[String] = []

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func show_rounds(queue: Array[String], capacity: int) -> void:
	if _feed != null and _remaining != queue:
		_finish_feed()
	while get_child_count() < capacity:
		var slot := TextureRect.new()
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.custom_minimum_size = SLOT_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
	for index in get_child_count():
		var slot: TextureRect = get_child(index)
		slot.visible = index < capacity
		var queue_index := capacity - 1 - index
		var loaded := queue_index >= 0 and queue_index < queue.size()
		slot.texture = CartridgeArt.texture(queue[queue_index] if loaded else "")
		slot.modulate = Color.WHITE if loaded else EMPTY_TINT
		slot.self_modulate.a = 0.0 if loaded and _feed != null else 1.0

func feed_shot(fired_round: String, remaining: Array[String]) -> void:
	if get_child_count() == 0: return
	_finish_feed()
	_fired_round = fired_round
	_remaining = remaining
	_set_feed_progress(0.0)
	_feed = create_tween()
	_feed.tween_method(_set_feed_progress, 0.0, 1.0, .18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_feed.finished.connect(_finish_feed)

func _set_feed_progress(value: float) -> void:
	_feed_progress = value
	queue_redraw()

func _finish_feed() -> void:
	if _feed != null: _feed.kill()
	_feed = null
	for slot: TextureRect in get_children():
		slot.self_modulate.a = 1.0
	queue_redraw()

func _draw() -> void:
	if _feed == null: return
	var slots := get_child_count()
	var right_slot: TextureRect = get_child(slots - 1)
	var spent_at := right_slot.position + Vector2.RIGHT * FEED_DISTANCE * _feed_progress
	_draw_cartridge(_fired_round, spent_at, 1.0 - _feed_progress)
	for index in _remaining.size():
		var destination: TextureRect = get_child(slots - 1 - index)
		var origin: TextureRect = get_child(slots - 2 - index)
		_draw_cartridge(_remaining[index], origin.position.lerp(destination.position, _feed_progress))

func _draw_cartridge(id: String, at: Vector2, alpha: float = 1.0) -> void:
	var fitted := Vector2(SLOT_SIZE.y * .5, SLOT_SIZE.y)
	draw_texture_rect(CartridgeArt.texture(id), Rect2(at + (SLOT_SIZE - fitted) * .5, fitted), false, Color(1, 1, 1, alpha))
