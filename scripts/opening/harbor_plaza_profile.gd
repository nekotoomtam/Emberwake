extends RefCounted
## Shared authored layout; all coordinates use the existing harbor metre scale.
const CAFE:=Vector3(-43,.055,-9)
const FOUNTAIN:=Vector3(-32,.055,-8.5)
const FOUNTAIN_RADIUS:=2.3
const PLAZA_RECT:=Rect2(Vector2(-51,-20),Vector2(31.3,35.4))
const CONNECTOR_RECT:=Rect2(Vector2(-22.5,2.6),Vector2(7,12.8))
const QUAY_RECT:=Rect2(Vector2(-18,2.1),Vector2(40,13.3))
const NORTH_APPROACH_RECT:=Rect2(Vector2(-27.5,-22.5),Vector2(7.8,5.7))
const NORTH_GATE_Z:=-22.5
const WEST_STREET_RECT:=Rect2(Vector2(-64,-25),Vector2(13,42.5))
const WEST_LINE_X:=-53.45
const WEST_GATE_X:=-53.20
const WEST_APPROACH_RECT:=Rect2(Vector2(WEST_GATE_X,-21),Vector2(2.20,38.5))
const PROMENADE_WEST_RECT:=Rect2(Vector2(WEST_LINE_X,-21),Vector2(2.45,27.3))
const PROMENADE_FRONT_RECT:=Rect2(Vector2(-51,4.3),Vector2(31.3,2.0))
const SEAFRONT_RECT:=Rect2(Vector2(-79,6.3),Vector2(15,11.2))
const ROAD_JOIN_RECT:=Rect2(Vector2(-53.45,6.3),Vector2(3.95,9.1))
const TOWN_END_RECT:=Rect2(Vector2(-64,-29),Vector2(13,8))
const CUP_REST:=CAFE+Vector3(.64,.56,-.14)
const SAUCER:=CAFE+Vector3(.64,.49,-.14)
const CAFE_CAMERA:=CAFE+Vector3(5.5,7.2,13.5)
const CAFE_LOOK:=CAFE+Vector3(5.5,1.3,-2)
const CAFE_FOV:=48.0
const WALK_ROUTE: Array[Vector3]=[CAFE+Vector3(2,0,3.5),Vector3(-36,.055,-3),Vector3(-25,.055,-3),Vector3(-22,.055,6),Vector3(-16,.055,11.6),Vector3(-1.8,.055,11.6),Vector3(7.5,.055,11.6),Vector3(7,.055,2.7),Vector3(7,.43,-2),Vector3(7,2.315,-4.8)]
static func contains_ground(at: Vector3) -> bool:
 var point:=Vector2(at.x,at.z)
 return PLAZA_RECT.has_point(point) or CONNECTOR_RECT.has_point(point) or NORTH_APPROACH_RECT.has_point(point) or WEST_APPROACH_RECT.has_point(point)
static func reserve_overlaps(at: Vector3,width: float,depth: float) -> bool:
 var footprint:=Rect2(Vector2(at.x-width*.5,at.z-depth*.5),Vector2(width,depth))
 return Rect2(Vector2(-52,-20.5),Vector2(32.3,39)).intersects(footprint,true) or WEST_STREET_RECT.grow(.8).intersects(footprint,true) or TOWN_END_RECT.grow(.4).intersects(footprint,true) or SEAFRONT_RECT.grow(.4).intersects(footprint,true)
static func wrong_way_exit(at: Vector3) -> bool:
 # The northeast promenade leads away from our original boarding pier.
 var north: bool=at.x>=NORTH_APPROACH_RECT.position.x and at.x<=NORTH_APPROACH_RECT.end.x and at.z<NORTH_GATE_Z
 var west: bool=at.x<WEST_GATE_X and at.z>=WEST_APPROACH_RECT.position.y and at.z<=WEST_APPROACH_RECT.end.y
 return north or west
static func rearm_wrong_way(at: Vector3) -> bool:
 # Repeated pressure at the western seam stays latched. Deliberate inward
 # travel rearms it; the separate north passage keeps its prior safe return.
 return (at.x>PLAZA_RECT.position.x+.5 and at.z>PLAZA_RECT.position.y+2.0) or (WEST_APPROACH_RECT.has_point(Vector2(at.x,at.z)) and at.x>=WEST_GATE_X+.7)
