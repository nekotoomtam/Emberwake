extends SceneTree
## Real source art and native cards; never substitute generated test artwork.
const PATHS: Array[String]=[
 "res://assets/city_backdrop/waterfront-low-v96.png",
 "res://assets/city_backdrop/rooftops.png",
 "res://assets/city_backdrop/skyline-no-clock-v96.png"]
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures.append(message);printerr("FAIL: "+message)
func alpha_evidence(image: Image) -> Dictionary:
 image.convert(Image.FORMAT_RGBA8)
 var data:=image.get_data();var transparent:=0;var opaque:=0
 var left:=image.get_width();var top:=image.get_height();var right:=-1;var bottom:=-1
 for y in image.get_height():
  for x in image.get_width():
   var alpha: int=data[(y*image.get_width()+x)*4+3]
   if alpha==0:transparent+=1
   if alpha>=64:
    left=mini(left,x);right=maxi(right,x);top=mini(top,y);bottom=maxi(bottom,y)
   if alpha>=250:opaque+=1
 return {"transparent":transparent,"opaque":opaque,"used":Rect2i(left,top,right-left+1,bottom-top+1)}
func run() -> void:
 var helper_path:="res://scripts/opening/harbor_city_matte.gd"
 check(FileAccess.file_exists(helper_path),"static image city helper exists")
 var ready_art:=true
 for path in PATHS:
  var exists:=FileAccess.file_exists(path)
  check(exists,"original selected transparent PNG exists: "+path.get_file())
  ready_art=ready_art and exists
 if not ready_art or not FileAccess.file_exists(helper_path):finish();return
 var script=load(helper_path)
 if script==null:check(false,"city helper parses");finish();return
 var helper: Node3D=script.new();root.add_child(helper);await process_frame
 check(helper.build_errors.is_empty(),"all real city assets build without fallback art")
 check(helper.layers.size()==3 and helper.geometry_count==3,"three source images produce exactly three native world cards")
 if helper.layers.size()!=3:helper.queue_free();await process_frame;finish();return
 check(helper.materials.size()==3 and helper.textures.size()==3 and helper.definitions.size()==3,"each city layer owns one retained material and texture")
 check(helper.find_children("*","CollisionObject3D",true,false).is_empty(),"distant image scenery adds no physics bodies")
 check(helper.find_children("*","CollisionShape3D",true,false).is_empty(),"distant image scenery adds no collision shapes")
 check(helper.find_children("*","NavigationRegion3D",true,false).is_empty(),"distant image scenery adds no navigation regions")
 check(not helper.is_processing() and not helper.is_physics_processing() and not helper.has_method("tick"),"city matte has no per-frame activity or rebuilding contract")
 var resource_ids: Array=[];var transforms: Array[Transform3D]=[]
 var previous_z:=0.0
 for i in 3:
  var source:=Image.load_from_file(ProjectSettings.globalize_path(PATHS[i]))
  check(not source.is_empty(),"selected PNG decodes: "+PATHS[i].get_file())
  if source.is_empty():continue
  var evidence:=alpha_evidence(source)
  var pixel_count: int=source.get_width()*source.get_height()
  check(evidence.transparent>pixel_count*.08 and evidence.opaque>200,"city source has true transparent sky and visible opaque architecture: "+PATHS[i].get_file())
  var card: MeshInstance3D=helper.layers[i]
  var material: StandardMaterial3D=helper.materials[i]
  var texture: Texture2D=helper.textures[i]
  var definition: Dictionary=helper.definitions[i]
  check(card.mesh is QuadMesh,"city is consumed as a native image plane")
  var quad: QuadMesh=card.mesh
  check(card.material_override==material and material.albedo_texture==texture,"rendered plane consumes its retained original art texture")
  var gpu_source: Texture2D=texture.atlas if texture is AtlasTexture else texture
  check(gpu_source.get_size()==Vector2(source.get_size()),"source PNG dimensions survive native texture creation")
  check(helper.used_rects[definition.id]==evidence.used,"visible alpha extent excludes faint transparent-padding residues")
  # 3D materials bind a texture RID, not AtlasTexture's 2D region drawing API.
  # Inspect the actual sampled source UVs; region metadata alone cannot prove
  # that the buildings reach the physical sea-level edge of their world card.
  var sampled_min:=Vector2(material.uv1_offset.x,material.uv1_offset.y)*gpu_source.get_size()
  var sampled_size:=Vector2(material.uv1_scale.x,material.uv1_scale.y)*gpu_source.get_size()
  check(sampled_min.distance_to(Vector2(evidence.used.position))<.01 and sampled_size.distance_to(Vector2(evidence.used.size))<.01,"GPU material UVs sample exactly the visible original PNG region")
  var pitch_x: float=quad.size.x/sampled_size.x
  var pitch_y: float=quad.size.y/sampled_size.y
  check(absf(pitch_x-pitch_y)<.0001,"actual rendered source pixels retain equal horizontal and vertical world scale")
  var bottom_v: float=(float(evidence.used.end.y)/source.get_height()-material.uv1_offset.y)/material.uv1_scale.y
  var visible_bottom: float=card.position.y+quad.size.y*.5-bottom_v*quad.size.y
  check(absf(visible_bottom-definition.base_y)<.01,"actual sampled architecture reaches the card's sea-level base without transparent padding below it")
  var expected_aspect: float=float(evidence.used.size.x)/evidence.used.size.y
  check(absf(quad.size.x/quad.size.y-expected_aspect)<.001,"world card preserves actual nontransparent art aspect")
  check(quad.size.x>80 and quad.size.x<1200 and quad.size.y>4 and quad.size.y<150,"distant city card has bounded world scale")
  check(card.position.z< -235 and card.position.z<previous_z-40,"city layers remain behind the original northern coast at separate depths")
  previous_z=card.position.z
  check(card.basis.is_equal_approx(Basis.IDENTITY),"world image stays fixed instead of rotating toward the camera")
  check(absf(card.position.y-quad.size.y*.5-definition.base_y)<.001 and definition.base_y>=-.6 and definition.base_y<=.1,"alpha shoreline base meets existing mean sea level")
  check(material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED and material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,"original color and transparent skyline render without a lit opaque rectangle")
  check(material.alpha_scissor_threshold>0 and material.alpha_scissor_threshold<.6 and not material.no_depth_test,"alpha cutout keeps foreground depth testing")
  check(material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and card.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"city cards neither spin nor cast rectangular shadows")
  var actual_bounds: AABB=card.transform*card.get_aabb()
  check(actual_bounds.is_equal_approx(helper.bounds[definition.id]),"published bounds describe the actual native world card")
  resource_ids.append([card.get_instance_id(),quad.get_instance_id(),material.get_instance_id(),texture.get_instance_id()])
  transforms.append(card.transform)
 # Camera motion may change projections; it must never rebuild or reorient art.
 var camera:=Camera3D.new();root.add_child(camera)
 for at in [Vector3(62,11.45,-13),Vector3(24,11.45,-8),Vector3(17,26,5),Vector3(15,11,19)]:
  camera.position=at;camera.look_at(Vector3(0,2,-250));await process_frame
  for i in 3:
   var card: MeshInstance3D=helper.layers[i]
   check(card.transform.is_equal_approx(transforms[i]),"camera travel leaves world card transform fixed")
   check(resource_ids[i]==[card.get_instance_id(),card.mesh.get_instance_id(),helper.materials[i].get_instance_id(),helper.textures[i].get_instance_id()],"camera travel reuses the same static native resources")
 camera.queue_free();helper.queue_free();await process_frame
 finish()
func finish() -> void:
 print("HARBOR CITY MATTE "+str(checks)+" checks; "+("PASS[]" if failures.is_empty() else "FAIL "+str(failures)))
 quit(0 if failures.is_empty() else 1)
