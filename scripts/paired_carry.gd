extends RefCounted
## Screen-space resting guard; committed attack roots remain in DualHandVisual.origin.
static func side(facing: String,hand: int) -> float:
 return (-1.0 if facing=="front" else 1.0)*(1 if hand==0 else -1)
static func front_hand(facing: String,hand: int) -> bool:
 return facing=="front" or (facing=="right" and hand==0) or (facing=="left" and hand==1)
static func rest(family: String,facing: String,hand: int,camera: Camera3D) -> Dictionary:
 var outward: float=side(facing,hand)
 var depth := .35 if facing=="front" else (-.35 if facing=="back" else .0)
 var toward := Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
 var direction := (camera.global_basis.x*outward+toward*depth).normalized()
 var pose := {"phase":"idle","angle":atan2(direction.z,direction.x),"grip_angle":atan2(direction.z,direction.x),"radius":.0,"pitch":.0,"grip_height":.0,"body_lean":.0,"trail":false,"progress":.0,"stance_managed":true}
 match family:
  "sword":
   pose.blade_length=1.9;pose.pitch=.75 if facing=="front" else (.55 if facing=="back" else (.35 if front_hand(facing,hand) else .60))
  "mace":
   pose.blade_length=1.9;pose.pitch=.95 if facing=="front" else (.80 if facing=="back" else (.90 if front_hand(facing,hand) else 1.0))
  "pistol":pose.blade_length=.72;pose.pitch=-.50 if facing in ["front","back"] else -.25
 return pose
static func wrist(shoulder: Vector3,camera: Camera3D,facing: String,hand: int) -> Vector3:
 return shoulder+camera.global_basis.x*(side(facing,hand)*.14)-camera.global_basis.y*.18
