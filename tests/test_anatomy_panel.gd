extends SceneTree
const UI = preload("res://scripts/anatomy_panel.gd")
const Body = preload("res://scripts/anatomy_state.gd")
class FakeGame:
 extends Node
 var anatomy:=Body.new()
 var body_lab_open:=false
 var last_hit: Array=[]
 var health:=100.0
 func max_health() -> float:return 100.0
 func toggle_body_lab() -> void:body_lab_open=not body_lab_open
 func set_body_integrity(id: String,value: float) -> void:anatomy.set_integrity(id,value)
 func remove_body_part(id: String) -> void:anatomy.remove(id)
 func restore_body_part(id: String) -> void:anatomy.restore(id)
 func hit_body_part(id: String,value: float,red: bool=false) -> void:last_hit=[id,value,red]
 func restore_body() -> void:
  anatomy.reset()
 func set_debug_health_zero() -> void:health=0.0
var failures:=0
func expect(value: bool,message: String) -> void:
 if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game:=FakeGame.new()
 root.add_child(game)
 var panel=UI.new()
 panel.game=game
 game.add_child(panel)
 await process_frame
 for viewport in [Vector2i(1280,800),Vector2i(1024,640)]:
  root.content_scale_size=viewport
  root.size=viewport
  await process_frame
  await process_frame
  var rect: Rect2=panel.compact.get_global_rect()
  expect(rect.position.is_equal_approx(Vector2(20,124)),"Compact anchor at %s: %s"%[viewport,rect])
  expect(rect.size.x<=125 and rect.end.y<=300,"Compact fits below the health HUD")
  expect(panel.surface.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Closed HUD passes input")
  panel.toggle()
  await process_frame
  await process_frame
  var modal_panel: Control=panel.modal.get_child(1).get_child(0)
  var modal_rect: Rect2=modal_panel.get_global_rect()
  expect(Rect2(Vector2.ZERO,Vector2(viewport)).encloses(modal_rect),"Modal fits %s: %s"%[viewport,modal_rect])
  panel.toggle()
 expect(panel.diagram.states.size()==10,"Exactly ten body states")
 panel._select("right_lower_leg")
 panel._set_integrity(30.0)
 expect(game.anatomy.integrity.right_lower_leg==30.0,"Preset delegates selected part")
 panel._hit(true)
 expect(game.last_hit==["right_lower_leg",30.0,true],"Red hit delegates selected part")
 panel._remove()
 expect(not game.anatomy.present("right_lower_leg"),"Removal delegates selected part")
 panel._restore_selected()
 expect(game.anatomy.present("right_lower_leg") and game.anatomy.integrity.right_lower_leg==100.0,"Restore delegates selected part")
 panel._zero_health()
 expect(game.health==0.0,"HP0 delegates")
 var event:=InputEventKey.new()
 event.keycode=KEY_B;event.pressed=true
 panel._input(event)
 expect(game.body_lab_open,"B opens lab")
 event.keycode=KEY_ESCAPE
 panel._input(event)
 expect(not game.body_lab_open,"Escape closes lab")
 print("Anatomy panel UI: ","PASS" if failures==0 else "FAIL", " (two viewport layouts, ten states, delegated controls, B/ESC)")
 quit(0 if failures==0 else 1)

