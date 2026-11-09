extends RefCounted
## Visual/sight focus only. No influence on the paid shot snapshot or its timers.
const DURATION:=.55
var progress:=.0
func advance(delta: float,aiming: bool) -> void:
 if not is_finite(delta) or delta<=0:return
 progress=move_toward(progress,1.0 if aiming else 0.0,delta/DURATION)
func amount() -> float:return progress*progress*(3-2*progress)
func reset() -> void:progress=0
func half_angle() -> float:return deg_to_rad(lerpf(120,32,amount())*.5)
func sight_multiplier() -> float:return lerpf(1,1.4,amount())
func camera_size() -> float:return lerpf(13.5,13.0,amount())
func lookahead() -> float:return lerpf(.45,4.0,amount())
