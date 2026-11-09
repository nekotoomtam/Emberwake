extends Node3D
## Curved displacement crests start at the stem, fan outward and stream aft.
const Hull=preload("res://scripts/opening/ship_hull_surface.gd")
const ShaderSource=preload("res://scripts/opening/ship_bow_wave.gdshader")
const ALONG:=48
const ACROSS:=10
var visual: MeshInstance3D
var material: ShaderMaterial
func _ready() -> void:
 name="BowDisplacementWave"
 material=ShaderMaterial.new();material.shader=ShaderSource;material.render_priority=3
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
 for side in [-1.0,1.0]:
  var first:=vertices.size()
  for along in ALONG+1:
   var u: float=float(along)/ALONG;var center:=centerline(u,side)
   var width: float=lerpf(.40,1.70,smoothstep(0,.55,u))
   for across in ACROSS+1:
    var v: float=float(across)/ACROSS
    vertices.append(center+Vector3(0,0,side*(v-.25)*width))
    normals.append(Vector3.UP);uvs.append(Vector2(u,v))
  for along in ALONG:
   for across in ACROSS:
    var a:=first+along*(ACROSS+1)+across;var b:=a+ACROSS+1
    indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 visual=MeshInstance3D.new();visual.name="CurvedBowCrests";visual.mesh=mesh;visual.material_override=material
 visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 visual.custom_aabb=AABB(Vector3(3,-1.2,-8),Vector3(12,3.5,16));add_child(visual)
func centerline(u: float,side: float) -> Vector3:
 var x: float=14.35-u*9.4
 return Vector3(x,.055,side*(Hull.waterline_half_width(x)+.18+pow(u,.72)*2.5))
func tick(clock: float,drive: float,seed_: float) -> void:
 material.set_shader_parameter("clock",clock)
 material.set_shader_parameter("drive",clampf(drive,0,1))
 material.set_shader_parameter("seed",seed_)
