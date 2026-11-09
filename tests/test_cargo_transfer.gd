extends SceneTree
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var backdrop=load("res://scripts/opening/harbor_backdrop.gd").new();root.add_child(backdrop)
 var port=backdrop.district
 check(port.has_method("set_arrival_ready"),"arrival readiness API exists")
 check(port.has_method("reset_activity"),"activity resets")
 check(absf(port.berths[4].start.z-port.berths[3].start.z)>=30,"berths have navigable spacing")
 check(port.berths[0].end.x>=22.9 and port.berths[0].width>=6,"large cargo terminal reaches arriving ship")
 check(backdrop.coastline_depth>=220,"city coastline has depth")
 check(backdrop.markets.size()>=20 and backdrop.buildings.size()>=100,"city mixes stalls and a deeper roofscape")
 check(port.couriers.size()>=2,"at least two couriers")
 var camera:=Camera3D.new();root.add_child(camera)
 var initial: Array=[]
 for courier in port.couriers:initial.append(courier.position)
 for i in 180:port.tick(1.0/60,camera,i/60.0)
 check(port.deliveries==0,"no unloaded cargo before vessel arrival")
 check(not port.transfer_bridge.visible,"bridge waits for arriving vessel")
 for i in port.couriers.size():check(port.couriers[i].position==initial[i],"courier waits before ship arrives "+str(i))
 port.set_arrival_ready(true)
 var saw_loaded:=false
 for i in 18000:
  port.set_arrival_ready(true)
  port.tick(1.0/60,camera,i/60.0)
  for courier in port.couriers:
   if courier.carrying:saw_loaded=true
 check(saw_loaded,"couriers pick up and carry a visible load")
 check(port.deliveries>=2,"workers complete physical ship-to-shore delivery cycles")
 check(port.delivery_piles.size()>=2,"delivered cargo changes shore pile")
 var hidden:=0
 for crate in port.ship_cargo:
  if not crate.visible:hidden+=1
 check(hidden>=2,"repeated readiness updates preserve consumed ship cargo")
 for berth in port.berths:
  check(berth.path_clearance>=3.8,"wide usable center lane "+berth.kind)
  if berth.kind!="cargo":check(berth.end.x<=12,"noncargo ports preserve sea channel")
 for courier in port.couriers:
  var clear:=true
  for i in range(1,courier.transfer_path.size()):
   var a: Vector3=courier.transfer_path[i-1];var c: Vector3=courier.transfer_path[i]
   for j in 21:
    var p: Vector3=a.lerp(c,j/20.0)
    for obstacle in port.obstacles:
     if obstacle.grow(.20).has_point(Vector2(p.x,p.z)):clear=false
  check(clear,"courier route avoids carts and staged cargo "+courier.name)
 port.reset_activity()
 check(port.deliveries==0 and port.delivery_piles.is_empty(),"reset clears completed transfers")
 for i in port.couriers.size():check(port.couriers[i].position==initial[i] and not port.couriers[i].enabled,"reset returns waiting courier "+str(i))
 print("CITY METADATA ",backdrop.buildings.size()," buildings; ",backdrop.markets.size()," stalls; ",port.workers.size()," workers; ",port.couriers.size()," couriers")
 camera.free();backdrop.free();await process_frame
 print("GRAND CITY FOCUSED ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
