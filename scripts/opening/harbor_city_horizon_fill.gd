extends Node3D
## A fixed northern return behind the accepted native terminal. The western
## city owner remains the sole source of art resources and alpha sampling.
var source_matte: Node3D
var source_waterfront: Node3D
var ridge_material: Material
var ridge_surface_material: StandardMaterial3D
var ridge_mesh: MeshInstance3D
var definitions: Array[Dictionary]=[
 {"id":"north_rooftops","source_id":"rooftops","center_x":-170.0,"z":-465.0,"width":300.0,"base_y":-8.0},
 {"id":"north_skyline","source_id":"skyline","center_x":-360.0,"z":-560.0,"width":600.0,"base_y":-16.0},
 {"id":"north_tail_town","source_id":"rooftops","center_x":-100.0,"z":-590.0,"width":130.0,"base_y":19.0}]
var layers: Array[MeshInstance3D]=[]
var materials: Array[StandardMaterial3D]=[]
var textures: Array[Texture2D]=[]
var used_rects: Dictionary={}
var bounds: Dictionary={}
var ground: MeshInstance3D
var ground_material: Material
var ground_rect:=Rect2(-320,-525,300,105)
var geometry_count:=0
var build_errors: Array[String]=[]
func _ready() -> void:
 name="NorthernInlandHorizonReturn"
 if not is_instance_valid(source_matte):
  _fail("Northern horizon needs the accepted city_matte resource owner");return
 if not is_instance_valid(source_waterfront):
  _fail("Northern horizon needs the accepted native waterfront palette");return
 if ridge_material==null:
  _fail("Northern inland ridge needs the shared native foliage material");return
 _build_inland_ground()
 for definition in definitions:_build_return(definition)
 _build_inland_ridge()
 geometry_count=layers.size()+2
func _build_inland_ridge() -> void:
 # A real rolling inland slope behind the terminal, with its southern foot
 # sharing the accepted ground's z=-525, y=0 edge. The east end returns to
 # ground at x=-20; no surface crosses into the offshore navigation channel.
 var xs: Array[float]=[-290,-270,-250,-225,-200,-175,-150,-125,-100,-80,-65,-55,-40,-30,-20]
 var heights: Array[float]=[0,20,25,25,26,25,26,25,28,27,28,28,24,22,0]
 var crests: Array[float]=[-603,-598,-606,-596,-610,-601,-609,-595,-604,-598,-607,-597,-603,-596,-600]
 var rows: Array=[]
 for row in 5:
  var points: Array[Vector3]=[]
  for column in xs.size():
   var z: float=-525.0;var height_: float=0.0
   if row==1:z=-560.0;height_=heights[column]*.5
   elif row==2:z=crests[column];height_=heights[column]
   elif row==3:z=-660.0;height_=heights[column]*.42
   elif row==4:z=-720.0
   points.append(Vector3(xs[column],height_,z))
  rows.append(points)
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in 4:
  for column in range(xs.size()-1):
   var a: Vector3=rows[row][column];var b: Vector3=rows[row][column+1]
   var c: Vector3=rows[row+1][column+1];var d: Vector3=rows[row+1][column]
   _ridge_triangle(surface,a,b,c);_ridge_triangle(surface,a,c,d)
 # Keep the world's foliage palette and texture untouched; only this distant
 # surface receives softer sampling and a restrained color multiplier.
 ridge_surface_material=ridge_material.duplicate(false) as StandardMaterial3D
 if ridge_surface_material==null:_fail("Native ridge requires a standard foliage material");return
 ridge_surface_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 ridge_surface_material.albedo_color=Color(.93,.87,1,1)
 ridge_mesh=MeshInstance3D.new();ridge_mesh.name="NorthernRollingInlandRidge"
 ridge_mesh.mesh=surface.commit();ridge_mesh.material_override=ridge_surface_material
 ridge_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 ridge_mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED;add_child(ridge_mesh)
 bounds["ridge"]=ridge_mesh.transform*ridge_mesh.get_aabb()
func _ridge_triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
 var normal_: Vector3=(b-a).cross(c-a).normalized()
 # Native harbor triangles use clockwise front faces and outward normals.
 for point in [a,c,b]:
  surface.set_normal(normal_);surface.set_uv(Vector2(point.x,point.z)*.035);surface.add_vertex(point)
func _build_inland_ground() -> void:
 # Real inland ground continues the northern terminal slab at the same y=0
 # datum. It stays west of the offshore channel and has no collision body.
 ground_material=source_waterfront.materials.stone
 var mesh:=BoxMesh.new();mesh.size=Vector3(ground_rect.size.x,2.4,ground_rect.size.y)
 ground=MeshInstance3D.new();ground.name="NorthernInlandGround"
 ground.mesh=mesh;ground.material_override=ground_material
 var center:=ground_rect.get_center();ground.position=Vector3(center.x,-1.2,center.y)
 ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 ground.gi_mode=GeometryInstance3D.GI_MODE_DISABLED;add_child(ground)
 bounds["ground"]=ground.transform*mesh.get_aabb()
func _build_return(definition: Dictionary) -> void:
 var source_index: int=-1
 for i in source_matte.definitions.size():
  if source_matte.definitions[i].id==definition.source_id:source_index=i;break
 if source_index<0 or source_index>=source_matte.materials.size() or source_index>=source_matte.textures.size():
  _fail("Accepted city art is unavailable for "+str(definition.source_id));return
 var source: Dictionary=source_matte.definitions[source_index]
 var used: Rect2i=source_matte.used_rects[definition.source_id]
 if used.size.x<=0 or used.size.y<=0:
  _fail("Accepted city art has no visible alpha region");return
 var material: StandardMaterial3D=source_matte.materials[source_index]
 var texture: Texture2D=source_matte.textures[source_index]
 var width_: float=definition.width
 var height_: float=width_*float(used.size.y)/used.size.x
 definition["path"]=source.path;definition["source_size"]=source.source_size
 definition["used_rect"]=used;definition["height"]=height_
 definition["world_units_per_pixel"]=width_/used.size.x
 used_rects[definition.id]=used
 var quad:=QuadMesh.new();quad.size=Vector2(width_,height_)
 var layer:=MeshInstance3D.new();layer.name=str(definition.id).to_pascal_case()
 layer.mesh=quad;layer.material_override=material
 layer.position=Vector3(definition.center_x,definition.base_y+height_*.5,definition.z)
 layer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 layer.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
 layer.set_meta("city_layer_id",definition.id);layer.set_meta("accepted_art_owner",source_matte.name)
 layer.set_meta("original_png",source.path);layer.set_meta("alpha_used_rect",used)
 add_child(layer)
 layers.append(layer);materials.append(material);textures.append(texture)
 bounds[definition.id]=layer.transform*quad.get_aabb()
func _fail(message: String) -> void:
 build_errors.append(message);push_error(message)
