extends RefCounted
## Scalar HP healing only. The owner gates use and pauses time by not advancing.
## Effects store independent seconds remaining; excess healing is spent, never banked.
const RUN_CHARGES := 3
const INSTANT_HEAL := 25.0
const HEAL_PER_SECOND := 5.0
const EFFECT_SECONDS := 5.0

var healing_multiplier := 1.0
var charges: int = RUN_CHARGES
var effects: Array[float] = []

func reset() -> void:
	charges = RUN_CHARGES
	effects.clear()

func drink(current: float, cap: float) -> float:
	if not _valid_health(current, cap): return current
	if current >= cap: return cap
	if charges <= 0: return current
	charges -= 1
	effects.append(EFFECT_SECONDS)
	return minf(cap, current + INSTANT_HEAL * healing_multiplier)

func advance(delta: float, current: float, cap: float) -> float:
	if not is_finite(delta) or delta < 0.0 or not _valid_health(current, cap):
		return current
	var healing := 0.0
	for index in range(effects.size() - 1, -1, -1):
		var elapsed := minf(delta, effects[index])
		healing += elapsed * HEAL_PER_SECOND
		effects[index] -= elapsed
		if effects[index] <= 0.0: effects.remove_at(index)
	return minf(cap, current + healing * healing_multiplier)

func rate() -> float:
	return effects.size() * HEAL_PER_SECOND * healing_multiplier

func cancel_effects() -> void:
	effects.clear()

func _valid_health(current: float, cap: float) -> bool:
	return is_finite(current) and current >= 0.0 and is_finite(cap) and cap > 0.0
