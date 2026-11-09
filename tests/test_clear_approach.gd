extends SceneTree
const PlazaProfile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures.append(label);printerr("FAIL: ",label)
func in_view(camera: Camera3D,at: Vector3) -> bool:
 if camera.is_position_behind(at):return false
 var p: Vector2=camera.unproject_position(at)
 return Rect2(Vector2.ZERO,root.size).has_point(p)
func run() -> void:
 root.size=Vector2i(1280,800)
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var env: Environment
 for node in g.world.get_children():
  if node is WorldEnvironment:env=node.environment
 check(env!=null and not env.fog_enabled,"clear harbor has no atmospheric fog")
 check(env.sky.sky_material is ShaderMaterial,"original cloud sky renderer")
 check(not in_view(g.camera,g.world.lighthouse.position+Vector3.UP*20),"title has no visible lighthouse yet")
 var visible_city:=0
 for building in g.world.backdrop.buildings:
  if in_view(g.camera,building.at+Vector3.UP*building.height):visible_city+=1
 check(visible_city==0,"title sees open water rather than city skyline")
 check(g.world.backdrop.district.berths[0].get("surface","")=="masonry","large cargo terminal is masonry")
 for i in range(1,5):check(g.world.backdrop.district.berths[i].get("surface","")=="timber","small berth retains timber "+str(i))
 g.start_arrival()
 for i in 540:g.tick(1.0/60)
 check(in_view(g.camera,g.world.lighthouse.position+Vector3.UP*20),"first reveal shows distant lighthouse")
 for i in 300:g.tick(1.0/60)
 visible_city=0
 for building in g.world.backdrop.buildings:
  if in_view(g.camera,building.at+Vector3.UP*building.height):visible_city+=1
 check(visible_city>0,"later orbit reveals coastline without fog trick")
 for i in roundi((g.camera.intro_duration-14.0+1.1)*60.0):g.tick(1.0/60)
 check(g.phase==&"line" and g.camera.position.distance_to(PlazaProfile.CAFE_CAMERA)<.01,"continuous approach finishes at coffee framing")
 check(g.world.arrival.docked and g.world.sip_lift>.9,"the vessel docks and the player lifts the cup as the camera settles")
 g.return_title()
 check(not in_view(g.camera,g.world.lighthouse.position+Vector3.UP*20),"replay restores sea-only composition")
 g.free();await process_frame
 print("CLEAR APPROACH ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
