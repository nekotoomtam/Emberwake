extends RefCounted
const DURATION:=5.0
const BONUS:=.10
var stacks:=0
var remaining:=.0
func multiplier() -> float:return 1.0+BONUS if stacks>0 else 1.0
func add() -> bool:
 stacks=1
 remaining=DURATION
 return true
func advance(delta: float) -> void:
 if not is_finite(delta) or delta<=0:return
 remaining=maxf(0,remaining-delta)
 if remaining<=0:clear()
func clear() -> void:stacks=0;remaining=0
