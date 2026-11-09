extends RefCounted
## Presentation state only; detection remains owned by SightSense.
const FLASH_TIME:=.20
var states: Dictionary={}
func reset() -> void:states.clear()
func frequency(strength: float) -> float:return lerpf(1.0,3.0,clampf(strength,0,1))
func width(strength: float) -> float:return lerpf(5.0,9.0,clampf(strength,0,1))
func update(detected: Dictionary,_revealed: Dictionary,delta: float) -> void:
 delta=maxf(0,delta)
 for bin in states.keys():
  if not detected.has(bin):states.erase(bin)
 for bin in detected:
  var strength:=clampf(float(detected[bin]),0,1)
  if not states.has(bin):states[bin]={"strength":strength,"alpha":1.0,"flash":FLASH_TIME,"phase":0.0}
  else:
   var state: Dictionary=states[bin]
   state.strength=strength;state.alpha=1.0;state.flash=maxf(0,state.flash-delta)
   state.phase=fmod(state.phase+delta*frequency(strength),1.0)
