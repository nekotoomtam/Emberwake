extends SceneTree
## Focused v96 acceptance at the actual prologue/selected artwork boundary.
const REVISED_WATERFRONT:="res://assets/city_backdrop/waterfront-low-v96.png"
const REVISED_SKYLINE:="res://assets/city_backdrop/skyline-no-clock-v96.png"
const CAMERA_SHA:="7FADE685A12251661701714D1264251EC3A2D6318EBF858EFE2F5566381DACD4"
const ROOFTOPS_SHA:="36B621638B0B517BD986F3F72A1828D22A6A47472B66E4736D1811F5356BC844"
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func has_property(object: Object,label: String) -> bool:
 for property in object.get_property_list():
  if property.name==label:return true
 return false
func alpha_content(path_: String) -> bool:
 var image:=Image.load_from_file(ProjectSettings.globalize_path(path_))
 if image==null or image.is_empty() or image.detect_alpha()==Image.ALPHA_NONE:return false
 var clear:=false;var opaque:=false
 var pitch: int=maxi(1,mini(image.get_width(),image.get_height())/128)
 for y in range(0,image.get_height(),pitch):
  for x in range(0,image.get_width(),pitch):
   var alpha:=image.get_pixel(x,y).a;clear=clear or alpha<.001;opaque=opaque or alpha>.95
 return clear and opaque
func state(matte: Node3D) -> Array:
 var result: Array=[]
 for index in matte.layers.size():
  var layer: MeshInstance3D=matte.layers[index]
  result.append([layer.get_instance_id(),layer.global_transform,layer.mesh.get_instance_id(),layer.material_override.get_instance_id(),matte.textures[index].get_instance_id()])
 return result
func projected_box(box: AABB) -> Rect2:
 var first:=true;var result:=Rect2()
 for x in [box.position.x,box.end.x]:
  for y in [box.position.y,box.end.y]:
   var at:=Vector3(x,y,box.position.z)
   var screen: Vector2=g.camera.unproject_position(at)
   if first:result=Rect2(screen,Vector2.ZERO);first=false
   else:result=result.expand(screen)
 return result
func finish() -> void:
 if g!=null:g.audio.shutdown();g.free()
 print("HARBOR CITY REVISION v96 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 # Declared selection is a meaningful RED before revised art/imports exist;
 # after this boundary passes, every assertion uses the actual prologue.
 var declared=load("res://scripts/opening/harbor_city_matte.gd").new()
 var paths: Dictionary={}
 for definition in declared.definitions:paths[str(definition.id)]=str(definition.path)
 declared.free()
 var selected: bool=paths.get("waterfront","")==REVISED_WATERFRONT and paths.get("skyline","")==REVISED_SKYLINE and paths.get("rooftops","")=="res://assets/city_backdrop/rooftops.png"
 check(selected,"actual world selects the low working waterfront and skyline without the clocktower, retaining original rooftops")
 if not selected:finish();return
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var matte=g.world.get("city_matte") if has_property(g.world,"city_matte") else null
 check(matte!=null,"actual prologue composes the city layers")
 if matte==null:finish();return
 check(matte.build_errors.is_empty() and matte.layers.size()==3,"revised source composes the same three static native image layers")
 if not matte.build_errors.is_empty() or matte.layers.size()!=3:finish();return
 var by_id: Dictionary={}
 for definition in matte.definitions:by_id[str(definition.id)]=definition
 check(str(by_id.waterfront.path)==REVISED_WATERFRONT and str(by_id.skyline.path)==REVISED_SKYLINE,"actual prologue retains the two selected revised image resources")
 check(FileAccess.file_exists(REVISED_WATERFRONT) and FileAccess.file_exists(REVISED_SKYLINE) and alpha_content(REVISED_WATERFRONT) and alpha_content(REVISED_SKYLINE),"both revised PNGs are genuine retained alpha artwork with clear sky/water pixels")
 var changed_art:=FileAccess.get_sha256(REVISED_WATERFRONT)!=FileAccess.get_sha256("res://assets/city_backdrop/waterfront.png") and FileAccess.get_sha256(REVISED_SKYLINE)!=FileAccess.get_sha256("res://assets/city_backdrop/skyline.png")
 check(changed_art and FileAccess.file_exists("res://assets/city_backdrop/waterfront.png") and FileAccess.file_exists("res://assets/city_backdrop/skyline.png"),"revised paintings differ from the retained original v95 sources")
 check(FileAccess.get_sha256("res://assets/city_backdrop/rooftops.png").to_upper()==ROOFTOPS_SHA and FileAccess.get_sha256("res://scripts/opening/harbor_camera.gd").to_upper()==CAMERA_SHA,"original roof artwork and all product-camera trajectories remain byte-identical")
 var cards:=state(matte)
 g.camera.set_view(&"port",0);g.world.tick(0,g.camera)
 var projected: Dictionary={}
 for index in matte.layers.size():
  var definition: Dictionary=matte.definitions[index];var id_: String=str(definition.id);var box: AABB=matte.bounds[id_]
  projected[id_]=projected_box(box)
  var used: Rect2i=matte.used_rects[id_];var actual: AABB=matte.layers[index].global_transform*matte.layers[index].mesh.get_aabb()
  check(box.end.z< -220 and is_equal_approx(actual.size.y/actual.size.x,float(used.size.y)/used.size.x),"far original-aspect native plane retained: "+id_)
 # A directional comparison against v95, not arbitrary final coordinates.
 # Actual silhouettes/low wharf/loading access/clock removal remain photo gates.
 var old_waterfront: Vector2=g.camera.unproject_position(Vector3(170,matte.layers[0].global_position.y,-250))
 var old_skyline: Vector2=g.camera.unproject_position(Vector3(130,matte.layers[2].global_position.y,-430))
 var shifted_left: bool=g.camera.unproject_position(matte.layers[0].global_position).x<old_waterfront.x and g.camera.unproject_position(matte.layers[2].global_position).x<old_skyline.x
 check(shifted_left,"unchanged original port camera places revised waterfront/skyline left of their v95 positions")
 # Agreed geography gate: continue behind the native west bank and leave the
 # separate lighthouse/water side open. Exact art silhouettes remain visual.
 var native_west: Vector2=g.camera.unproject_position(Vector3(-164,0,-220))
 var lighthouse: Vector2=g.camera.unproject_position(g.world.lighthouse.global_position)
 var continuous:=true
 for id_: String in ["waterfront","skyline"]:
  var projected_layer: Rect2=projected[id_]
  continuous=continuous and projected_layer.position.x<=native_west.x and projected_layer.end.x<lighthouse.x
 check(continuous,"original port view continues the far artwork behind the native west bank while keeping it left of the separate lighthouse")
 print("CITY REVISION ORIGINAL PORT PROJECTED BOUNDS ",projected)
 for view: StringName in [&"quay",&"lighthouse",&"port"]:
  g.camera.set_view(view,0);g.world.tick(.01,g.camera)
  check(state(matte)==cards,"original "+str(view)+" view retains fixed world cards and their native resources")
 check(g.world.main.visible and g.world.ship.visible and g.world.arrival.visible and g.world.backdrop.visible and g.world.lighthouse.visible and g.world.sea_surface.visible,"every original foreground/native city/ship/lighthouse/sea remains visible")
 finish()
