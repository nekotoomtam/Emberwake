extends Node3D
## Reusable visual sea. World owns the absolute clock; all vertices/materials
## remain static resources and no wave owns a physics or navigation body.
const WaterShader=preload("res://scripts/opening/harbor_sea_water.gdshader")
const ShoreShader=preload("res://scripts/opening/harbor_sea_shore.gdshader")
const Spectrum=preload("res://scripts/opening/harbor_wave_spectrum.gd")
const MEAN_LEVEL: float=Spectrum.MEAN
const WAVE_LIMIT: float=1.10
const NEAR_RECT:=Rect2(Vector2(-110,-245),Vector2(255,290))
const NEAR_PITCH: float=1.5
const SHORE_INNER: float=.30
const SHORE_OUTER: float=2.30
var near_mesh: MeshInstance3D
var far_mesh: MeshInstance3D
var shore_mesh: MeshInstance3D
var water_material: ShaderMaterial
var shore_material: ShaderMaterial
var reflection_texture: Texture2D
var clock: float=0.0
var near_vertex_count:=0
var far_vertex_count:=0
var shore_vertex_count:=0
var shore_patch_count:=0
var geometry_count:=0
var shore_segments: Array[Dictionary]=[
 {"a":Vector2(-79,17.5),"b":Vector2(-51,17.5),"outward":Vector2(0,1)},
 {"a":Vector2(-51,15.4),"b":Vector2(-51,17.5),"outward":Vector2(1,0)},
 {"a":Vector2(-51,15.4),"b":Vector2(22,15.4),"outward":Vector2(0,1)},
 {"a":Vector2(22,2.1),"b":Vector2(22,15.4),"outward":Vector2(1,0)},
 {"a":Vector2(-19.55,2.1),"b":Vector2(4.8,2.1),"outward":Vector2(0,-1)},
 {"a":Vector2(9.2,2.1),"b":Vector2(22,2.1),"outward":Vector2(0,-1)},
 {"a":Vector2(-19.55,-20),"b":Vector2(-19.55,2.1),"outward":Vector2(1,0)}
]
func _ready() -> void:
 name="OpenSea"
 water_material=ShaderMaterial.new();water_material.shader=WaterShader
 water_material.set_shader_parameter("mean_level",MEAN_LEVEL)
 var waterline:=PackedVector4Array()
 for segment in shore_segments:
  var a: Vector2=segment.a
  var b: Vector2=segment.b
  waterline.append(Vector4(a.x,a.y,b.x,b.y))
 water_material.set_shader_parameter("waterline",waterline)
 shore_material=ShaderMaterial.new();shore_material.shader=ShoreShader;shore_material.render_priority=2
 _build_water();_build_shore();set_clock(clock)
func set_clock(value: float) -> void:
 clock=value
 if water_material!=null:water_material.set_shader_parameter("clock",clock)
 if shore_material!=null:shore_material.set_shader_parameter("clock",clock)
func sync_player_reflection(sprite: Sprite3D) -> void:
 var visible_player:=is_instance_valid(sprite) and sprite.is_visible_in_tree() and sprite.texture!=null
 water_material.set_shader_parameter("player_reflection_visible",visible_player)
 if not visible_player:return
 if sprite.texture!=reflection_texture:
  reflection_texture=sprite.texture
  water_material.set_shader_parameter("player_reflection_texture",reflection_texture)
 var pose:=sprite.global_transform
 var rect:=sprite.get_item_rect()
 var center:=rect.get_center()
 var origin:=pose.origin+(pose.basis.x*center.x-pose.basis.y*center.y)*sprite.pixel_size
 water_material.set_shader_parameter("player_reflection_origin",origin)
 water_material.set_shader_parameter("player_reflection_right",pose.basis.x.normalized())
 water_material.set_shader_parameter("player_reflection_up",pose.basis.y.normalized())
 water_material.set_shader_parameter("player_reflection_size",rect.size*sprite.pixel_size*Vector2(pose.basis.x.length(),pose.basis.y.length()))
func surface_height(at: Vector2,time: float) -> float:
 return Spectrum.height(at,time)
func _axis(start: float,end: float,cells: int) -> PackedFloat32Array:
 var result:=PackedFloat32Array();result.resize(cells+1)
 for i in cells+1:result[i]=lerpf(start,end,float(i)/cells)
 return result
