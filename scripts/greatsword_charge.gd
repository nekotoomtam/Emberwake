extends RefCounted
## Base charge timing/specs; item attack speed scales the caller's simulation clock.
const MID_TIME:=.40
const FULL_TIME:=1.0
const DAMAGE=[[18.0,27.0,42.0],[20.0,30.0,46.0],[24.0,36.0,55.0]]
const STAGGER=[.2,.3,.4]
var charging:=false
var elapsed:=.0
var selected:=1
var finisher_level:=1
var finisher_valid:=false
var slam_level:=1
func begin() -> void:charging=true;elapsed=0;selected=1
func reset() -> void:
 charging=false;elapsed=0;selected=1;slam_level=1;clear_finisher()
func advance(delta: float) -> void:
 if charging and is_finite(delta) and delta>0:elapsed=minf(FULL_TIME,elapsed+delta)
func level() -> int:
 if not charging:return selected
 return 3 if elapsed>=FULL_TIME-.00000001 else (2 if elapsed>=MID_TIME-.00000001 else 1)
func release() -> bool:
 if not charging:return false
 selected=level();charging=false;return true
func definition(base: Dictionary,index: int) -> Dictionary:
 var result:=base.duplicate(true)
 if index==2:
  result.damage=DAMAGE[2][slam_level-1]
  result.stagger=STAGGER[slam_level-1]
  result.charge_level=slam_level
  return result
 var tier:=level()
 result.arc=float(base.arc)*tier/3.0
 result.charge_level=tier
 result.damage=DAMAGE[index][tier-1]
 if tier==1:
  result.windup=.10;result.active=.09;result.recovery=.18
 elif tier==2:
  result.windup=.13;result.active=.10;result.recovery=.21
 return result

func clear_finisher() -> void:finisher_level=1;finisher_valid=false
func prime_finisher(level: int) -> void:
 finisher_level=clampi(level,1,3);finisher_valid=true
func begin_slam() -> void:
 charging=false;elapsed=0;slam_level=finisher_level if finisher_valid else 1;selected=slam_level
 clear_finisher()
