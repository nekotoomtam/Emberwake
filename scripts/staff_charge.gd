extends RefCounted
## Prepared ammunition and cast concentration are separate; no automatic release.
const MAX_UNITS:=3
const LOAD_TIME:=.45
const CAST_MID:=.40
const CAST_FULL:=.90
var units:=0
var key:=""
var stores: Dictionary={}
var loading:=false
var casting:=false
var load_elapsed:=.0
var cast_elapsed:=.0
var empty_flash:=.0
func bind(item: String) -> void:
 if item==key:return
 if key!="":stores[key]=units
 cancel_actions();key=item;units=int(stores.get(item,0)) if item!="" else 0
func reset() -> void:
 cancel_actions();stores.clear();units=0;key="";empty_flash=0
func cancel_actions() -> void:
 loading=false;casting=false;load_elapsed=0;cast_elapsed=0
func begin_load() -> bool:
 if casting or units>=MAX_UNITS:return false
 loading=true;load_elapsed=0;return true
func stop_load() -> void:loading=false;load_elapsed=0
func begin_cast() -> bool:
 stop_load()
 if units<=0:empty_flash=.3;return false
 if casting:return false
 casting=true;cast_elapsed=0;return true
func level() -> int:
 if not casting or units<=0:return 0
 return mini(units,3 if cast_elapsed>=CAST_FULL-.00000001 else (2 if cast_elapsed>=CAST_MID-.00000001 else 1))
func release_cast() -> int:
 var tier:=level()
 casting=false;cast_elapsed=0
 units=maxi(0,units-tier)
 return tier
func advance(delta: float,pay: Callable) -> int:
 if not is_finite(delta) or delta<=0:return 0
 empty_flash=maxf(0,empty_flash-delta)
 if casting:cast_elapsed=minf(CAST_FULL,cast_elapsed+delta);return 0
 if not loading:return 0
 load_elapsed+=delta
 var gained:=0
 while load_elapsed>=LOAD_TIME-.00000001 and units<MAX_UNITS:
  if not pay.is_valid() or not bool(pay.call()):stop_load();break
  load_elapsed=maxf(0,load_elapsed-LOAD_TIME);units+=1;gained+=1
 if units>=MAX_UNITS:stop_load()
 return gained
