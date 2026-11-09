extends Node3D
## A low carved-stone public fountain. The basin has a real circular boundary;
## water is a separate animated surface, six falling jets and a scalloped sheet.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var materials: Dictionary={}
var geometry_count:=0
var water_time:=0.0
var water_phase:=0.0
var basin_water: MeshInstance3D
var water_material: ShaderMaterial
var stream_material: ShaderMaterial
var ripple_material: ShaderMaterial
var splash_rings: Array[MeshInstance3D]=[]
var _geometry
func _ready() -> void:
 if not materials.has("stone"):materials.stone=Detail.material("b7b0a0","plaster",8951)
 if not materials.has("cream"):materials.cream=Detail.material("e9dabb","plaster",8952)
 if not materials.has("stone2"):materials.stone2=Detail.material("a7a596","plaster",8953)
 if not materials.has("gold"):materials.gold=Detail.material("cfa76f","wood",8954)
 if not materials.has("iron"):materials.iron=Detail.material("3e5357","slate",8955)
 _geometry=Detail.new();_geometry.name="CarvedLimestoneBasin";add_child(_geometry)
 var radius: float=Profile.FOUNTAIN_RADIUS
 _geometry.cylinder(Vector3(0,.05,0),radius,.10,materials.stone2,48)
 _ring(.17,.24,radius-.10,radius-.34,materials.stone,48)
 _ring(.36,.14,radius-.16,radius-.40,materials.stone,48)
 _ring(.46,.09,radius,radius-.31,materials.cream,48)
 # Alternating coping joints and modest copper rosettes make the basin readable.
 for i in 24:
  var angle: float=TAU*i/24
  var direction:=Vector3(cos(angle),0,sin(angle))
  _geometry.beam(direction*(radius-.31)+Vector3.UP*.507,direction*radius+Vector3.UP*.507,.018,materials.stone2)
  if i%4==0:
   var at: Vector3=direction*(radius-.157)+Vector3.UP*.30
   _geometry.boulder(at,Vector3(.14,.12,.14),materials.gold,8970+i)
 # The internal stone floor is below the waterline; no opaque blue water block.
 _geometry.cylinder(Vector3(0,.105,0),radius-.30,.035,materials.stone2,48)
 _geometry.cylinder(Vector3(0,.19,0),.58,.21,materials.stone,24,.44)
 _geometry.cylinder(Vector3(0,.38,0),.33,.30,materials.cream,24,.23)
 _geometry.cylinder(Vector3(0,.57,0),.22,.19,materials.stone,24,.28)
 _geometry.cylinder(Vector3(0,.71,0),.28,.12,materials.cream,24,.48)
 _ring(.82,.10,.65,.35,materials.cream,36)
 _geometry.cylinder(Vector3(0,.84,0),.35,.055,materials.stone,24)
 _geometry.cylinder(Vector3(0,.98,0),.10,.25,materials.stone,16,.075)
 _geometry.cylinder(Vector3(0,1.13,0),.13,.065,materials.gold,16,.07)
 # A disk matching the visible basin prevents walking into water.
 var body:=StaticBody3D.new();body.name="FountainBasinCollision";body.collision_layer=1;body.add_to_group("harbor_plaza_fountain")
 var collider:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=.53;collider.shape=shape;collider.position.y=.265;body.add_child(collider);add_child(body)
 _make_water(radius-.32)
 geometry_count+=_geometry.count;_geometry.finish()
func _ring(y: float,height: float,outer: float,inner: float,mat: Material,segments: int) -> void:
 for i in segments:
  var a: float=TAU*i/segments;var b: float=TAU*(i+1)/segments
  var da:=Vector3(cos(a),0,sin(a));var db:=Vector3(cos(b),0,sin(b))
  var top: float=y+height*.5;var bottom: float=y-height*.5
  _geometry.quad(da*outer+Vector3.UP*top,db*outer+Vector3.UP*top,db*inner+Vector3.UP*top,da*inner+Vector3.UP*top,mat)
  _geometry.quad(da*outer+Vector3.UP*bottom,db*outer+Vector3.UP*bottom,db*outer+Vector3.UP*top,da*outer+Vector3.UP*top,mat)
  _geometry.quad(db*inner+Vector3.UP*bottom,da*inner+Vector3.UP*bottom,da*inner+Vector3.UP*top,db*inner+Vector3.UP*top,mat)
