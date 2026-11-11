extends RefCounted
## Per-target debuff, independent of the wielder and equipment lifecycle.
const MAX_STACKS:=5
const PER_STACK:=.10
const DURATION:=10.0
const BROKEN_MULTIPLIER:=1.10
var stacks:=0
var remaining:=.0
func add(amount: int = 1, fill: bool = false) -> void:
 stacks=MAX_STACKS if fill else mini(MAX_STACKS,stacks+amount);remaining=DURATION
func advance(delta: float) -> void:
 if not is_finite(delta) or delta<=0:return
 remaining=maxf(0,remaining-delta)
 if remaining<=0:clear()
func clear() -> void:
 stacks=0;remaining=0
func fraction() -> float:return stacks*PER_STACK if remaining>0 else 0.0
func broken() -> bool:return stacks==MAX_STACKS and remaining>0
func physical_multiplier() -> float:return BROKEN_MULTIPLIER if broken() else 1.0
