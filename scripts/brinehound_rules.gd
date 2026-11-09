extends RefCounted
const Anatomy = preload("res://scripts/anatomy_state.gd")
const HEALTH:=62.0
const SPEED:=3.0
const TRIGGER:=2.5
const MAX_POUNCE:=1.8
const STOP_DISTANCE:=.7
const BITE_REACH:=.95
const DURATIONS:=[.45,.14,.11,.42,.10,.42]
const RUN_FRAME:=.09
static func total_duration() -> float:
	var total:=0.0
	for duration: float in DURATIONS:total+=duration
	return total
static func pounce_distance(distance: float) -> float:
	return clampf(distance-STOP_DISTANCE,0,MAX_POUNCE) if is_finite(distance) else 0.0
static func attack(index: int,phase: int) -> Dictionary:
	var damage:=8.0 if phase==4 else 11.0
	var parts := Anatomy.STRIKE_TARGETS
	return {"id":"brinehound_follow_bite" if phase==4 else "brinehound_pounce_bite","shape":"sector","arc":deg_to_rad(100),"reach":BITE_REACH,"trigger":TRIGGER,"windup":DURATIONS[phase],"active":DURATIONS[phase],"recovery":DURATIONS[5],"damage":damage,"parryable":true,"base_parryable":true,"guard_cost":1.0,"projectiles":0,"variant":false,"impact":0.0,"lunge":0.0,"body_part":parts[posmod(index+(1 if phase==4 else 0),parts.size())],"body_damage":damage*.2}