func _make_water(radius: float) -> void:
 var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform float clock=0.;
varying vec3 local_position;
void vertex(){local_position=VERTEX;VERTEX.y+=sin(length(VERTEX.xz)*16.-clock*3.1)*.006+sin(VERTEX.x*7.+VERTEX.z*5.+clock*2.)*.004;}
void fragment(){vec2 p=local_position.xz;float r=length(p);float rings=sin(r*20.-clock*3.8)*.5+.5;float shimmer=pow(max(0.,sin(p.x*13.+clock)*sin(p.y*17.-clock*1.6)),14.);ALBEDO=mix(vec3(.24,.49,.49),vec3(.48,.69,.62),rings*.30)+vec3(.25,.25,.18)*shimmer;METALLIC=.10;ROUGHNESS=.24;}
"""
 water_material=ShaderMaterial.new();water_material.shader=shader
 basin_water=MeshInstance3D.new();basin_water.name="MovingBasinWater";var disc:=CylinderMesh.new();disc.top_radius=radius;disc.bottom_radius=radius;disc.height=.009;disc.radial_segments=64;disc.rings=4;basin_water.mesh=disc;basin_water.position.y=.307;basin_water.material_override=water_material;add_child(basin_water)
 var stream_shader:=Shader.new();stream_shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform float clock=0.;
varying vec3 stream_position;
void vertex(){stream_position=VERTEX;VERTEX.x+=sin(VERTEX.y*16.+clock*5.+VERTEX.z*7.)*.006;VERTEX.z+=cos(VERTEX.y*12.+clock*4.)*.006;}
void fragment(){float dash=sin(stream_position.y*43.+clock*9.+stream_position.x*8.);ALBEDO=mix(vec3(.40,.66,.65),vec3(.82,.91,.80),smoothstep(.35,.98,dash));ROUGHNESS=.18;METALLIC=.07;}
"""
 stream_material=ShaderMaterial.new();stream_material.shader=stream_shader
 var streams=Detail.new();streams.name="SixFallingWaterArcs";add_child(streams)
 for i in 6:
  var angle: float=TAU*i/6+.22;var direction:=Vector3(cos(angle),0,sin(angle));var points: Array[Vector3]=[]
  for j in 13:
   var t: float=j/12.0
   points.append(direction*lerpf(.19,1.58,t)+Vector3.UP*(lerpf(.98,.32,t)+sin(t*PI)*.43))
  streams.tube(points,.024,stream_material,.72)
  var ring:=MeshInstance3D.new();ring.name="LandingRipple"+str(i);var torus:=TorusMesh.new();torus.inner_radius=.105;torus.outer_radius=.12;torus.rings=20;torus.ring_segments=4;ring.mesh=torus;ring.position=direction*1.58+Vector3.UP*.326;splash_rings.append(ring);add_child(ring)
 # Three narrow scalloped overflow ribbons catch light independently of the jets.
 for i in 18:
  var angle: float=i*TAU/18;var next: float=(i+.65)*TAU/18
  var da:=Vector3(cos(angle),0,sin(angle));var db:=Vector3(cos(next),0,sin(next))
  streams.quad(da*.61+Vector3.UP*.866,db*.61+Vector3.UP*.866,db*.85+Vector3.UP*.45,da*.85+Vector3.UP*.45,stream_material)
 var source_jet: Array[Vector3]=[Vector3(0,1.14,0),Vector3(.005,1.29,.003),Vector3(.02,1.34,0)]
 streams.tube(source_jet,.033,stream_material,.22)
 streams.finish();geometry_count+=streams.count
 var ripple_shader:=Shader.new();ripple_shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float clock=0.;
void fragment(){ALBEDO=vec3(.72,.83,.71)*(.84+.16*sin(clock*4.));}
"""
 ripple_material=ShaderMaterial.new();ripple_material.shader=ripple_shader
 for ring in splash_rings:ring.material_override=ripple_material
func tick(delta: float,_camera: Camera3D,clock: float) -> void:
 water_time=clock;water_phase=fposmod(clock,TAU)
 water_material.set_shader_parameter("clock",clock)
 stream_material.set_shader_parameter("clock",clock)
 ripple_material.set_shader_parameter("clock",clock)
 for i in splash_rings.size():
  var growth: float=.45+fposmod(clock*1.1+i*.22,1.0)*2.0
  splash_rings[i].scale=Vector3(growth,1,growth)
