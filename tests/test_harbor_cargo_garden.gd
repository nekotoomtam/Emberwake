extends SceneTree
## v91 consumer evidence: native solids, live couriers and ordinary player paths.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func steer(target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func step() -> void:await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
func walk_to(target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("CARGO GARDEN WALK STOP ",g.walker.position," target ",target);return false
func route(points: Array) -> bool:
 for point in points:
  if not await walk_to(point):return false
 return true
func contact(target: Vector3,owner: Node,seconds: float=1.4) -> bool:
 var touched:=false
 for frame in ceili(seconds*Engine.physics_ticks_per_second):
  steer(target);await step()
  for index in g.walker.get_slide_collision_count():
   var hit: KinematicCollision3D=g.walker.get_slide_collision(index)
   for contact_index in hit.get_collision_count():
    var body: Object=hit.get_collider(contact_index);var normal: Vector3=hit.get_normal(contact_index)
    if body is Node and owner.is_ancestor_of(body) and Vector2(normal.x,normal.z).length()>.75:touched=true
 release_walk();return touched
func identities(people: Array) -> Dictionary:
 var result: Dictionary={}
 for person in people:result[str(person.profile.id)]=hash(person.profile)
 return result
func no_solids(at: Vector3) -> bool:
 var query:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.24;shape.height=1.34
 query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*.73);query.collision_mask=1
 return g.world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func finish() -> void:
 release_walk();g.audio.shutdown();g.free()
 print("HARBOR CARGO GARDEN ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var cargo=g.world.get("cargo_street");var garden=g.world.get("square_garden")
 check(cargo!=null and garden!=null,"actual prologue composes both requested scenery helpers")
 if cargo==null or garden==null:finish();return
 check(cargo.workers.size()==2 and garden.trees.size()==2 and garden.bed_bounds.size()==2,"delivery street and square contain the agreed two-worker/two-tree composition")
 check(g.world.townspeople.size()==8 and g.world.crew.size()==4 and g.world.pigeons.size()==6 and g.world.plaza.people.size()==8 and g.world.plaza.birds.size()==4,"new scenery retains all original town, deck and plaza population counts")
 check(garden.feeder in g.world.plaza.people and garden.feeding_pigeon in g.world.plaza.birds,"feeding scene reuses the actual existing visitor and bird")
 check(str(garden.feeder.profile.id)=="FountainVisitor" and garden.feeder.human_blocker!=null,"existing fountain identity and native human footprint remain")
 var original_town:=identities(g.world.townspeople);var original_crew:=identities(g.world.crew);var original_plaza:=identities(g.world.plaza.people)
 g.start_arrival();g.skip_arrival();g.tick(0);await step();await step()
 check(g.phase==&"play" and g.walker is CharacterBody3D,"ordinary intro skip releases the real protagonist")
 var corridor_clear:=true
 for x in [-57.5,-56.0,-54.5]:
  for z in [-17.0,-14.0,-11.0,-8.0,-5.0,-2.0,1.0,4.0]:corridor_clear=corridor_clear and no_solids(Vector3(x,.055,z))
 check(corridor_clear,"native player-sized samples leave a continuous centre/east delivery carriageway clear")
 check(await route([Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-49.7,.055,-3)]),"real protagonist reaches western tree through the original cafe exit")
 check(await contact(Vector3(-49.7,.055,-.4),garden),"western flowerbed/tree physically stops the actual player capsule")
 check(await route([Vector3(-49.7,.055,-3),Vector3(-47.6,.055,-3),Vector3(-47.6,.055,1.0),Vector3(-49.7,.055,1.0)]),"visible inward bypass around western bed stays walkable")
 check(await route([Vector3(-47.6,.055,1.0),Vector3(-47.6,.055,-3),Vector3(-26.3,.055,-3)]),"square centre remains connected between both new trees")
 check(await contact(Vector3(-26.3,.055,-.4),garden),"eastern flowerbed/tree physically stops the actual player capsule")
 check(await route([Vector3(-26.3,.055,-3),Vector3(-24.2,.055,-3),Vector3(-24.2,.055,1.0)]),"eastern bed leaves the fountain-to-painter bypass usable")
 check(await route([Vector3(-24.2,.055,-3),Vector3(-25,.055,-3),Vector3(-25,.055,-21.7)]),"original northern narrative approach stays connected")
 check(await route([Vector3(-25,.055,-3),Vector3(-52.3,.055,-3)]),"new props preserve the original west pavement route")
 for frame in ceili(1.2*Engine.physics_ticks_per_second):steer(Vector3(-60,.055,-3));await step()
 release_walk()
 check(g.walker.position.x>=-53.201 and g.walker.wrong_way_latched,"decorated western street retains the original marked player limit")
 check(await route([Vector3(-52.3,.055,-3),Vector3(-43,.055,-3)]),"western boundary still permits immediate return toward cafe")
 var positions: Array=[{},{}];var carrying: Array=[{},{}];var frames: Array=[{},{}];var grain_poses: Dictionary={}
 var worker_bodies:=true
 for worker in cargo.workers:worker_bodies=worker_bodies and worker.human_blocker!=null and worker.human_blocker.collision_layer==1
 check(worker_bodies,"both added workers use native blocking people bodies")
 for sample in 1200:
  await physics_frame;g.tick(1.0/60)
  for index in cargo.workers.size():
   var worker=cargo.workers[index]
   positions[index][str(worker.position.snapped(Vector3(.05,.05,.05)))]=true
   carrying[index][str(worker.carrying)]=true
   if worker.sprite.texture!=null:frames[index][hash(worker.sprite.texture.get_image().get_data())]=true
  for grain in garden.grains:grain_poses[str(grain.transform)+str(grain.visible)]=true
 for index in cargo.workers.size():
  check(positions[index].size()>12 and frames[index].size()>2,"courier "+str(index+1)+" visibly moves and animates over small world steps")
  check(carrying[index].size()==2,"courier "+str(index+1)+" changes between loaded and empty return states")
 check(grain_poses.size()>4,"reused fountain resident has time-varying physical grain feedback")
 check(identities(g.world.townspeople)==original_town and identities(g.world.crew)==original_crew and identities(g.world.plaza.people)==original_plaza,"delivery and feeding leave original appearance identities unchanged")
 check(garden.feeder in g.world.plaza.people and garden.feeding_pigeon in g.world.plaza.birds and g.world.plaza.people.size()==8 and g.world.plaza.birds.size()==4,"temporal activity does not duplicate the original fountain person or pigeon")
 check(g.walker.position.y>-.05,"all inspected public paths retain real supporting ground")
 finish()
