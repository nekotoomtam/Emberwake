extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false);g.start_arrival();g.tick(8)
 for f in ceili(35*Engine.physics_ticks_per_second):
  await physics_frame;g.world.tick(1.0/Engine.physics_ticks_per_second,g.camera)
  if f%int(10*Engine.physics_ticks_per_second)==0:
   for a in g.world.dock_life.marked_workers:print("TRACE ",g.world.clock," ",a.name," ",a.position," ",a.state," wp",a.waypoint," enabled",a.enabled)
 var a=g.world.dock_life.marked_workers[g.world.dock_life.active_index]
 var next: Vector3=a.position.move_toward(a.transfer_path[a.waypoint],.01)
 var q:=PhysicsShapeQueryParameters3D.new();q.shape=a._route_shape;q.transform=a.human_blocker.global_transform*a._human_shape.transform;q.transform.origin+=next-a.position+Vector3.UP*.03;q.collision_mask=3;q.exclude=[a.human_blocker.get_rid()]
 for hit in g.world.get_world_3d().direct_space_state.intersect_shape(q):print("BLOCKER ",hit.collider.get_path())
 g.audio.shutdown();g.free();quit()
