extends SceneTree
const Art=preload("res://scripts/opening/harbor_human_art.gd")
var checks:=0
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func wood_pixels(texture: Texture2D) -> int:
 var im: Image=texture.get_image();var total:=0
 for y in range(20,26):
  for x in range(10,23):
   if im.get_pixel(x*4+1,y*4+1).to_html(false) in ["ad855f","75543e","d2ae7c"]:total+=1
 return total
func run():
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 for actor in g.world.dock_life.marked_workers:
  check(actor.native_load!=null and actor.profile.get("native_cargo",false),"marked worker has a native3D load owner")
  var meshes=actor.native_load.find_children("*","MeshInstance3D",true,false)
  check(not meshes.is_empty() and meshes.all(func(n):return n.get_active_material(0).shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED),"carried crate is genuine shaded/depth-tested native geometry")
  for facing in ["front","back","left","right"]:
   var native: Texture2D=Art.frame(actor.profile,facing,"carry_walk",0)
   var old: Dictionary=actor.profile.duplicate();old.native_cargo=false
   check(wood_pixels(native)==0 and wood_pixels(Art.frame(old,facing,"carry_walk",0))>0,"painted crate is absent while supporting hands remain: "+facing)
  check(actor.dropoff_anchor.x< -27.3 and absf(actor.dropoff_anchor.z+29)<.01,"crate delivery target is fixed inside the marked doorway")
 g.audio.shutdown();g.free()
 print("HARBOR PHYSICAL CARGO v102 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
