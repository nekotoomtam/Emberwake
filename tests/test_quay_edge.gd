extends SceneTree
## Native collision checks: sea rails stop a walker; boarding and work lanes stay open.
const Backdrop=preload("res://scripts/opening/harbor_backdrop.gd")
const Detail=preload("res://scripts/opening/harbor_detail.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func _crossing(from: Vector3,motion: Vector3) -> KinematicCollision3D:
 var actor:=CharacterBody3D.new();actor.collision_layer=2;actor.collision_mask=1
 var col:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.4;capsule.radius=.24;col.shape=capsule;col.position.y=.7;actor.add_child(col)
 root.add_child(actor);actor.position=from
 var hit:=actor.move_and_collide(motion)
 actor.free();return hit
func _building_mesh_bounds(building: Dictionary,mats: Dictionary) -> AABB:
 # Exercise the real authored mesh, including roof beams, eaves and window sills.
 var probe:=Backdrop.new();probe.mats=mats;probe.b=Detail.new();probe.add_child(probe.b)
 probe._building(building.at,building.width,building.height,building.depth,mats.cream,false,0)
 probe.b.finish()
 var bounds:=AABB();var first:=true
 for mesh in probe.b.get_children():
  if mesh is MeshInstance3D:
   var part: AABB=mesh.mesh.get_aabb()
   bounds=part if first else bounds.merge(part);first=false
 probe.free();return bounds
func run() -> void:
 var path:="res://scripts/opening/harbor_quay_edge.gd"
 check(ResourceLoader.exists(path),"public coast has a native quay-edge helper")
 if ResourceLoader.exists(path):
  var edge=load(path).new();root.add_child(edge)
  await physics_frame;await physics_frame
  check(_crossing(Vector3(-20.6,.055,-8),Vector3(2.2,0,0))!=null,"west sea rail physically stops the walker")
  check(_crossing(Vector3(-20.6,.055,3.2),Vector3(2.2,0,-2.2))!=null,"square west-to-foreground rail joint has no diagonal escape")
  check(_crossing(Vector3(0,.055,3.2),Vector3(0,0,-2.2))!=null,"foreground sea rail physically stops the walker")
  check(_crossing(Vector3(18,.055,3.2),Vector3(0,0,-2.2))!=null,"foreground rail resumes after boarding opening")
  check(_crossing(Vector3(21,.055,10),Vector3(2,0,0))!=null,"east quay end physically stops the walker")
  check(_crossing(Vector3(-42,.055,14.2),Vector3(0,0,2.2))!=null,"trimmed south plaza edge physically stops the walker")
  for x in [11.2,13.0,14.8]:
   check(_crossing(Vector3(x,.055,3.2),Vector3(0,0,-2.2))==null,"boarding opening stays usable at x "+str(x))
  for z in [3.1,6.0,11.9]:
   check(_crossing(Vector3(-22.0,.055,z),Vector3(6,0,0))==null,"plaza-to-quay connector has no barrier at z "+str(z))
  for z in [-29,-72,-110,-148,-186]:
   check(_crossing(Vector3(-22,.055,z),Vector3(7,0,0))==null,"cargo berth throat stays clear at z "+str(z))
  var bodies: Array=edge.find_children("*","StaticBody3D",true,false)
  check(bodies.size()>=5,"rails have matching native collision bodies")
  for body in bodies:
   var shape: BoxShape3D=body.get_child(0).shape
   check(shape.size.y>=.9 and shape.size.y<=1.0,"rail body height matches a low public safety rail")
  print("QUAY EDGE GEOMETRY ",edge.geometry_count,"; collision bodies ",bodies.size())
  edge.free();await physics_frame
 var city=load("res://scripts/opening/harbor_backdrop.gd").new();root.add_child(city)
 var warehouses:=0;var residences:=0;var intrusions:=0;var mesh_intrusions:=0
 var reserve:=Rect2(Vector2(-52,-20.5),Vector2(32.3,39))
 for building in city.buildings:
  if building.warehouse:warehouses+=1;continue
  residences+=1
  # Roof eaves extend 7%/8% beyond wall bounds; include them in the reserve.
  var width: float=maxf(building.width*1.14,building.width+.25)
  var depth: float=maxf(building.depth*1.16,building.depth+.25)
  var at: Vector3=building.at
  if reserve.intersects(Rect2(Vector2(at.x-width*.5,at.z-depth*.5),Vector2(width,depth)),true):intrusions+=1
  var mesh: AABB=_building_mesh_bounds(building,city.mats)
  if reserve.intersects(Rect2(Vector2(mesh.position.x,mesh.position.z),Vector2(mesh.size.x,mesh.size.z)),true):mesh_intrusions+=1
 check(intrusions==0,"residential building footprints leave the authored plaza reserve clear")
 check(mesh_intrusions==0,"actual complete residential meshes leave the authored plaza reserve clear")
 check(residences>=110,"plaza carving preserves a dense distant city")
 check(warehouses==5 and city.warehouse_fronts.size()==5 and city.loading_yards.size()==5,"all five warehouse fronts and loading courts remain")
 check(city.warehouse_fronts[0].distance_to(Vector3(-27.22,0,-29))<.001,"first warehouse door remains at the existing cargo lane")
 print("COAST CITY residences ",residences,"; warehouses ",warehouses,"; reserve intrusions ",intrusions,"; full-mesh intrusions ",mesh_intrusions)
 city.free();await process_frame
 print("QUAY EDGE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
