extends Node3D
## Small deterministic prewarmed plumes, driven only by the world's clock.
## All origins come from the builders that draw the actual chimney caps.
const PUFFS_PER_CHIMNEY:=9
const LIFETIME:=10.0
var outlets: Array=[]
var sources: Array[Vector3]=[]
var batch: MultiMeshInstance3D
var material: StandardMaterial3D
func _ready() -> void:
 name="HarborChimneySmoke"
 # Leave most chimneys quiet; evenly spaced active roofs imply occupied
 # homes and workshops without turning the sunny harbor into a fire scene.
 for index in outlets.size():
  if index%4==0:sources.append(outlets[index])
 var gradient:=Gradient.new()
 gradient.set_color(0,Color(1,1,1,.72));gradient.set_color(1,Color(1,1,1,0))
 gradient.add_point(.33,Color(1,1,1,.44));gradient.add_point(.72,Color(1,1,1,.06))
 var texture:=GradientTexture2D.new();texture.gradient=gradient;texture.width=64;texture.height=64
 texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(.98,.5)
 material=StandardMaterial3D.new();material.albedo_texture=texture
 material.vertex_color_use_as_albedo=true;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR;material.no_depth_test=false
 var quad:=QuadMesh.new();quad.size=Vector2.ONE
 var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.use_colors=true
 instances.mesh=quad;instances.instance_count=sources.size()*PUFFS_PER_CHIMNEY
 batch=MultiMeshInstance3D.new();batch.name="SharedSoftSmokePuffs";batch.multimesh=instances;batch.material_override=material
 batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;batch.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
 add_child(batch)
func tick(_delta: float,camera: Camera3D,clock: float) -> void:
 if not is_instance_valid(camera):return
 for chimney in sources.size():
  var origin: Vector3=sources[chimney];var phase: float=fmod(chimney*1.731,LIFETIME)
  var near_alpha: float=1-smoothstep(180,300,camera.global_position.distance_to(origin))
  for puff in PUFFS_PER_CHIMNEY:
   var index: int=chimney*PUFFS_PER_CHIMNEY+puff
   var age: float=fposmod(clock+phase+puff*LIFETIME/PUFFS_PER_CHIMNEY,LIFETIME)
   var u: float=age/LIFETIME
   var position_: Vector3=origin+Vector3(age*.20+sin(age*.8+chimney)*u*.35,age*.52,age*.065+sin(age*.5+chimney)*u*.22)
   var size_: float=lerpf(.60,3.4,u)
   var basis_: Basis=camera.global_basis*Basis(Vector3.FORWARD,u*.8+chimney*.37)
   basis_=basis_.scaled_local(Vector3(size_,size_*1.15,size_))
   batch.multimesh.set_instance_transform(index,Transform3D(basis_,position_))
   var alpha: float=.55*smoothstep(0,.10,u)*(1-smoothstep(.50,1,u))*near_alpha
   batch.multimesh.set_instance_color(index,Color(.78,.79,.76,alpha))
