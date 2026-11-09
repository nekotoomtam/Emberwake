extends RefCounted
## Presentation of the existing0.24s dodge, never a second movement controller.
const DURATION := .24
static func classify(aim: Vector3,travel: Vector3) -> String:
 var forward := Vector3(aim.x,0,aim.z).normalized()
 var right := Vector3(-forward.z,0,forward.x)
 var along := forward.dot(travel)
 var across := right.dot(travel)
 if absf(along)>=absf(across):return "front" if along>=0 else "back"
 return "right" if across>0 else "left"
static func sample(left: float,aim: Vector3,travel: Vector3,camera: Camera3D) -> Dictionary:
 if left<=0:return {}
 var p := clampf(1-left/DURATION,0,1)
 var amount := sin(PI*p)
 var x := camera.global_basis.x.dot(travel)
 var kind := classify(aim,travel)
 return {"kind":kind,"progress":p,"amount":amount,"frame":mini(5,int(p*6)),"lean":-x*amount*(.30 if kind in ["left","right"] else (.22 if kind=="front" else .12)),"drop":amount*(-.10 if kind=="back" else -.14),"squash":amount*.045}
static func tuck(pose: Dictionary,dash: Dictionary) -> Dictionary:
 var result := pose.duplicate(true)
 if dash.is_empty():return result
 var amount: float=dash.amount
 result.pitch=float(result.get("pitch",0))+.24*amount
 result.phase="idle";result.trail=false
 return result
static func wrist(shoulder: Vector3,camera: Camera3D,side: float,amount: float) -> Vector3:
 return shoulder+camera.global_basis.x*side*(.14-.07*amount)-camera.global_basis.y*(.18-.08*amount)
