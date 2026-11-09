extends Control
var owner_ui
var location: Dictionary
var id := ""
var texture: Texture2D
var blocked := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(94,86)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	var selected: bool = owner_ui.selected == location
	draw_style_box(owner_ui.slot_style(selected,blocked), Rect2(Vector2.ZERO,size))
	if texture != null:
		var native := texture.get_size()
		var factor := minf((size.x-16)/native.x,(size.y-30)/native.y)
		var extent := native * factor
		draw_texture_rect(texture, Rect2(Vector2((size.x-extent.x)/2,8+(size.y-30-extent.y)/2),extent),false)
	var caption: String = "ใช้สองมือ" if blocked else ("ว่าง" if id == "" else str(owner_ui.model.items[id].name))
	draw_string(get_theme_default_font(),Vector2(5,size.y-8),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x-10,13,Color("#9bacae") if id == "" else Color("#e8dfc9"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: owner_ui.clicked(location)
		elif event.button_index == MOUSE_BUTTON_RIGHT: owner_ui.remove_item(location)
		accept_event()

func _get_drag_data(_position: Vector2):
	if id == "": return null
	var preview := TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(90,60)
	set_drag_preview(preview)
	return {"arsenal":true,"source":location.duplicate()}

func _can_drop_data(_position: Vector2,data) -> bool:
	if blocked or not data is Dictionary or not data.get("arsenal",false) or not owner_ui.model.valid_location(data.get("source",{})): return false
	var incoming: String = owner_ui.model.item_at(data.source)
	if incoming == "": return false
	if location.kind == "slot" and location.hand == "off" and owner_ui.model.items[incoming].two_hand: return false
	return data.source != location

func _drop_data(_position: Vector2,data) -> void:
	owner_ui.transfer(data.source,location)
