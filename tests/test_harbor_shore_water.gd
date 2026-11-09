extends SceneTree
## Headless consumer contracts only. Visible motion requires the native fixture.
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func finish(g) -> void:
 g.audio.shutdown();g.free()
 print("HARBOR SHORE WATER ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func assigned_material(mesh: MeshInstance3D) -> Material:
 return mesh.get_active_material(0) if mesh!=null and mesh.mesh!=null and mesh.mesh.get_surface_count()>0 else null
func resource_state(sea) -> Array:
 var state: Array=[]
 for node in [sea.near_mesh,sea.far_mesh,sea.shore_mesh]:
  state.append(node.get_instance_id());state.append(node.mesh.get_instance_id())
  state.append(assigned_material(node).get_instance_id())
  for surface in node.mesh.get_surface_count():
   var arrays: Array=node.mesh.surface_get_arrays(surface)
   state.append(hash(arrays[Mesh.ARRAY_VERTEX]));state.append(hash(arrays[Mesh.ARRAY_INDEX]))
 return state
func native_shores(g) -> Array:
 # Endpoints come from the actual QuayEdge body extents. The short northeast
 # coping has no safety-rail body, so its authored visible interval is appended.
 var outward_by_name: Dictionary={"PlazaSeaRail":Vector2.RIGHT,"QuayWestRail":Vector2.UP,"QuayEastRail":Vector2.UP,"QuayEndRail":Vector2.RIGHT,"TownSeafrontRail":Vector2.DOWN,"TownShoreStep":Vector2.RIGHT,"PlazaSouthRail":Vector2.DOWN,"QuaySouthRail":Vector2.DOWN}
 var result: Array=[]
 for body in g.world.quay_edge.find_children("*","StaticBody3D",true,false):
  if not outward_by_name.has(String(body.name)):continue
  for child in body.get_children():
   if not child is CollisionShape3D or not child.shape is BoxShape3D:continue
   var size: Vector3=child.shape.size;var at: Vector3=child.global_position
   var a: Vector2;var b: Vector2
   if size.x>size.z:a=Vector2(at.x-size.x*.5,at.z);b=Vector2(at.x+size.x*.5,at.z)
   else:a=Vector2(at.x,at.z-size.z*.5);b=Vector2(at.x,at.z+size.z*.5)
   result.append({"a":a,"b":b,"outward":outward_by_name[String(body.name)]})
 result.append({"a":Vector2(-19.55,-20),"b":Vector2(-19.55,-17.4),"outward":Vector2.RIGHT})
 return result
func covered(segment: Dictionary,available: Array) -> bool:
 var a: Vector2=segment.a;var b: Vector2=segment.b;var length:=a.distance_to(b)
 if length<.01:return false
 var along: Vector2=(b-a)/length;var outward: Vector2=segment.outward
 var intervals: Array=[]
 for candidate in available:
  var ca: Vector2=candidate.a;var cb: Vector2=candidate.b;var normal: Vector2=candidate.outward
  if normal.dot(outward)<.999:continue
  if absf((ca-a).cross(along))>.005 or absf((cb-a).cross(along))>.005:continue
  var low:=maxf(0,minf((ca-a).dot(along),(cb-a).dot(along)))
  var high:=minf(length,maxf((ca-a).dot(along),(cb-a).dot(along)))
  if high>=low:intervals.append(Vector2(low,high))
 intervals.sort_custom(func(x,y):return x.x<y.x)
 var end:=0.0
 for interval in intervals:
  if interval.x>end+.005:return false
  end=maxf(end,interval.y)
 return end>=length-.005
func floor_ray(g,point: Vector2) -> bool:
 var at:=Vector3(point.x,0,point.y)
 return not g.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.5,at-Vector3.UP*.6,1)).is_empty()
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var sea=g.world.get("sea_surface")
 check(sea!=null and g.world.get_node_or_null("OpenSea")==sea,"actual opening composes the sea helper at its retained OpenSea node")
 if sea==null:finish(g);return
 check(g.world.water_material==sea.water_material,"world retains its public water-material alias")
 var meshes_ready: bool=sea.near_mesh is MeshInstance3D and sea.far_mesh is MeshInstance3D and sea.shore_mesh is MeshInstance3D
 check(meshes_ready,"near sea, distant ocean and shore wash use native mesh instances")
 if not meshes_ready:finish(g);return
 var materials_ready: bool=sea.water_material!=null and sea.shore_material!=null and assigned_material(sea.near_mesh)==sea.water_material and assigned_material(sea.far_mesh)==sea.water_material and assigned_material(sea.shore_mesh)==sea.shore_material
 check(materials_ready,"actual composed meshes use the exposed clock-driven sea/shore materials")
 if not materials_ready:finish(g);return
 var near_arrays: Array=sea.near_mesh.mesh.surface_get_arrays(0)
 check(near_arrays[Mesh.ARRAY_VERTEX].size()>16000,"near-harbor surface has local native vertices rather than the old sparse huge plane")
 check(sea.find_children("*","CollisionObject3D",true,false).is_empty(),"new surface and wash are visual-only with no physics bodies or areas")
 var original_state:=resource_state(sea)
 var before: float=g.world.clock
 g.world.tick(1.25,g.camera)
 check(is_equal_approx(g.world.clock,before+1.25) and is_equal_approx(sea.clock,g.world.clock),"existing world clock advances the composed sea without a second timer")
 check(is_equal_approx(float(sea.water_material.get_shader_parameter("clock")),g.world.clock) and is_equal_approx(float(sea.shore_material.get_shader_parameter("clock")),g.world.clock),"the same absolute world time reaches both rendered shader materials")
 var paused: float=g.world.clock;g.world.tick(0,g.camera)
 check(is_equal_approx(sea.clock,paused) and is_equal_approx(float(sea.shore_material.get_shader_parameter("clock")),paused),"zero-delta world ticks hold water and shore time")
 var low:=INF;var high:=-INF;var total:=0.0;var count:=0;var moving_points:=0
 for point in [Vector2(4,18),Vector2(-50,18),Vector2(23,8),Vector2(-19,-9),Vector2(80,-38)]:
  var point_low:=INF;var point_high:=-INF
  for time in [0.0,1.3,2.7,4.4,7.1,10.2]:
   var height: float=sea.surface_height(point,time)
   point_low=minf(point_low,height);point_high=maxf(point_high,height)
   low=minf(low,height);high=maxf(high,height);total+=height;count+=1
  if point_high-point_low>.025:moving_points+=1
 check(low>=sea.MEAN_LEVEL-.081 and high<=sea.MEAN_LEVEL+.081 and absf(total/count-sea.MEAN_LEVEL)<.035,"sampled surface stays in the modest sea-height envelope below dry paving")
 check(moving_points>=4 and high-low>.055,"independent water locations rise and fall across time rather than remaining a flat translated clock")
 var held_world_clock: float=g.world.clock;var held_ship: Transform3D=g.world.ship.visual_root.transform
 for time in [3.75,0.0,9.2,1.1,5.5]:sea.set_clock(time)
 check(is_equal_approx(sea.clock,5.5) and is_equal_approx(float(sea.water_material.get_shader_parameter("clock")),5.5) and is_equal_approx(float(sea.shore_material.get_shader_parameter("clock")),5.5),"absolute effect-time selection updates both materials coherently")
 check(is_equal_approx(g.world.clock,held_world_clock) and g.world.ship.visual_root.transform==held_ship,"effect-only sampling cannot advance the world or existing ship heave")
 check(resource_state(sea)==original_state,"clock changes reuse the exact native meshes, vertex/index data and material instances")
 g.world.tick(0,g.camera)
 check(is_equal_approx(sea.clock,g.world.clock),"normal world tick restores its one-clock authority after isolated effect inspection")
 await physics_frame;await physics_frame
 var actual: Array=native_shores(g);var complete:=true;var no_extra:=true;var directions:=true
 for segment in actual:
  complete=complete and covered(segment,sea.shore_segments)
  var midpoint: Vector2=(Vector2(segment.a)+Vector2(segment.b))*.5;var outward: Vector2=segment.outward
  directions=directions and not floor_ray(g,midpoint+outward*1.1) and floor_ray(g,midpoint-outward*1.1)
 for segment in sea.shore_segments:no_extra=no_extra and covered(segment,actual)
 check(complete,"shore intervals cover every actual capped sea-facing rail/coping edge and corner")
 check(no_extra,"shore intervals add no land-side or boarding-opening segment")
 check(directions,"shore normals point from actual dry supported land toward real open water")
 var boarding_open:=true
 for segment in sea.shore_segments:
  var a: Vector2=segment.a;var b: Vector2=segment.b
  if absf(a.y-2.1)<.005 and absf(b.y-2.1)<.005:
   if maxf(minf(a.x,b.x),10.81)<minf(maxf(a.x,b.x),15.19):boarding_open=false
 check(boarding_open,"the original complete 10.8-to-15.2m boarding mouth has no authored shore-wave interval")
 g.start_arrival();g.skip_arrival();g.tick(0)
 g.ui.open_settings();g.tick(0);paused=g.world.clock;g.tick(.75)
 check(is_equal_approx(g.world.clock,paused) and is_equal_approx(sea.clock,paused),"play settings pause the existing world and both water effects")
 g.ui.close_settings();g.tick(.125)
 check(is_equal_approx(g.world.clock,paused+.125) and is_equal_approx(sea.clock,g.world.clock),"closing settings resumes the same world-owned water clock")
 finish(g)
