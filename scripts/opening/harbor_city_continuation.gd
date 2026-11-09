extends Node3D
## Fixed inland scenery: continue the accepted paintings past their exposed
## southern ends and layer roof terraces over the northern bare hill face.
## Shares original textures/materials and never follows the camera.
var source_matte: Node3D
var layers: Array[MeshInstance3D]=[]
var build_errors: Array[String]=[]
var definitions: Array[Dictionary]=[
 {"id":"WestRoofReturn","source":"rooftops","at":Vector3(-207,-2,5),"width":300.0,"yaw":PI*.5},
 {"id":"WestSkylineReturn","source":"skyline","at":Vector3(-275,14,-8),"width":450.0,"yaw":PI*.5},
 {"id":"NorthHillTerraces","source":"rooftops","at":Vector3(-155,1,-544),"width":260.0,"yaw":0.0},
 {"id":"NorthHillCrown","source":"rooftops","at":Vector3(-155,12,-581),"width":260.0,"yaw":0.0}]
func _ready() -> void:
 name="InlandCityContinuations"
 for definition in definitions:
  var index: int=-1
  for i in source_matte.definitions.size():
   if source_matte.definitions[i].id==definition.source:index=i;break
  if index<0:build_errors.append("Missing accepted city layer "+str(definition.source));continue
  var used: Rect2i=source_matte.used_rects[definition.source]
  var height_: float=float(definition.width)*used.size.y/used.size.x
  var mesh:=QuadMesh.new();mesh.size=Vector2(definition.width,height_)
  var layer:=MeshInstance3D.new();layer.name=definition.id;layer.mesh=mesh
  layer.material_override=source_matte.materials[index]
  layer.position=definition.at+Vector3.UP*height_*.5;layer.rotation.y=definition.yaw
  layer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;layer.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
  add_child(layer);layers.append(layer)
