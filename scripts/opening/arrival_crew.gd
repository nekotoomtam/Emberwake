extends "res://scripts/opening/harbor_npc.gd"
## Preserve the shared pixel actor and local routes on a rotated moving vessel.
func tick(delta: float,camera: Camera3D,time_: float) -> void:
 super.tick(delta,camera,time_)
 facing=Directions.choose(global_basis*aim,camera,facing)
 var action: String="carry_walk" if profile.get("native_cargo",false) and carrying else "walk" if walking else "work" if work else "idle"
 var index: int=int(time_*(7 if walking else 2)+float(profile.get("phase",0)))%(4 if walking or work else 2)
 render_modular(camera,action,index)
