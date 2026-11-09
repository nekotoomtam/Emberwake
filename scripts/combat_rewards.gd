extends RefCounted
## Base combat windows; independent of future weapon and skill modifiers.
const CHAIN_WINDOW:=.7
const COUNTER_WINDOW:=.7
const DODGE_IFRAMES:=.16
const DODGE_SPEED:=10.5
const DODGE_RECHARGE:=.42
const DODGE_COST:=30.0
const PERFECT_WINDOW:=.08
const PERFECT_REFUND:=15.0
var counter_left:=.0
var combo_left:=.0
var dodge_age:=INF
var dodge_origin:=Vector3.ZERO
var refunded:=false
var perfects:=0
func reset() -> void:
 counter_left=0;combo_left=0;dodge_age=INF;refunded=false;perfects=0
func advance(delta: float) -> void:
 counter_left=maxf(0,counter_left-delta);combo_left=maxf(0,combo_left-delta)
 if is_finite(dodge_age):dodge_age+=delta
func grant_counter() -> void:counter_left=COUNTER_WINDOW
func clear_chain() -> void:counter_left=0;combo_left=0
func begin_dodge(origin: Vector3) -> void:
 clear_chain();dodge_origin=origin;dodge_age=0;refunded=false
func invulnerable() -> bool:return dodge_age<DODGE_IFRAMES-.00000001
func can_perfect() -> bool:return not refunded and dodge_age<=PERFECT_WINDOW+.00000001
func reward() -> bool:
 if not can_perfect():return false
 refunded=true;perfects+=1;return true
