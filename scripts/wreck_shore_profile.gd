extends RefCounted
const INTRO:=4.2
static func coast_z(x: float) -> float:return -.30*x+.8*sin(x*.10)
static func travel_z(x: float) -> float:return coast_z(x)+1.0-6.5*smoothstep(47,62,x)
static func sea_z(x: float) -> float:return coast_z(x)+6.8
static func forest_z(x: float) -> float:return travel_z(x)-3.7
