extends RefCounted
## Prepared ammunition and cast concentration are separate; no automatic release.
const MAX_UNITS:=5
const LOAD_TIME:=.45
const CAST_FULL:=.90
const CAST_ORBS := 3
const SWITCH_TIME := .4
const SWITCH_CHANGE_AT := .16
const ELEMENTS := ["fire", "ice", "lightning"]
const NEUTRAL := "neutral"
const FOCUS_DURATION := 10.0
const ELEMENT_NAMES := {"fire":"ไฟ", "ice":"น้ำแข็ง", "lightning":"สายฟ้า"}
const ELEMENT_COLORS := {"fire":Color("#ff9349"), "ice":Color("#73dcff"), "lightning":Color("#ba9aff"), NEUTRAL:Color("#a285c4")}
signal orb_stored(slot: int, element: String)
signal orbs_spent(previous: Array[String], removed: Array[int])
signal orbs_prepended(previous: Array[String], count: int)

var element := "fire"
var slots: Array[String] = ["", "", "", "", ""]
var units: int:
 get: return MAX_UNITS - slots.count("")
 set(value):
  var target := clampi(value, 0, MAX_UNITS)
  while units < target: slots[slots.find("")] = element
  for index in range(MAX_UNITS - 1, -1, -1):
   if units <= target: break
   slots[index] = ""
var key:=""
var stores: Dictionary={}
var loading:=false
var casting:=false
var load_elapsed:=.0
var cast_elapsed:=.0
var cast_time := CAST_FULL
var cast_orbs := CAST_ORBS
var cast_element := "fire"
var empty_flash:=.0
var focus_left := 0.0
var switch_left := 0.0
var switching := false
var _next_element := ""
func bind(item: String) -> void:
 if item==key:return
 if key!="":stores[key] = {"slots": slots.duplicate(), "element": element}
 cancel_actions();key=item
 switch_left = 0.0
 var saved: Dictionary = stores.get(item, {})
 slots.fill("")
 if saved.has("slots"): slots.assign(saved.slots)
 element = saved.get("element", "fire")
func reset() -> void:
 cancel_actions();stores.clear();slots.fill("");element="fire";key="";empty_flash=0;switch_left=0.0
 focus_left = 0.0
func cycle_element() -> bool:
 if switch_left > 0.0 or casting: return false
 _next_element = ELEMENTS[(ELEMENTS.find(element) + 1) % ELEMENTS.size()]
 switch_left = SWITCH_TIME
 switching = true
 load_elapsed = 0.0
 return true
func cancel_actions() -> void:
 loading=false;casting=false;load_elapsed=0;cast_elapsed=0
 switching=false;_next_element=""
func begin_load() -> bool:
 if casting or units>=MAX_UNITS:return false
 loading=true;load_elapsed=0;return true
func stop_load() -> void:loading=false;load_elapsed=0
func begin_cast(required: int = CAST_ORBS, duration: float = CAST_FULL, spell_element: String = "fire") -> bool:
 if casting or units < required:return false
 stop_load()
 cast_orbs = required
 cast_time = duration
 cast_element = spell_element
 casting=true;cast_elapsed=0;return true
func cast_ready() -> bool:
 return casting and units >= cast_orbs and cast_elapsed >= cast_time - .00000001
func casting_slots() -> Array[int]:
 var selected: Array[int] = []
 if casting and units >= cast_orbs:
  for i in cast_orbs: selected.append(i)
 return selected

func casting_elements() -> Array[String]:
 var selected: Array[String] = []
 for slot in casting_slots(): selected.append(slots[slot])
 return selected
func spend_orb(orb_element: String) -> bool:
 var slot := slots.find(orb_element)
 if slot < 0: return false
 _remove_orbs([slot])
 return true

func grant_neutral(count: int) -> void:
 for _index in range(mini(count, MAX_UNITS - units)):
  _store_orb(NEUTRAL)

func prepend_neutral(count: int) -> void:
 var added := clampi(count, 0, MAX_UNITS)
 if added == 0: return
 var previous := slots.duplicate()
 slots.fill("")
 for index in range(added):
  slots[index] = NEUTRAL
 var next_slot := added
 for orb_element in previous:
  if next_slot >= MAX_UNITS: break
  if orb_element.is_empty(): continue
  slots[next_slot] = orb_element
  next_slot += 1
 orbs_prepended.emit(previous, added)

func _store_orb(orb_element: String) -> void:
 var slot := slots.find("")
 slots[slot] = orb_element
 orb_stored.emit(slot, orb_element)
func release_cast() -> void:
 var selected: Array[int] = []
 if cast_ready(): selected = casting_slots()
 casting=false;cast_elapsed=0
 _remove_orbs(selected)

func spend_prefix(count: int) -> Array[String]:
 var spent: Array[String] = []
 if units < count: return spent
 var indices: Array[int] = []
 for index in range(count):
  indices.append(index)
  spent.append(slots[index])
 _remove_orbs(indices)
 return spent

func _remove_orbs(removed: Array[int]) -> void:
 if removed.is_empty(): return
 var previous := slots.duplicate()
 slots.fill("")
 var next_slot := 0
 for index in previous.size():
  if previous[index].is_empty() or index in removed: continue
  slots[next_slot] = previous[index]
  next_slot += 1
 orbs_spent.emit(previous, removed)

func advance(delta: float,pay: Callable,rate: float = 1.0) -> int:
 if not is_finite(delta) or delta<=0:return 0
 empty_flash=maxf(0,empty_flash-delta)
 if switch_left>0.0:
  var switch_step:=minf(switch_left,delta)
  switch_left=maxf(0.0,switch_left-delta)
  if switching:
   if not _next_element.is_empty() and SWITCH_TIME-switch_left>=SWITCH_CHANGE_AT-.00000001:
    element=_next_element;_next_element=""
   if switch_left<=.00000001:
    switch_left=0.0;switching=false
   delta-=switch_step
   if delta<=0:return 0
 delta*=rate
 if casting:cast_elapsed=minf(cast_time,cast_elapsed+delta);return 0
 if not loading:return 0
 load_elapsed+=delta
 var gained:=0
 while load_elapsed>=LOAD_TIME-.00000001 and units<MAX_UNITS:
  if not pay.is_valid() or not bool(pay.call()):stop_load();break
  load_elapsed=maxf(0,load_elapsed-LOAD_TIME)
  _store_orb(element)
  gained += 1
 if units>=MAX_UNITS:stop_load()
 return gained
