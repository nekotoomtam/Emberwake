extends RefCounted
## Pistol focus and held-aim cadence; range, damage and reload stay unchanged.
const DURATION:=.25
var progress:=0.0
var stacks:=0
func reset() -> void:progress=0;stacks=0
func advance(delta: float,aiming: bool) -> void:
 if not aiming:progress=0;return
 if not is_finite(delta) or delta<0:return
 progress=minf(1,progress+delta/DURATION)
func amount() -> float:return smoothstep(0,1,progress)
func spread(aimed: bool) -> float:return deg_to_rad(lerpf(8,2.5,amount()) if aimed else 8)

func record_shot() -> void:stacks=mini(5,stacks+1)
func speed_bonus() -> float:return stacks*.05
