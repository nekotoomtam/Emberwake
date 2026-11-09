extends RefCounted
## Base action costs, separate from weapon timing/damage and future modifiers.
const COSTS={"sword":[8.0,8.0,12.0],"greatsword":[14.0,14.0,20.0],"mace":[12.0,8.0,18.0],"staff":[14.0],"pistol":[3.0],"rifle":[10.0]}
const AIM_COST:=1.3
var delay_left:=.0
var flash:=.0
var rate:=.0
func cost(family: String,stage: int,aimed: bool=false) -> float:
 var values: Array=COSTS.get(family,[])
 if values.is_empty():return 0
 return float(values[clampi(stage,0,values.size()-1)])*((1.5 if family=="rifle" else AIM_COST) if aimed and family in ["pistol","rifle"] else 1.0)
func reset() -> void:delay_left=0;flash=0;rate=0
func recover(current: float,delta: float,stats,busy: bool,half_rate: bool) -> float:
 flash=maxf(0,flash-delta);rate=0
 if busy:
  delay_left=stats.value("stamina_delay");return minf(current,stats.value("max_stamina"))
 var usable:=maxf(0,delta-delay_left);delay_left=maxf(0,delay_left-delta)
 if usable>0:rate=stats.value("stamina_regen")*(.5 if half_rate else 1.0)
 return minf(stats.value("max_stamina"),current+rate*usable)
