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
 var lateral := outward
 if facing in ["left", "right"]:
  lateral = -1.0 if facing == "left" else 1.0
  depth = .13 if front_hand(facing, hand) else -.48
 var direction := (camera.global_basis.x*lateral+toward*depth).normalized()
 var pose := {"phase":"idle","angle":atan2(direction.z,direction.x),"grip_angle":atan2(direction.z,direction.x),"radius":.0,"pitch":.0,"grip_height":.0,"body_lean":.0,"trail":false,"progress":.0,"stance_managed":true}
 match family:
  "sword":
   pose.blade_length=1.9;pose.pitch=.46 if facing in ["front","back"] else (.37 if front_hand(facing,hand) else -.12)
  "mace":
   pose.blade_length=1.9;pose.pitch=.72 if facing in ["front","back"] else (.68 if front_hand(facing,hand) else .19)
  "pistol":pose.blade_length=.72;pose.pitch=-.42 if facing in ["front","back"] else (-.22 if front_hand(facing,hand) else -.46)
  "shield":pose.blade_length=.70
 return pose
static func wrist(shoulder: Vector3,camera: Camera3D,facing: String,hand: int) -> Vector3:
 if facing in ["front", "back"]:
  return shoulder + camera.global_basis.x * (side(facing,hand) * .17) - camera.global_basis.y * .20
 var forward := -1.0 if facing == "left" else 1.0
 var near := front_hand(facing, hand)
 return shoulder + camera.global_basis.x * forward * (.17 if near else .34) - camera.global_basis.y * (.19 if near else .37)
