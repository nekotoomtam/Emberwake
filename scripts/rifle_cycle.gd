extends RefCounted
## Actual loaded rounds, mechanical readiness and presentation are separate.
var capacity:=5
var _queue: Array[Dictionary] = [{}, {}, {}, {}, {}]
var rounds: int:
 get: return _queue.size()
 set(value):
  var target := clampi(value, 0, capacity)
  while _queue.size() > target: _queue.pop_back()
  while _queue.size() < target: _queue.append({})
var reload_duration:=2.65
var reloading:=false
var elapsed:=.0
var phase:=""
var phase_elapsed:=.0
var needs_bolt:=false
var bolt_active:=false
var bolt_elapsed:=.0
var bolt_duration:=.66
var spent_case:=false
var cycle_debt:=.0
var close_time:=.2
var rapid_fire_left := 0.0
var events: Array[String]=[]
func configure(_definition: Dictionary) -> bool:reset();return true
func configure_shot(aimed: bool, timing_scale: float = 1.0) -> void:bolt_duration=(.92 if aimed else .66)*timing_scale
func can_fire() -> bool:return rounds>0 and not reloading and not needs_bolt and not bolt_active
func prepare_round(round_id: String, count: int = 1) -> bool:
 if round_id.is_empty() or not can_fire() or count < 1 or rounds < count:return false
 # All rounds from this activation share its first-shot cooldown flag.
 var batch := {"id": round_id, "fired": false}
 for i in count:
  _queue.pop_back()
 for i in count:
  _queue.push_front(batch)
 return true

func refill_now(count: int) -> bool:
 if count < 1 or rounds + count > capacity: return false
 rounds += count
 cancel_reload()
 _eject()
 needs_bolt = false
 return true

func next_round() -> Dictionary:
 return {} if _queue.is_empty() else _queue[0]

func round_ids() -> Array[String]:
 var ids: Array[String] = []
 for round_data in _queue: ids.append(round_data.get("id", ""))
 return ids

func consume(skip_bolt: bool = false) -> bool:
 if not can_fire():return false
 var fired_round: Dictionary = _queue.pop_front()
 if not fired_round.is_empty(): fired_round.fired = true
 needs_bolt=true;bolt_elapsed=0;spent_case=true
 if skip_bolt:
  _eject()
  needs_bolt = false
 return true
func start_bolt() -> bool:
 if not needs_bolt or reloading:return false
 bolt_active=true;bolt_elapsed=0;return true
func _eject() -> void:
 if spent_case:events.append("eject");spent_case=false
func sync_bolt(clock: float) -> void:
 if not needs_bolt or reloading:return
 bolt_elapsed=clampf(clock,0,bolt_duration)
 if bolt_elapsed>=bolt_duration*.45:_eject()
 if bolt_elapsed>=bolt_duration-.00000001:
  needs_bolt=false;bolt_active=false;events.append("ready")
func tick_bolt(delta: float) -> void:
 if bolt_active and is_finite(delta) and delta>0:sync_bolt(bolt_elapsed+delta)
func cancel_bolt() -> void:bolt_active=false;bolt_elapsed=0
func start_reload() -> bool:
 if reloading or rounds>=capacity:return false
 cancel_bolt();reloading=true;elapsed=0;phase="open";phase_elapsed=0
 reload_duration=.4+(capacity-rounds)*.45;cycle_debt=bolt_duration if needs_bolt else 0.0
 return true
func close_reload() -> bool:
 if not reloading or rounds<=0:return false
 if phase!="close":_start_close()
 return true
func tick(delta: float) -> bool:
 if not reloading or not is_finite(delta) or delta<=0:return false
 var left:=delta
 while left>.00000001 and reloading:
  var duration:=.45 if phase=="insert" else (close_time if phase=="close" else .2)
  var step:=minf(left,maxf(0,duration-phase_elapsed))
  phase_elapsed+=step;elapsed+=step;cycle_debt=maxf(0,cycle_debt-step);left=maxf(0,left-step)
  if phase_elapsed<duration-.00000001:break
  phase_elapsed=0
  if phase=="open":
   _eject();needs_bolt=true;phase="insert"
  elif phase=="insert":
   rounds=mini(capacity,rounds+1);events.append("insert")
   if rounds>=capacity:_start_close()
  else:
   reloading=false;phase="";needs_bolt=false;bolt_active=false;spent_case=false;events.append("ready");return true
 return false
func progress() -> float:
 return clampf(elapsed/reload_duration,0,1) if reloading else 0.0
func action_progress() -> float:
 return clampf(phase_elapsed/(.45 if phase=="insert" else .2),0,1)
func cancel_reload() -> void:
 if reloading:needs_bolt=true
 reloading=false;phase="";phase_elapsed=0;elapsed=0;cancel_bolt()
func reset() -> void:
 _queue.clear()
 rounds=capacity;reloading=false;elapsed=0;phase="";phase_elapsed=0
 needs_bolt=false;bolt_active=false;bolt_elapsed=0;bolt_duration=.66;spent_case=false;events.clear()
 rapid_fire_left = 0.0

func _start_close() -> void:
 phase="close";phase_elapsed=0;close_time=maxf(.2,cycle_debt)

func next_boundary() -> float:return maxf(.00000001,(.45 if phase=="insert" else (close_time if phase=="close" else .2))-phase_elapsed)
