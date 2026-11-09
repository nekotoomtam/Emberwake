extends SceneTree
## Real art, ground, controller input and narrative gates. No persistence access.
## Original three-check RED evidence remains unchanged in work/citylife87-red.log.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const Coffee=preload("res://scripts/opening/harbor_coffee_art.gd")
var checks:=0
var failures: Array=[]
var events:=0
var lowest_y:=INF
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func has_property(object: Object,key: String) -> bool:
 for entry in object.get_property_list():
  if entry.name==key:return true
 return false
func finish(g) -> void:
 release_walk();g.free()
 print("HARBOR CITY LIFE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func steer(g,target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk()
 Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x))
 Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func physical_frame(g) -> void:
 await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
 lowest_y=minf(lowest_y,g.walker.position.y)
func walk_to(g,target: Vector3) -> bool:
 for frame in Engine.physics_ticks_per_second*12:
  var delta: Vector3=target-g.walker.position;delta.y=0
  if delta.length()<.16:release_walk();return true
  steer(g,target);await physical_frame(g)
 release_walk();printerr("CITY WALK STOP ",g.walker.position," target ",target);return false
func route(g,points: Array,label: String) -> bool:
 for point in points:
  var reached: bool=await walk_to(g,point)
  check(reached,label+" "+str(point))
  if not reached:return false
 return true
func attempt(g,target: Vector3,seconds: float) -> void:
 for frame in ceili(Engine.physics_ticks_per_second*seconds):
  steer(g,target);await physical_frame(g)
 release_walk()
func contact(g,target: Vector3,seconds: float,group: String) -> bool:
 var touched:=false
 for frame in ceili(Engine.physics_ticks_per_second*seconds):
  steer(g,target);await physical_frame(g)
  for index in g.walker.get_slide_collision_count():
   var hit: KinematicCollision3D=g.walker.get_slide_collision(index)
   for contact_index in hit.get_collision_count():
    var body: Object=hit.get_collider(contact_index);var normal: Vector3=hit.get_normal(contact_index)
    if body is Node and body.is_in_group(group) and Vector2(normal.x,normal.z).length()>.8:touched=true
 release_walk();return touched
func mesh_vertices(node: Node) -> Array[Vector3]:
 var vertices: Array[Vector3]=[]
 if node is MeshInstance3D and node.mesh!=null:
  for surface in node.mesh.get_surface_count():
   var arrays: Array=node.mesh.surface_get_arrays(surface)
   for vertex in arrays[Mesh.ARRAY_VERTEX]:vertices.append(node.global_transform*vertex)
 for child in node.get_children():vertices.append_array(mesh_vertices(child))
 return vertices
func has_vertex(vertices: Array[Vector3],box: AABB) -> bool:
 for vertex in vertices:
  if box.has_point(vertex):return true
 return false
func mesh_intersects_rect(vertices: Array[Vector3],rect: Rect2,min_y: float) -> bool:
 # Actual triangles catch broad roofs spanning the road even when no vertex
 # lies inside it. A registry or metadata-only removal cannot satisfy this.
 var corners:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
 for index in range(0,vertices.size()-2,3):
  var a: Vector3=vertices[index];var b: Vector3=vertices[index+1];var c: Vector3=vertices[index+2]
  if minf(a.y,minf(b.y,c.y))<=min_y:continue
  var projected:=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
  var bound:=Rect2(projected[0],Vector2.ZERO).expand(projected[1]).expand(projected[2])
  if rect.intersects(bound,true) and not Geometry2D.intersect_polygons(projected,corners).is_empty():return true
 return false
func support_at(g,at: Vector3) -> bool:
 var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.5,at-Vector3.UP*.5,1)
 var hit: Dictionary=g.world.get_world_3d().direct_space_state.intersect_ray(ray)
 return not hit.is_empty() and Vector3(hit.normal).y>.99 and absf(Vector3(hit.position).y-.055)<.025
func identity_count(node: Node,id: String) -> int:
 var count:=0
 if has_property(node,"profile") and node.profile is Dictionary and str(node.profile.get("id",""))==id:count+=1
 for child in node.get_children():count+=identity_count(child,id)
 return count
