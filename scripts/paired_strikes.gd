extends RefCounted
## One accepted click owns both hands; only the final hand advances the combo.
var active := false
var stage := 0
var cursor := 0
var items: Array[String] = []
var generation := 0

func begin(index: int, ids: Array) -> bool:
	if active or index not in [0,1,2] or ids.size()!=2: return false
	items.assign(ids)
	stage=index;cursor=0;active=true;generation+=1
	return true

func next_hand() -> String:
	if not active or cursor!=0: return ""
	cursor=1
	return items[1]

func cancel() -> void:
	active=false;items.clear();cursor=0;generation+=1

func handoff_time(definition: Dictionary) -> float:
	return float(definition.windup)+float(definition.active)+minf(.04,float(definition.recovery))
