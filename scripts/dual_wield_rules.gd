extends RefCounted
const SPEED:=.75
static func speed(dual: bool) -> float:return SPEED if dual else 1.0
static func dispersion(dual: bool) -> float:return 1.0/SPEED if dual else 1.0
