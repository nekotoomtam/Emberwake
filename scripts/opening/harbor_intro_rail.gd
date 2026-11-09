extends RefCounted
## One continuous dolly. Equal travelled distance gives even motion through
## the authored locations; only the opening and coffee landing ease to rest.
const Plaza=preload("res://scripts/opening/harbor_plaza_profile.gd")
const DURATION:=28.0
const EASE_IN:=1.5
const EASE_OUT:=3.0
var travel: Curve3D
var attention: Curve3D
func _init() -> void:
 travel=_curve(PackedVector3Array([
  Vector3(62,11.45,-13),Vector3(47,15,-9),Vector3(28,24,-3),
  Vector3(9,28,4),Vector3(-10,23,7),Vector3(-28,15,8),Plaza.CAFE_CAMERA]))
 attention=_curve(PackedVector3Array([
  Vector3(88,3.45,-39),Vector3(57,4,-38),Vector3(18,4,-42),
  Vector3(-13,5,-78),Vector3(-52,5,-110),Vector3(-72,4,-87),
  Vector3(-58,2.5,-46),Plaza.CAFE_LOOK]))
func _curve(points: PackedVector3Array) -> Curve3D:
 var curve:=Curve3D.new();curve.bake_interval=.05
 for index in points.size():
  var previous: Vector3=points[maxi(0,index-1)]
  var next: Vector3=points[mini(points.size()-1,index+1)]
  var tangent: Vector3=(next-previous)*.16
  curve.add_point(points[index],-tangent,tangent)
 return curve
func progress(seconds: float) -> float:
 var time: float=clampf(seconds,0,DURATION)
 var total: float=DURATION-(EASE_IN+EASE_OUT)*.5
 var distance: float=time-EASE_IN*.5
 if time<EASE_IN:
  var u: float=time/EASE_IN
  distance=EASE_IN*(u*u*u-.5*u*u*u*u)
 elif time>DURATION-EASE_OUT:
  var u: float=(DURATION-time)/EASE_OUT
  distance=total-EASE_OUT*(u*u*u-.5*u*u*u*u)
 return clampf(distance/total,0,1)
func apply(camera: Camera3D,seconds: float) -> void:
 var u: float=progress(seconds)
 var at: Vector3=travel.sample_baked(travel.get_baked_length()*u,true)
 var target: Vector3=attention.sample_baked(attention.get_baked_length()*u,true)
 camera.transform=Transform3D(Basis.looking_at(target-at),at)
 # A restrained lens push into town, then a continuous return to the exact
 # existing cafe lens. Position carries the shot rather than a zoom jump.
 camera.fov=lerpf(50,43,smoothstep(.08,.43,u))+5*smoothstep(.65,1,u)
 if seconds>=DURATION:
  camera.transform=Transform3D(Basis.looking_at(Plaza.CAFE_LOOK-Plaza.CAFE_CAMERA),Plaza.CAFE_CAMERA)
  camera.fov=Plaza.CAFE_FOV
