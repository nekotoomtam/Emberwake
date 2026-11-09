extends Node3D
const Profile=preload("res://scripts/wreck_shore_profile.gd")
const SURF_PERIOD:=6.0
var mesh:=ImmediateMesh.new()
var clock:=0.0
var materials: Dictionary={}
var debris: Array=[]
var sound: AudioStreamPlayer
func _ready() -> void:
 var node:=MeshInstance3D.new();node.mesh=mesh
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.vertex_color_use_as_albedo=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
 for i in 6:
  var part=preload("res://scripts/village_detail.gd").new();add_child(part)
  part.box(Vector3.ZERO,Vector3(.75 if i<4 else .5,.08 if i<4 else .45,.15 if i<4 else .5),materials.oldwood);part.finish();debris.append(part)
 if DisplayServer.get_name()!="headless":
  sound=AudioStreamPlayer.new();sound.stream=_surf_sound();sound.volume_db=-24;add_child(sound);sound.play()
func _surf_sound() -> AudioStreamWAV:
 var rate:=11025;var count:=rate*6;var data:=PackedByteArray();data.resize(count*2)
 var random:=RandomNumberGenerator.new();random.seed=7301;var low:=0.0
 for i in count:
  var t: float=float(i)/rate;low=lerpf(low,random.randf_range(-1,1),.08)
  var envelope: float=.28+.55*pow(sin(t*PI/6),2)
  var value: float=(low*.8+random.randf_range(-1,1)*.055)*envelope
  var edge: float=minf(1,minf(t,6-t)/.08)
  data.encode_s16(i*2,int(clampf(value*edge,-1,1)*22000))
 var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=data;stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=count;return stream
func _v(point: Vector3,color: Color) -> void:mesh.surface_set_color(color);mesh.surface_add_vertex(point)
func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
 for p in [a,b,c,a,c,d]:_v(p,color)
func update_wave(delta: float,age: float,landing: Vector3,origin: Vector3) -> void:
 clock+=delta;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var progress:=clampf(age/1.8,0,1)
 var front: float=lerpf(origin.z+.6,landing.z-.3,1-pow(1-progress,2))
 if age>1.8:front=lerpf(landing.z-.3,origin.z+1,clampf((age-1.8)/1.5,0,1))
 var alpha: float=clampf(1-maxf(0,age-2.2)/1.2,0,1)
 if alpha>0:
  for i in 48:
   var x: float=landing.x-7+i*.3;var next: float=x+.3
   var za: float=front+sin(x*.8+clock*.8)*.25+pow(absf(x-landing.x)/7,2)*.6;var zb: float=front+sin(next*.8+clock*.8)*.25+pow(absf(next-landing.x)/7,2)*.6
   var edge: float=pow(sin(PI*(i+.5)/48),.8)
   var a:=Vector3(x,.045,za);var b:=Vector3(next,.045,zb);var c:=Vector3(next,.045,zb+2);var d:=Vector3(x,.045,za+2)
   var near:=Color(.23,.43,.46,.35*alpha*edge);var far:=Color(.23,.43,.46,0)
   _v(a,near);_v(b,near);_v(c,far);_v(a,near);_v(c,far);_v(d,far)
   if i%5!=0:_quad(Vector3(x,.055,za),Vector3(next-.04,.055,zb),Vector3(next-.04,.055,zb+.055),Vector3(x,.055,za+.07),Color(.7,.85,.81,.8*alpha*edge))
   if i%3==0:_quad(Vector3(x,.057,za+.26),Vector3(next-.12,.057,zb+.28),Vector3(next-.12,.057,zb+.31),Vector3(x,.057,za+.30),Color(.62,.76,.73,.35*alpha*edge))
 # Broad run-up and backwash loop for the whole coast, independent of capped intro age.
 var fade:=smoothstep(3.0,4.2,age)
 if fade>0:
  for train in 2:
   for i in 132:
    var x: float=-20+i*.8;var next: float=x+.8
    var za:=surf_front(x,clock,train);var zb:=surf_front(next,clock,train)
    var reach:=_surf_reach(x,clock,train);var strength: float=fade*(1.0 if train==0 else .45)
    var y: float=.029+train*.004;var width: float=1.9 if train==0 else 1.3
    var near:=Color(.24,.44,.46,(.12+.38*reach)*strength);var far:=Color(.24,.44,.46,0)
    var a:=Vector3(x,y,za);var b:=Vector3(next,y,zb);var c:=Vector3(next,y,zb+width);var d:=Vector3(x,y,za+width)
    _v(a,near);_v(b,near);_v(c,far);_v(a,near);_v(c,far);_v(d,far)
    if i%8 not in [0,5]:
     var thickness: float=(.05+.07*reach)*(.85+.25*sin(x*3.1))
     _quad(Vector3(x,y+.008,za),Vector3(next-(.15+.08*sin(x*2)),y+.008,zb),Vector3(next-(.15+.08*sin(x*2)),y+.008,zb+thickness),Vector3(x,y+.008,za+thickness),Color(.65,.81,.78,(.23+.53*reach)*strength))
    if i%3==0:_quad(Vector3(x+.14,y+.01,za+.32),Vector3(next-.12,y+.01,zb+.34),Vector3(next-.12,y+.01,zb+.39),Vector3(x+.14,y+.01,za+.37),Color(.59,.75,.73,.30*strength*reach))
 mesh.surface_end()
 for i in debris.size():
  var p: Vector3=origin.lerp(landing,clampf(age/2.0,0,1))
  debris[i].position=Vector3(p.x+(i-2.5)*.9,.08,p.z+1.3+sin(i)*.7)
  debris[i].rotation=Vector3(sin(clock*2+i)*.04,i*.8,sin(clock+i)*.025)
func _surf_reach(x: float,time_: float,train: int) -> float:
 var phase: float=fposmod(time_+train*SURF_PERIOD*.5+x*.018,SURF_PERIOD)/SURF_PERIOD
 return smoothstep(0,.42,phase) if phase<=.42 else 1.0-smoothstep(.42,1.0,phase)
func surf_front(x: float,time_: float,train: int=0) -> float:
 var runup: float=3.2 if train==0 else 1.1
 return Profile.sea_z(x)+.9-runup*_surf_reach(x,time_,train)+sin(x*.9+time_*TAU/SURF_PERIOD)*.24+sin(x*2.4-time_*TAU*2/SURF_PERIOD)*.15
func set_audio(active: bool) -> void:
 if is_instance_valid(sound):sound.stream_paused=not active

func _exit_tree() -> void:
 if is_instance_valid(sound):sound.stop();sound.stream=null
