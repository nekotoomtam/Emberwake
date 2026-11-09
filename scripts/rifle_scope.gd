extends CanvasLayer
## Soft framing aligned to the aim line, below gameplay icons and HUD.
var frame: ColorRect
var material: ShaderMaterial
func _ready() -> void:
 layer=3
 frame=ColorRect.new();frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
 material=ShaderMaterial.new();material.shader=preload("res://shaders/rifle_scope.gdshader");frame.material=material;add_child(frame)
func update_view(game) -> void:
 var focus: float=game.rifle_focus_state.amount()
 visible=focus>.0001 and game.mode in ["practice","combat"] and not game.inventory_open and not game.stats_open
 if not visible:return
 var size: Vector2=game.get_viewport().get_visible_rect().size
 var player: Vector3=game.player.position+game.camera.global_basis.y*1.10
 var center: Vector2=game.camera.unproject_position(player)
 var direction: Vector2=game.camera.unproject_position(player+game.aim)-center
 if direction.length_squared()<.00001:direction=Vector2.RIGHT
 material.set_shader_parameter("center",center/size);material.set_shader_parameter("axis",direction.normalized())
 material.set_shader_parameter("viewport_size",size);material.set_shader_parameter("focus",focus)
