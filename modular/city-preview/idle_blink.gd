extends RefCounted

const OPEN := 0
const HALF := 1
const CLOSED := 2
var remaining := 0.0

func reset() -> void:
	remaining = randf_range(2.6, 5.2)

func advance(delta: float) -> int:
	remaining -= delta
	if remaining > 0.0:
		return OPEN
	var elapsed := -remaining
	if elapsed < 0.05:
		return HALF
	if elapsed < 0.12:
		return CLOSED
	if elapsed < 0.18:
		return HALF
	reset()
	return OPEN
