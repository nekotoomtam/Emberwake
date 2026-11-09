extends RefCounted
## Small visual sea motion; stable walking/support collisions remain on the berth anchor.
static func pose(clock: float,cruising: float=0.0,phase: float=0.0) -> Transform3D:
 var t: float=clock+phase
 var energy: float=lerpf(1.0,1.5,clampf(cruising,0.0,1.0))
 var heave: float=(sin(t*1.13)*.043+sin(t*.63+.7)*.017)*energy
 var pitch: float=deg_to_rad(sin(t*.91+.5)*.10)*energy
 var roll: float=deg_to_rad(sin(t*.79)*.24)*energy
 return Transform3D(Basis.from_euler(Vector3(pitch,0,roll)),Vector3(0,heave,0))
