extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false);g.start_wreck_shore();await physics_frame;await physics_frame
 var ship=g.arena.ship
 var bow: Vector3=ship.to_global(Vector3(14.2,0,0));var stern: Vector3=ship.to_global(Vector3(-14.2,0,0))
 var profile=load("res://scripts/wreck_shore_profile.gd")
 check(bow.z<profile.sea_z(bow.x)-1,"hull bow driven onto beach")
 check(stern.z>profile.sea_z(stern.x)+2,"stern remains in sea")
 check((bow-stern).normalized().dot(Vector3.FORWARD)>.7,"axis heads inland, not parallel shore")
 check(bow.y>stern.y,"bow rides above submerged stern")
 check(g.arena.get("west_rocks")!=null,"authored irregular west cluster")
 if g.arena.get("west_rocks")!=null:
  var rocks: Array=g.arena.west_rocks;var xs: Array=[];var sizes: Array=[]
  for rock in rocks:xs.append(rock[0].x);sizes.append(rock[1])
  check(xs.max()-xs.min()>3,"west outline not a straight x row")
  check(sizes[0]!=sizes[1] and rocks.size()>=7,"overlapping mixed rock masses")
  check(g.arena.west_growth>=6,"dense west growth supports blockade")
 check(g.arena.get("impact_rocks")!=null,"physical rocks at bow contact")
 check(g.arena.get("west_backdrop_count")!=null,"upper-left background authored")
 check(ship.get("crushed_planks")!=null and ship.get("crushed_deck_tiles")!=null,"heavy right bow damage represented")
 check(ship.get("fallen_mast_tips")!=null,"broken mast segments fall left")
 check(g.arena.impact_rocks.size()==3,"linked impact outcrop has physical masses")
 var contact: Vector3=g.arena.impact_rocks[0];var torn_bow: Vector3=ship.to_global(Vector3(12.8,0,2.1));torn_bow.y=0
 check(contact.distance_to(torn_bow)<.01,"contact outcrop aligned with crushed right bow")
 check(ship.crushed_planks>=40 and ship.crushed_deck_tiles>=20,"large asymmetric hull and deck loss")
 check(g.arena.west_backdrop_count>=20,"forest continues past upper left")
 check(ship.fallen_mast_tips.size()==2,"both mast tops are broken")
 for i in ship.fallen_mast_tips.size():
  check(ship.fallen_mast_tips[i].x<ship.fallen_mast_starts[i].x-6 and ship.fallen_mast_tips[i].y<1,"mast falls left and down")
 var tip: Vector3=ship.fallen_mast_tips[1]
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(tip.x,.5,tip.z-1),Vector3(tip.x,.5,tip.z+1),1)
 var hit: Dictionary=g.player.get_world_3d().direct_space_state.intersect_ray(ray)
 check(not hit.is_empty() and hit.collider.get_parent()==ship and hit.collider.get_child(0).shape is CapsuleShape3D,"grounded mast has matching physical obstruction")
 g.arena.skip_intro();g.player.position=g.arena.landing_point;g.move_input=Vector2.LEFT
 for i in 200:g.tick(1.0/120)
 g.move_input=Vector2.ZERO;check(g.player.position.x>1.0,"real movement blocked at natural bank")
 g.free();await process_frame;print("GROUNDED WRECK ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
