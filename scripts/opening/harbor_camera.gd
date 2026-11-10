extends Camera3D
const PlazaProfile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const IntroRail=preload("res://scripts/opening/harbor_intro_rail.gd")
const WATER_HANDOFF:=6.0
const RAIL_OVERLAP:=3.0
const OPEN_WATER_FOV:=45.0
const OPEN_WATER_EYE:=Vector3(-37,11.8,5)
const OPEN_WATER_AIM:=Vector3(4,3.9,10)
var view_id: StringName=&"lighthouse"
var flying:=false
var intro_duration:=IntroRail.DURATION
var _intro_rail=IntroRail.new()
var _from:=Transform3D.IDENTITY
var _to:=Transform3D.IDENTITY
var _age:=0.0
var _duration:=0.0
var _from_fov:=42.0
var _target_fov:=42.0
var _water_lead:=0.0
func _ready() -> void:
 projection=Camera3D.PROJECTION_PERSPECTIVE;near=.1;far=5000;current=true;set_view(&"lighthouse",0)
func set_view(id: StringName,seconds: float=.8) -> void:
 flying=false
 view_id=id;_from=transform;_from_fov=fov;_age=0;_duration=seconds
 var at: Vector3=PlazaProfile.CAFE_CAMERA;var target: Vector3=PlazaProfile.CAFE_LOOK;_target_fov=PlazaProfile.CAFE_FOV
 if id==&"lighthouse":at=Vector3(62,11.45,-13);target=Vector3(88,3.45,-39);_target_fov=50
 if id==&"market":at=PlazaProfile.FOUNTAIN+Vector3(3,11,14);target=PlazaProfile.FOUNTAIN+Vector3(0,1,-2);_target_fov=52
 if id==&"port":at=Vector3(17,26,5);target=Vector3(-12,2,-82);_target_fov=54
 if id==&"quay":at=Vector3(15,11,19);target=Vector3(7,3,-5);_target_fov=47
 if id==&"boarding":at=Vector3(8.95,3.65,-3.6);target=Vector3(8.75,3.45,-9.15);_target_fov=52
 _to=Transform3D(Basis.looking_at(target-at),at)
 if seconds<=0:transform=_to;fov=_target_fov
func frame_open_water(ship_at: Vector3) -> void:
 var eye:=ship_at+OPEN_WATER_EYE
 var aim:=ship_at+OPEN_WATER_AIM
 transform=Transform3D(Basis.looking_at(aim-eye),eye)
 fov=OPEN_WATER_FOV

func start_flyin(from_open_water: bool=false) -> void:
 _water_lead=WATER_HANDOFF if from_open_water else 0.0
 intro_duration=IntroRail.DURATION+(_water_lead-RAIL_OVERLAP if from_open_water else 0.0)
 set_view(&"cafe",intro_duration);flying=true;view_id=&"flyin"
 if not from_open_water:_intro_rail.apply(self,0)
func follow_actor(at: Vector3,delta: float) -> void:
 flying=false;_duration=0
 var desired: Vector3=at+Vector3(2.9,7.8,10.2)
 var facing:=Basis.looking_at(Vector3(0,-6.1,-13.4))
 transform=transform.interpolate_with(Transform3D(facing,desired),1-exp(-delta*2.4))

func view_settled() -> bool:
 return not flying and _age>=_duration

func tick(delta: float) -> void:
 if _duration<=0:return
 if flying:
  _age=minf(intro_duration,_age+maxf(0,delta))
  var rail_delay: float=_water_lead-RAIL_OVERLAP if _water_lead>0.0 else 0.0
  _intro_rail.apply(self,maxf(0.0,_age-rail_delay))
  if _age<_water_lead:
   var handoff:=smoothstep(0.0,_water_lead,_age)
   transform=_from.interpolate_with(transform,handoff)
   fov=lerpf(_from_fov,fov,handoff)
  if _age>=intro_duration:flying=false;view_id=&"cafe";_duration=0
  return
 _age+=delta;var t:=smoothstep(0,_duration,_age);transform=_from.interpolate_with(_to,t);fov=lerpf(_from_fov,_target_fov,t)