func image_key(texture: Texture2D) -> int:return hash(texture.get_image().get_data())
func alpha_width(image: Image,row: int) -> int:
 var left:=32;var right:=-1
 for x in 32:
  if image.get_pixel(x*4+2,row*4+2).a>.5:left=mini(left,x);right=maxi(right,x)
 return maxi(0,right-left+1)
func social_checks(g,life) -> void:
 check(life.actors.size()==4 and life.portrait_pair.size()==2 and life.coffee_pair.size()==2,"one artist/model scene and one seated coffee pair are composed")
 if life.actors.size()!=4 or life.portrait_pair.size()!=2 or life.coffee_pair.size()!=2:return
 check(g.world.get("life")==life,"world and plaza share the same social scene")
 check(g.world.townspeople.size()==8 and g.world.crew.size()==4,"existing eight town and four deck identities are retained")
 check(life.coffee_pair[1] in g.world.townspeople and life.coffee_pair[1].profile.id=="cafe_patron","decorated world cafe patron is the actual second seated actor")
 check(life.coffee_pair[0].profile.id=="CafeReader" and identity_count(g.world,"CafeReader")==1 and identity_count(g.world,"cafe_patron")==1,"reader and world patron each have one actual body")
 var standing_reader:=false
 for person in g.world.plaza.people:
  if person.profile.id=="CafeReader":standing_reader=true
 check(not standing_reader,"former standing reader is absent from the walking population")
 var actor=life.coffee_pair[1];var ticks_before: int=actor.tick_count
 g.world.tick(.125,g.camera)
 check(actor.tick_count==ticks_before+1,"adopted patron receives exactly one animation tick per world tick")
 var props: Array[Vector3]=mesh_vertices(life.main)
 var hero_pixels:=image_key(Coffee.sipping(0));var social_art=load("res://scripts/opening/harbor_social_art.gd")
 for index in 2:
  var person=life.coffee_pair[index]
  var rest: Texture2D=social_art.frame(person.profile,"coffee",person.facing_side,0)
  var im:=rest.get_image()
  check(rest.get_width()==128 and rest.get_height()==128 and alpha_width(im,24)>=8 and alpha_width(im,27)<=4 and alpha_width(im,30)>=5,"coffee person "+str(index+1)+" has horizontal thigh, bent shin and grounded boot pixels")
  check(has_vertex(props,AABB(person.position+Vector3(-.30,.35,-.30),Vector3(.60,.12,.60))),"coffee person "+str(index+1)+" sits over an actual native chair seat")
  var changed: Dictionary=person.profile.duplicate(true);changed.coat="e1364c"
  check(image_key(rest)!=image_key(social_art.frame(changed,"coffee",person.facing_side,0)) and image_key(rest)==image_key(social_art.frame(person.profile,"coffee",person.facing_side,0)),"coffee person "+str(index+1)+" has an appearance-sensitive private sprite cache")
 check(image_key(life.coffee_pair[0].sprite.texture)!=image_key(life.coffee_pair[1].sprite.texture),"seated people retain distinct personal appearances")
 check(image_key(Coffee.sipping(0))==hero_pixels,"social recoloring leaves protagonist coffee bitmap unchanged")
 var painter=life.portrait_pair[0];var model=life.portrait_pair[1]
 check(painter.role=="painter" and model.role=="model" and painter.position.distance_to(Vector3(-22.8,.055,.8))<.01 and model.position.distance_to(Vector3(-20.8,.055,-2))<.01,"artist and subject occupy the authored waterfront scene")
 check(painter.brush!=null and mesh_vertices(painter.brush).size()>20 and painter.palette_prop!=null and mesh_vertices(painter.palette_prop).size()>100,"artist holds rendered brush and colored native palette")
 var painting=life.get_node_or_null("OriginalPaintedPortrait")
 check(painting is Sprite3D and painting.texture.get_width()==40 and painting.texture.get_height()==48,"easel carries original unfinished portrait artwork")
 var painter_frames: Dictionary={};var model_frames: Dictionary={};var brush_positions: Dictionary={}
 var coffee_frames: Array=[{},{}];var coffee_low: Array=[INF,INF];var coffee_high: Array=[-INF,-INF]
 var saw_rest: Array=[false,false];var saw_mouth: Array=[false,false];var staggered:=false
 for sample in 97:
  g.world.tick(.125,g.camera)
  painter_frames[image_key(painter.sprite.texture)]=true;model_frames[image_key(model.sprite.texture)]=true;brush_positions[str(painter.brush.transform)]=true
  staggered=staggered or absf(life.coffee_pair[0].sip_lift-life.coffee_pair[1].sip_lift)>.8
  for index in 2:
   var person=life.coffee_pair[index];var mug: Node3D=person.cup
   coffee_frames[index][image_key(person.sprite.texture)]=true
   coffee_low[index]=minf(coffee_low[index],mug.position.y);coffee_high[index]=maxf(coffee_high[index],mug.position.y)
   var rest_at:=Vector3(-47.71 if index==0 else -46.89,.645,-8.16)
   var mouth_at:=Vector3(-48.01 if index==0 else -46.59,.855,-8.165)
   if person.sip_lift<.001:saw_rest[index]=saw_rest[index] or mug.position.distance_to(rest_at)<.003
   if person.sip_lift>.999:saw_mouth[index]=saw_mouth[index] or mug.position.distance_to(mouth_at)<.003
 for index in 2:
  check(saw_rest[index] and saw_mouth[index] and coffee_high[index]-coffee_low[index]>.20 and coffee_frames[index].size()>=4,"coffee person "+str(index+1)+" moves hand art and real cup between saucer and mouth")
 check(staggered,"coffee people sip at different times")
 check(painter_frames.size()>=3 and brush_positions.size()>6,"artist visibly changes brush pose while painting")
 check(model_frames.size()>=2,"portrait subject visibly changes pose over world time")
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 await physics_frame;await physics_frame
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(-25,.75,-15),Vector3(-25,.75,-21.5),1)
 check(g.world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"pottery facade and counter replaced by a usable walkway")
 var life=g.world.plaza.get("life");check(life!=null,"painter/model and seated coffee pair are composed")
 var town_routes=g.world.get("town_routes");check(town_routes!=null,"wide western street and north approach have authored ground")
 if life==null or town_routes==null:finish(g);return
 check(not mesh_intersects_rect(mesh_vertices(g.world.plaza.main),Rect2(-27,-21.3,4.1,4.7),.30),"actual pottery canopy, facade and counter meshes are cleared from new passage")
 check(identity_count(g.world,"PlazaPotter")==0,"removed pottery frontage has no orphan standing vendor")
 check(identity_count(g.world,"PlazaBaker")==1 and identity_count(g.world,"PlazaFlorist")==1,"baker and florist remain beside new opening")
 for z in [-15.0,-16.5,-18.0,-19.6,-20.7,-21.7,-22.35]:check(support_at(g,Vector3(-25,.055,z)),"former pottery plot has actual ground at "+str(Vector3(-25,.055,z)))
 check(Profile.WEST_STREET_RECT.size.x>=10 and town_routes.geometry_count>0 and mesh_vertices(town_routes).size()>500,"wide western street emits real native geometry at requested scale")
 check(not mesh_intersects_rect(mesh_vertices(g.world.backdrop.b),Rect2(-63.9,-24.9,12.8,42.3),1.2),"actual old residential walls and roofs are cleared across western street")
 for at in [Vector3(-63,.055,-16),Vector3(-57.5,.055,-16),Vector3(-52.3,.055,-16),Vector3(-63,.055,0),Vector3(-57.5,.055,0),Vector3(-52.3,.055,0),Vector3(-63,.055,16.5),Vector3(-57.5,.055,16.5),Vector3(-52.3,.055,16.5)]:check(support_at(g,at),"broad western road has physical ground at "+str(at))
 social_checks(g,life)
 g.start_arrival();g.skip_arrival();g.tick(0)
 check(g.phase==&"play" and g.walker is CharacterBody3D,"new routes use real playable protagonist")
 if g.walker==null:finish(g);return
 g.walker.wrong_way_attempted.connect(func():events+=1)
 await physics_frame;await physics_frame
 if not await route(g,[Vector3(-41,.055,-5.5),Vector3(-36,.055,-3),Vector3(-25,.055,-3),Vector3(-25,.055,-15),Vector3(-25,.055,-21.7)],"actual north walk through former pottery store"):finish(g);return
 check(events==0,"new north passage is usable before its narrative gate")
 await attempt(g,Vector3(-25,.055,-27),1.3)
 check(events==1 and g.walker.position.z>=-22.501 and g.walker.position.z<-22.35,"north outward input warns at new -22.5m gate "+str(g.walker.position))
 check(g.ui.bark_panel.visible and g.ui.bark_text.text=="นั่นไม่ใช่ทางไปที่เรือนะ","original Thai wrong-way line appears at new gate")
 await attempt(g,Vector3(-25,.055,-27),3.2)
 check(events==1 and g.walker.wrong_way_latched,"held north input stays silent after speech times out")
 # The retained rear cafe terrace occupies z=-13. Use its public front walk.
 if not await route(g,[Vector3(-25,.055,-17.3),Vector3(-25,.055,-3),Vector3(-39,.055,-3),Vector3(-49,.055,-3),Vector3(-52.2,.055,-3),Vector3(-52.2,.055,-18),Vector3(-51.65,.055,-18)],"actual north-to-west public pavement route"):finish(g);return
 check(events==1,"open western public band has no premature warning")
 var facade_contact: bool=await contact(g,Vector3(-51.65,.055,-24),1.8,"harbor_town_end_building")
 check(facade_contact and g.walker.position.z> -20.85 and events==1,"actual terminal building closes north street with side contact rather than a narrative gate")
 if not await route(g,[Vector3(-51.65,.055,-17),Vector3(-52.2,.055,-17),Vector3(-52.2,.055,-3),Vector3(-52.2,.055,11)],"north stores to the seaside public band"):finish(g);return
 await attempt(g,Vector3(-60,.055,11),1.4)
 check(events==2 and g.walker.position.x>=Profile.WEST_GATE_X-.001 and g.walker.position.x<Profile.WEST_GATE_X+.2 and g.walker.position.x-.24>=Profile.WEST_LINE_X-.001 and g.walker.position.y>.02,"west outward input stops the full capsule at the adjacent pavement seam "+str(g.walker.position))
 await attempt(g,Vector3(-60,.055,11),3.2)
 check(events==2 and g.walker.wrong_way_latched,"held western input cannot repeatedly speak after timeout")
 if not await route(g,[Vector3(-52.9,.055,11)],"movement just inside the western seam"):finish(g);return
 var coast_contact: bool=await contact(g,Vector3(-52.9,.055,19),2.5,"harbor_quay_edge")
 check(coast_contact and events==2 and g.walker.wrong_way_latched,"public band's south coast is a real rail and does not invent another narrative exit")
 if not await route(g,[Vector3(-52.9,.055,11),Vector3(-52.2,.055,11)],"actual inward return along public pavement"):finish(g);return
 check(not g.walker.wrong_way_latched,"returning inward along supported pavement rearms next wrong turn")
 if not await route(g,[Vector3(-52.9,.055,11)],"new deliberate adjacent-seam approach"):finish(g);return
 await attempt(g,Vector3(-60,.055,11),1.0)
 check(events==3 and g.walker.position.x>=Profile.WEST_GATE_X-.001 and g.ui.bark_panel.visible,"new deliberate seam exit speaks again at its real limit "+str(g.walker.position))
 check(lowest_y>-.025,"new routes stay above native harbor floor")
 g.return_title();g.tick(0)
 check(g.walker==null and not g.ui.bark_panel.visible and g.route_bark_time==0,"title reset clears new-route warning state")
 g.start_arrival();g.skip_arrival();g.tick(0)
 check(g.phase==&"play" and not g.walker.wrong_way_latched and not g.ui.bark_panel.visible,"replay and skip start with clean city warning state")
 finish(g)
