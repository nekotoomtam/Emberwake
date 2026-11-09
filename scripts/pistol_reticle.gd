extends CanvasLayer
## Cursor brackets show the actual dispersion; no aim ray or screen vignette.
var drawer: Node2D
var center:=Vector2.ZERO
var radius:=28.0
func _ready() -> void:
 layer=9;drawer=Node2D.new();add_child(drawer);drawer.draw.connect(_draw)
func update_view(game) -> void:
 visible=game.primary_family() in ["pistol","rifle"] and game.mode in ["practice","combat"] and not game.inventory_open and not game.stats_open
 if not visible:return
 center=game._mouse_position
 if game.test_aim.length_squared()>.001:center=game.camera.unproject_position(game.player.position+game.test_aim.normalized()*5)
 radius=maxf(8,4+3*rad_to_deg(game.gun_spread(game.primary_family(),game.right_action()=="aim")))
 drawer.queue_redraw()
func _draw() -> void:
 for side in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
  var corner: Vector2=center+side*radius
  var points:=PackedVector2Array([corner-Vector2(side.x*7,0),corner,corner-Vector2(0,side.y*7)])
  drawer.draw_polyline(points,Color(.02,.03,.04,.9),4,true)
  drawer.draw_polyline(points,Color(.86,.94,.98,.95),2,true)
