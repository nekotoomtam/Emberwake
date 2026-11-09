extends RefCounted
## Reusable per-weapon magazine. The caller decides when to fire and reload,
## and freezes reload time by not calling tick while gameplay is paused.

const DEFAULT_CAPACITY := 10
const DEFAULT_RELOAD_DURATION := 0.5

var capacity: int = DEFAULT_CAPACITY
var rounds: int = DEFAULT_CAPACITY
var reload_duration: float = DEFAULT_RELOAD_DURATION
var reloading := false
var elapsed := 0.0

func configure(definition: Dictionary) -> bool:
	var next_capacity: Variant = definition.get("magazine_capacity", DEFAULT_CAPACITY)
	var next_duration: Variant = definition.get("reload_time", DEFAULT_RELOAD_DURATION)
	if typeof(next_capacity) != TYPE_INT or next_capacity <= 0:
		return false
	if typeof(next_duration) != TYPE_INT and typeof(next_duration) != TYPE_FLOAT:
		return false
	var duration := float(next_duration)
	if not is_finite(duration) or duration <= 0.0:
		return false
	# Validate the entire definition before replacing live ammunition or timing.
	capacity = next_capacity
	reload_duration = duration
	reset()
	return true

func can_fire() -> bool:
	return not reloading and rounds > 0

func consume() -> bool:
	if not can_fire():
		return false
	rounds -= 1
	return true

func start_reload() -> bool:
	if reloading or rounds >= capacity:
		return false
	reloading = true
	elapsed = 0.0
	return true

func tick(delta: float) -> bool:
	if not reloading or not is_finite(delta) or delta <= 0.0:
		return false
	elapsed = minf(elapsed + delta, reload_duration)
	if elapsed < reload_duration:
		return false
	rounds = capacity
	reloading = false
	return true

func progress() -> float:
	return clampf(elapsed / reload_duration, 0.0, 1.0)

func cancel_reload() -> void:
	# Interruption preserves actual ammunition; no refill or refund.
	reloading = false
	elapsed = 0.0

func reset() -> void:
	rounds = capacity
	reloading = false
	elapsed = 0.0
