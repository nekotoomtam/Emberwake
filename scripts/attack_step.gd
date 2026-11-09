extends RefCounted
## One locked, cumulative release step per accepted ordinary melee stroke.

const ShortLunge = preload("res://scripts/short_lunge.gd")
const DISTANCES := {
	"sword": [0.18, 0.20, 0.30],
	"greatsword": [0.28, 0.30, 0.42],
	# The accepted second Mace strike owns its separate .75-unit lunge.
	"mace": [0.16, 0.0, 0.24],
}

var distance: float = 0.0
var travelled: float = 0.0
var requested: float = 0.0
var direction := Vector3.ZERO
var _sweep = ShortLunge.new()
var _approach_during_windup := false


func begin(family: String, stage: int, angle: float, distance_override: float = -1.0, max_distance: float = 0.85, approach_during_windup: bool = false) -> bool:
	reset()
	if not DISTANCES.has(family) or stage < 0 or stage > 2 or not is_finite(angle):
		return false
	distance = DISTANCES[family][stage]
	# The separate accepted Mace second-strike lunge remains its sole travel path.
	if not (family == "mace" and stage == 1) and is_finite(distance_override):
		var limit: float = max_distance if is_finite(max_distance) and max_distance > 0.0 else 0.85
		distance = clampf(distance_override, distance, maxf(distance, limit))
	_approach_during_windup = approach_during_windup
	direction = Vector3(cos(angle), 0.0, sin(angle))
	return true


func reset() -> void:
	distance = 0.0
	travelled = 0.0
	requested = 0.0
	direction = Vector3.ZERO
	_approach_during_windup = false
	_sweep.reset()


func advance(body: CharacterBody3D, elapsed: float, definition: Dictionary, targets: Array) -> float:
	if not is_instance_valid(body) or not body.is_inside_tree() or distance <= 0.0 or not is_finite(elapsed) or elapsed <= 0.0:
		return 0.0
	if not _finite_number(definition.get("windup")) or not _finite_number(definition.get("active")):
		return 0.0
	var windup: float = definition.windup
	var release: float = definition.active
	if windup < 0.0 or release <= 0.0:
		return 0.0
	if definition.get("kind", "sweep") in ["lift", "slam"]:
		if not _finite_number(definition.get("impact_progress")):
			return 0.0
		var contact: float = definition.impact_progress
		if contact <= 0.0 or contact > 1.0:
			return 0.0
		release *= contact
	# Derive from the motion clock, including a frame ending after recovery.
	# ShortLunge consumes attempted travel even when a target or wall clips it.
	var progress: float = clampf((elapsed - windup) / release, 0.0, 1.0)
	# Approach during preparation so the existing blade contact can occur from
	# its intended position. Ordinary attacks keep the authored release step.
	if _approach_during_windup and windup > 0.0:
		progress = clampf(elapsed / windup, 0.0, 1.0)
	var desired: float = distance * (1.0 - (1.0 - progress) * (1.0 - progress))
	var actual: float = _sweep.advance(body, direction, desired, targets, distance)
	requested = _sweep.requested
	travelled = _sweep.travelled
	return actual


func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value))
