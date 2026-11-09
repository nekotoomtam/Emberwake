extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func has_property(node: Object,key: String) -> bool:
 for entry in node.get_property_list():
  if entry.name==key:return true
 return false
func finish() -> void:
 if g!=null:g.audio.shutdown();g.free()
 print("HARBOR MARKED ROUTES v102 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 var probe=load("res://scripts/opening/harbor_dock_life.gd").new()
 check(has_property(probe,"marked_workers"),"marked red/orange routes have one explicit owner")
 probe.free()
 if not failures.is_empty():finish();return
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var life=g.world.dock_life
 check(life.marked_workers.size()==2,"exactly two first-terminal haulers")
 var red=life.marked_workers[0];var orange=life.marked_workers[1]
 check(red.profile.id=="PortWorker20" and orange.profile.id=="PortWorker30","the marked appearances are reused")
 check(life.source_boxes[0]==g.world.backdrop.district.marked_stocks.red and life.source_boxes[1]==g.world.backdrop.district.marked_stocks.orange,"pickup meshes are the real warehouse/pier stock")
 check(life.source_boxes[0].global_position.z< -34 and life.source_boxes[0].global_position.x< -23,"red source remains in the marked warehouse stack")
 check(life.source_boxes[1].global_position.x> -12 and life.source_boxes[1].global_position.z> -27,"orange source remains in the marked front-edge pier stack")
 for worker in life.marked_workers:
  check(worker.transfer_path[0].x< -27.3,"delivery actually enters the warehouse recess")
  check(worker.pickup_anchor.distance_to(worker.transfer_path[-1])<1.3,"pickup is within reach of its own box")
 var node_count: int=life.get_child_count();var separation:=INF;var bad_pickups:=0;var bad_drops:=0;var waits_without_progress:=0.0;var max_stall:=0.0
 var last_deliveries: Array=[0,0];var load_ids: Array=[red.native_load.get_instance_id(),orange.native_load.get_instance_id()]
 var pickup_positions: Array=[Vector3.INF,Vector3.INF]
 var wrong_stock:=false
 var was_carrying: Array=[false,false];var max_step:=0.0
 g.start_arrival();g.tick(8.0)
 for frame in ceili(900*Engine.physics_ticks_per_second):
  await physics_frame
  var active=life.marked_workers[life.active_index];var before: Vector3=active.position
  var before_positions: Array=[red.position,orange.position]
  g.world.tick(1.0/Engine.physics_ticks_per_second,g.camera)
  separation=minf(separation,red.position.distance_to(orange.position))
  if life.active_index==life.marked_workers.find(active) and active.state in ["outbound","returning"] and active.pause<=0 and active.position.distance_to(before)<.00001:
   waits_without_progress+=1.0/Engine.physics_ticks_per_second
  else:waits_without_progress=0
  max_stall=maxf(max_stall,waits_without_progress)
  for i in 2:
   var actor=life.marked_workers[i]
   max_step=maxf(max_step,actor.position.distance_to(before_positions[i]))
   if actor.state=="pickup" and actor.carrying and not was_carrying[i]:
    pickup_positions[i]=actor.position
    if actor.native_load.global_position.distance_to(actor.pickup_anchor)>.1:bad_pickups+=1
    wrong_stock=wrong_stock or life.source_boxes[i].visible
   was_carrying[i]=actor.carrying
   if actor.completed_deliveries>last_deliveries[i]:
    if actor.position.distance_to(actor.transfer_path[0])>.03 or actor.position.x>=-27.3:bad_drops+=1
    last_deliveries[i]=actor.completed_deliveries
  if red.completed_deliveries>=10 and orange.completed_deliveries>=10:break
 check(red.completed_deliveries>=10 and orange.completed_deliveries>=10,"both actual routes deliver ten times with the normal arrival enabled")
 check(separation>1.1,"two marked haulers never squeeze past or overlap")
 check(max_stall<.5,"no unexplained physical deadlock during a scheduled turn")
 check(max_step<.035,"movement contains no recovery teleports or collision bypass")
 check(bad_pickups==0 and not wrong_stock and pickup_positions.all(func(p):return p!=Vector3.INF),"both loads originate at the correct visible stock and acquisition")
 check(bad_drops==0,"all deliveries happen inside the one warehouse doorway")
 check(life.get_child_count()==node_count and [red.native_load.get_instance_id(),orange.native_load.get_instance_id()]==load_ids,"long loop retains its actors, props and load nodes")
 check(g.world.backdrop.district.delivery_piles.all(func(n):return n.position.z< -40),"legacy first-terminal random delivery piles are gone")
 # A real player-sized footprint must stop the active worker and releasing it
 # must resume the same route, without a teleport or disabled collisions.
 var actor=life.marked_workers[life.active_index]
 for frame in ceili(30*Engine.physics_ticks_per_second):
  if actor.state in ["outbound","returning"] and actor.position.distance_to(actor.transfer_path[actor.waypoint])>1:break
  await physics_frame;g.world.tick(1.0/Engine.physics_ticks_per_second,g.camera)
 var next: Vector3=actor.transfer_path[actor.waypoint]
 var blocker:=StaticBody3D.new();blocker.collision_layer=2
 var col:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.radius=.3;shape.height=1.4;col.shape=shape;col.position.y=.7;blocker.add_child(col)
 blocker.position=actor.position.move_toward(next,.7);g.world.add_child(blocker)
 var stopped:=false;var previous: Vector3=actor.position
 for frame in ceili(1.5*Engine.physics_ticks_per_second):
  await physics_frame;g.world.tick(1.0/Engine.physics_ticks_per_second,g.camera)
  stopped=stopped or (not actor.walking and actor.position.distance_to(blocker.position)<.8)
 check(stopped,"player-sized blocker is respected")
 blocker.free();var resume: Vector3=actor.position
 for frame in ceili(1.5*Engine.physics_ticks_per_second):await physics_frame;g.world.tick(1.0/Engine.physics_ticks_per_second,g.camera)
 check(actor.position.distance_to(resume)>.4,"worker resumes after the player clears its route")
 var ids: Array=[red.get_instance_id(),orange.get_instance_id()]
 var resets_ok:=true
 for reset in 3:
  g.return_title();g.start_arrival();g.tick(8)
  for frame in ceili(90*Engine.physics_ticks_per_second):
   await physics_frame;g.world.tick(1.0/Engine.physics_ticks_per_second,g.camera)
   if red.completed_deliveries>=1 and orange.completed_deliveries>=1:break
  resets_ok=resets_ok and red.completed_deliveries>=1 and orange.completed_deliveries>=1
 check(resets_ok and ids==[red.get_instance_id(),orange.get_instance_id()],"three menu/start resets keep the same people and both routes finish again")
 finish()
