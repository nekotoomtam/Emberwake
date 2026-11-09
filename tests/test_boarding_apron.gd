extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var game=load("res://scenes/prologue.tscn").instantiate();root.add_child(game);game.set_process(false)
 var world=game.world
 check(world.get_tree().get_nodes_in_group("harbor_staff_barrier").is_empty(),"old fenced service yard no longer blocks the boarding apron")
 var old_props:=0
 for body in world.public_solids.blockers:
  if String(body.name).begins_with("Market") or String(body.name).begins_with("ServiceBarrel"):old_props+=1
 check(old_props==0,"removed stalls leave no canopy, planter, flag or service-barrel blockers")
 var orphaned:=0
 for actor in world.townspeople:
  if String(actor.profile.id) in ["bread_seller","fish_seller","pot_seller","yard_porter","market_porter","yard_ropehand","market_customer"]:orphaned+=1
 check(orphaned==0,"old market vendors and yard-only workers are removed with their workplace")
 var path:="res://scripts/opening/harbor_gangway.gd"
 check(ResourceLoader.exists(path),"arrival and departure can share one gangway design")
 if ResourceLoader.exists(path):
  var bridge=load(path)
  check(bridge.WIDTH==2.3,"shared bridge is the incoming vessel's 2.3m width")
  check((bridge.DEPARTURE_DECK-bridge.DEPARTURE_SHORE).is_equal_approx(bridge.ARRIVAL_DECK-bridge.ARRIVAL_SHORE),"both gangways have identical run, rise and width")
  check(world.get_node_or_null("BoardingGangwayFloor")!=null,"walking floor owns the revised gangway")
  check(world.get_tree().get_nodes_in_group("harbor_boarding_rail").size()==2,"both visible gangway edges have safety collision")
  check(bridge.ENTRY_LOCAL_X==0 and is_equal_approx(bridge.DEPARTURE_DECK.x-world.ship.position.x,0) and is_equal_approx(bridge.ARRIVAL_DECK.x-world.arrival.BERTH_POSITION.x,0),"both entrances are at the exact same local midship position")
  var first: Array=[];var second: Array=[]
  for mesh in world.ship.visual_root.find_children("*","MeshInstance3D",true,false):first.append(hash(mesh.mesh.get_faces()))
  for mesh in world.arrival.ship.visual_root.find_children("*","MeshInstance3D",true,false):second.append(hash(mesh.mesh.get_faces()))
  check(first==second and world.ship.geometry_count==world.arrival.ship.geometry_count,"actual arrival and departure ship model geometry is identical")
  var crates:=0
  for body in world.public_solids.deck_blockers:
   if String(body.name).begins_with("DepartureSupplyCrate"):crates+=1
  check(crates==0 and world.backdrop.district.ship_cargo.is_empty(),"deck crates and their colliders are removed")
 game.audio.shutdown();await create_timer(.25).timeout;game.free();await process_frame
 print("BOARDING APRON ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