func _append_grid(mesh: ArrayMesh,xs: PackedFloat32Array,zs: PackedFloat32Array) -> int:
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
 var columns:=xs.size();var rows:=zs.size();vertices.resize(columns*rows);normals.resize(columns*rows)
 for z in rows:
  for x in columns:
   var index:=z*columns+x;vertices[index]=Vector3(xs[x],MEAN_LEVEL,zs[z]);normals[index]=Vector3.UP
 indices.resize((columns-1)*(rows-1)*6);var cursor:=0
 for z in rows-1:
  for x in columns-1:
   var a:=z*columns+x;var b:=a+1;var c:=a+columns+1;var d:=a+columns
   for index in [a,c,b,a,d,c]:indices[cursor]=index;cursor+=1
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return vertices.size()
func _visual(label: String,mesh: ArrayMesh,material: ShaderMaterial) -> MeshInstance3D:
 var visual:=MeshInstance3D.new();visual.name=label;visual.mesh=mesh;visual.material_override=material;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var bounds: AABB=mesh.get_aabb();bounds.position.y=MEAN_LEVEL-WAVE_LIMIT-.015;bounds.size.y=WAVE_LIMIT*2+.03;visual.custom_aabb=bounds;add_child(visual)
 return visual
func _build_water() -> void:
 var xs:=_axis(NEAR_RECT.position.x,NEAR_RECT.end.x,ceili(NEAR_RECT.size.x/NEAR_PITCH))
 var zs:=_axis(NEAR_RECT.position.y,NEAR_RECT.end.y,ceili(NEAR_RECT.size.y/NEAR_PITCH))
 var near_grid:=ArrayMesh.new();near_vertex_count=_append_grid(near_grid,xs,zs)
 near_mesh=_visual("NearHarborWaves",near_grid,water_material)
 # Four disjoint exterior patches share every boundary vertex with the dense
 # grid. Their animated edges meet exactly; no far sheet covers local troughs.
 var north:=PackedFloat32Array([-5500,-2500,-1000,-500,-350,-290,-260,-245])
 var south:=PackedFloat32Array([45,47,51,61,85,140,280,600,1500,3000,4500])
 var all_z:=PackedFloat32Array()
 for i in north.size()-1:all_z.append(north[i])
 all_z.append_array(zs)
 for i in range(1,south.size()):all_z.append(south[i])
 var far_grid:=ArrayMesh.new()
 far_vertex_count+=_append_grid(far_grid,PackedFloat32Array([-6000,-3000,-1500,-700,-350,-200,-150,-125,-115,-110]),all_z)
 far_vertex_count+=_append_grid(far_grid,PackedFloat32Array([145,150,160,180,220,300,500,900,1800,3500,6000]),all_z)
 far_vertex_count+=_append_grid(far_grid,xs,north)
 far_vertex_count+=_append_grid(far_grid,xs,south)
 far_mesh=_visual("DistantOcean",far_grid,water_material)
 geometry_count=near_grid.get_faces().size()/3+far_grid.get_faces().size()/3
func _build_shore() -> void:
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
 for segment_index in shore_segments.size():
  var segment: Dictionary=shore_segments[segment_index]
  var a: Vector2=segment.a;var b: Vector2=segment.b;var outward: Vector2=segment.outward
  var length_: float=a.distance_to(b);var tangent: Vector2=(b-a)/length_
  var endpoint_pad: float=minf(.48,length_*.22);var available: float=length_-endpoint_pad*2.0
  var patches:=maxi(1,ceili(available/4.8));var span: float=available/patches
  for patch in patches:
   var start: float=endpoint_pad+patch*span+.10;var end: float=endpoint_pad+(patch+1)*span-.10
   var along_steps:=maxi(2,ceili((end-start)/.45));var across_steps:=9
   var first:=vertices.size();var phase: float=fposmod((shore_patch_count+1)*.38196601125+segment_index*.173,1.0)
   for along in along_steps+1:
    var u: float=float(along)/along_steps
    for across in across_steps+1:
     var v: float=float(across)/across_steps
     var point: Vector2=a+tangent*lerpf(start,end,u)+outward*lerpf(SHORE_INNER,SHORE_OUTER,v)
     vertices.append(Vector3(point.x,MEAN_LEVEL,point.y));normals.append(Vector3.UP);uvs.append(Vector2(u,v));colors.append(Color(phase,0,0,1))
   var columns:=across_steps+1
   for along in along_steps:
    for across in across_steps:
     var p:=first+along*columns+across;var q:=p+1;var r:=p+columns+1;var s:=p+columns
     indices.append_array(PackedInt32Array([p,r,q,p,s,r]))
   shore_patch_count+=1
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var shore_grid:=ArrayMesh.new();shore_grid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 shore_vertex_count=vertices.size();geometry_count+=indices.size()/3
 shore_mesh=_visual("ShorewardWashAndFoam",shore_grid,shore_material)
