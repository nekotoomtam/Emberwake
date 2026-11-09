extends Node3D
## Retained inland paintings behind the native 3D waterfront extension.
## Fixed inland orientation and buried bases let real roofs/land conceal
## their footings along the coast instead of only at its northern tip.
## Explicit 3D material UVs remove padding; original PNG bytes stay untouched.
const ALPHA_SCISSOR_THRESHOLD: float=.25
var definitions: Array[Dictionary]=[
 {"id":"rooftops","path":"res://assets/city_backdrop/rooftops.png","center_x":-205.0,"z":-260.0,"width":300.0,"base_y":-8.0,"rotation_y":PI*.5},
 {"id":"skyline","path":"res://assets/city_backdrop/skyline-no-clock-v96.png","center_x":-270.0,"z":-330.0,"width":450.0,"base_y":-16.0,"rotation_y":PI*.5}]
var layers: Array[MeshInstance3D]=[]
var materials: Array[StandardMaterial3D]=[]
var textures: Array[Texture2D]=[]
var used_rects: Dictionary={}
var bounds: Dictionary={}
var geometry_count:=0
var build_errors: Array[String]=[]
static var source_art: Dictionary={}
func _ready() -> void:
 name="LayeredHarborCityMatte"
 for definition in definitions:_build_layer(definition)
 geometry_count=layers.size()
func _build_layer(definition: Dictionary) -> void:
 var id_: String=definition.id
 var path: String=definition.path
 var source:=_source_art(path)
 if source.is_empty():return
 var used: Rect2i=source.used_rect
 var size_: Vector2i=source.source_size
 var texture: Texture2D=source.texture
 var width_: float=definition.width
 var height_: float=width_*float(used.size.y)/used.size.x
 definition["source_size"]=size_;definition["used_rect"]=used
 definition["source_used_rect"]=source.source_used_rect;definition["alpha_threshold"]=ALPHA_SCISSOR_THRESHOLD
 definition["source_load_mode"]=source.load_mode
 definition["height"]=height_;definition["world_units_per_pixel"]=width_/used.size.x
 used_rects[id_]=used
 var material:=StandardMaterial3D.new()
 material.resource_name="OriginalCityMatte_"+id_
 material.albedo_texture=texture;material.albedo_color=Color.WHITE
 # The layer owns its tint and UV transform, including mirrored placements.
 material.uv1_scale=Vector3(float(used.size.x)/size_.x,float(used.size.y)/size_.y,1)
 material.uv1_offset=Vector3(float(used.position.x)/size_.x,float(used.position.y)/size_.y,0)
 material.texture_repeat=false
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 material.alpha_scissor_threshold=ALPHA_SCISSOR_THRESHOLD
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 material.billboard_mode=BaseMaterial3D.BILLBOARD_DISABLED
 material.no_depth_test=false
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 material.disable_receive_shadows=true
 var quad:=QuadMesh.new();quad.size=Vector2(width_,height_)
 var layer:=MeshInstance3D.new();layer.name="CityMatte_"+id_.capitalize()
 layer.mesh=quad;layer.material_override=material
 layer.position=Vector3(definition.center_x,definition.base_y+height_*.5,definition.z)
 layer.rotation.y=float(definition.get("rotation_y",0.0))
 layer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 layer.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
 layer.set_meta("city_layer_id",id_);layer.set_meta("original_png",path)
 layer.set_meta("alpha_used_rect",used);layer.set_meta("world_units_per_pixel",width_/used.size.x)
 add_child(layer)
 bounds[id_]=layer.transform*quad.get_aabb()
 layers.append(layer);materials.append(material);textures.append(texture)
func _source_art(path: String) -> Dictionary:
 if source_art.has(path):return source_art[path]
 var imported_available:=ResourceLoader.exists(path,"Texture2D")
 var source_available:=FileAccess.file_exists(path)
 if not imported_available and not source_available:
  _fail("Missing original city artwork: "+path);return {}
 # Resource loading follows Godot's import remaps and works inside exports.
 # Loose PNG fallback supports an unimported source checkout only.
 var image: Image
 var load_mode: String
 if imported_available:
  var imported: Texture2D=load(path) as Texture2D
  if imported!=null:image=imported.get_image();load_mode="imported_texture"
 if (image==null or image.is_empty()) and source_available:
  image=Image.load_from_file(ProjectSettings.globalize_path(path));load_mode="loose_source_png"
 if image==null or image.is_empty():_fail("Cannot decode original city artwork: "+path);return {}
 if image.is_compressed() and image.decompress()!=OK:
  _fail("Cannot decode imported city texture: "+path);return {}
 if image.detect_alpha()==Image.ALPHA_NONE:
  _fail("City artwork needs genuine transparent sky: "+path);return {}
 var used:=_visible_alpha_rect(image)
 if used.size.x<=0 or used.size.y<=0:
  _fail("City artwork has no visible architecture: "+path);return {}
 var data: Dictionary={"source_size":image.get_size(),"source_used_rect":image.get_used_rect(),
  "used_rect":used,"load_mode":load_mode}
 image.generate_mipmaps()
 data["texture"]=ImageTexture.create_from_image(image)
 source_art[path]=data
 return data
func _visible_alpha_rect(image: Image) -> Rect2i:
 # Generated PNGs can contain alpha=1 specks far outside their visible skyline.
 # Use the same threshold as native cutout rendering, keeping the original
 # atlas unmodified and deriving the real occupied aspect rather than a wall.
 image.convert(Image.FORMAT_RGBA8)
 var data:=image.get_data();var width_: int=image.get_width()
 var left:=width_;var top: int=image.get_height();var right:=-1;var bottom:=-1
 var minimum_alpha: int=ceili(ALPHA_SCISSOR_THRESHOLD*255)
 for y in image.get_height():
  for x in width_:
   if data[(y*width_+x)*4+3]<minimum_alpha:continue
   left=mini(left,x);right=maxi(right,x);top=mini(top,y);bottom=maxi(bottom,y)
 return Rect2i(left,top,maxi(0,right-left+1),maxi(0,bottom-top+1))
func _fail(message: String) -> void:
 build_errors.append(message);push_error(message)
