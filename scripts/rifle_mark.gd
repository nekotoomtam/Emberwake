extends RefCounted
const DURATION:=10.0
const MAX_STACKS:=3
var stacks:=0
var remaining:=.0
func multiplier() -> float:return 1+.1*stacks if remaining>0 else 1.0
func add() -> void:stacks=mini(MAX_STACKS,stacks+1);remaining=DURATION
func advance(delta: float) -> void:
 if not is_finite(delta) or delta<=0:return
 remaining=maxf(0,remaining-delta)
 if remaining<=0:clear()
func clear() -> void:stacks=0;remaining=0
