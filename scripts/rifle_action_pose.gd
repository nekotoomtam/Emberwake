extends RefCounted
const Stance=preload("res://scripts/weapon_stance.gd")
static func bolt_pose(progress: float,angle: float) -> Dictionary:
 var p:=clampf(progress,0,1)
 var pose:=Stance.rest("rifle",angle,-1)
 pose.phase="bolt";pose.progress=p;pose.stance_managed=false
 pose.pitch=.24*sin(PI*p);pose.radius=.35;pose.grip_height=.87
 pose.support_pull=sin(PI*p);pose.body_lean=-.025*sin(PI*p)
 return pose
static func reload_pose(cycle,angle: float) -> Dictionary:
 var pose:=Stance.rest("rifle",angle,-1)
 var p: float=cycle.action_progress()
 var lift: float=p if cycle.phase=="open" else (1-p if cycle.phase=="close" else 1.0)
 pose.phase="reload";pose.progress=(p*.2 if cycle.phase=="open" else (.8+p*.2 if cycle.phase=="close" else .5));pose.stance_managed=false
 pose.pitch=.9*lift;pose.radius=.18;pose.grip_height=.91
 pose.support_pull=sin(PI*p) if cycle.phase=="insert" else lift
 pose.body_lean=-.035*lift
 return pose
