extends Control
const Charge=preload("res://scripts/greatsword_charge.gd")
var elapsed:=.0
func show_charge(time: float) -> void:elapsed=time;queue_redraw()
func _draw() -> void:
 var width: float=(size.x-8)/3.0
 for i in range(3):
  var rect:=Rect2(Vector2(i*(width+4),0),Vector2(width,size.y))
  draw_style_box(_box(Color(.07,.09,.11)),rect)
  var fill: float=1.0 if i==0 else clampf(elapsed/Charge.MID_TIME,0,1) if i==1 else clampf((elapsed-Charge.MID_TIME)/(Charge.FULL_TIME-Charge.MID_TIME),0,1)
  if fill>0:draw_rect(Rect2(rect.position,Vector2(width*fill,size.y)),Color(1,.72,.22) if elapsed>=Charge.FULL_TIME-.00001 else Color(.72,.43,.13))
  draw_rect(rect,Color(.9,.72,.4),false,1)
func _box(color: Color) -> StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=color;return box
