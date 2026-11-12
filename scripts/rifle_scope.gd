extends CanvasLayer
## Soft framing aligned to the aim line, below gameplay icons and HUD.
var frame: ColorRect
var material: ShaderMaterial
var guide: Line2D
var zoom := 0.0
func _ready() -> void:
 layer=3
 frame=ColorRect.new();frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
 material=ShaderMaterial.new();material.shader=preload("res://shaders/rifle_scope.gdshader");frame.material=material;add_child(frame)
 guide=Line2D.new()
 guide.antialiased=true
 add_child(guide)
 hide()

func advance(delta: float, charging: bool) -> void:
 zoom=move_toward(zoom,1.0 if charging else 0.0,maxf(0.0,delta)*5.0)

func update_view(game) -> void:
 var charging: bool=game.rifle_finisher_charging()
 visible=zoom>.0001 and game.primary_family()=="rifle" and game.mode in ["practice","combat"] and not game.inventory_open and not game.stats_open and not game.body_lab_open and not game.sword_skills_open and not game.dungeon_peek.visible
 guide.visible=charging
 if not visible:return
 var size: Vector2=game.get_viewport().get_visible_rect().size
 var line: Dictionary=game.aimed_rifle_line(game._hand_pose(game.motion.sample()))
 var muzzle: Vector3=line.origin
 var center: Vector2=game.camera.unproject_position(muzzle)
 var direction: Vector2=game.camera.unproject_position(muzzle+line.direction)-center
 if direction.length_squared()<.00001:direction=Vector2.RIGHT
 material.set_shader_parameter("center",center/size);material.set_shader_parameter("axis",direction.normalized())
 material.set_shader_parameter("viewport_size",size);material.set_shader_parameter("focus",zoom)
 if charging:
  var flash: bool=game.motion.elapsed>=.88
  var end: Vector2=game.camera.unproject_position(muzzle+line.direction*game.RifleMotion.FINISHER_RANGE)
  guide.points=PackedVector2Array([center,end])
  guide.width=3.0 if flash else 1.25
  guide.default_color=Color("#e9fdff") if flash else Color(.63,.9,1.0,.6)
