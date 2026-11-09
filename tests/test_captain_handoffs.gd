extends SceneTree
const Art=preload("res://scripts/captain_art.gd")
const Rules=preload("res://scripts/captain_rules.gd")
const Pose=preload("res://scripts/captain_pose.gd")
var n:=0
var failures: Array=[]
func check(v: bool,s: String) -> void:
 n+=1
 if not v:failures.append(s);printerr("FAIL: ",s)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var th:=Rules.definition("throw");check(th.has("release"),"throw has explicit cast/release timeline")
 if not th.has("release"):finish();return
 check(not Rules.damaging(th,0) and Rules.damaging(th,th.release) and not Rules.damaging(th,th.catch_time),"held/caught anchor cannot damage")
 for angle in [0,PI,PI*.5,-PI*.5,.6,-.6,2.4,-2.4]:
  for id in ["sweep","throw","slam"]:
   var d:=Rules.definition(id);var active: Dictionary=Pose.sample(d,"attack",0,d.active,0,angle);var recover: Dictionary=Pose.sample(d,"recover",0,0,d.recovery,angle)
   var wind: Dictionary=Pose.sample(d,"windup",0,0,0,angle);var first: Dictionary=Pose.sample(d,"attack",0,0,0,angle);check(absf(wrapf(wind.roll-first.roll,-PI,PI))<.001,"no release rotation snap "+id)
   var a: Dictionary=Art._pose(active.animation,active.frame);var b: Dictionary=Art._pose(recover.animation,recover.frame)
   for joint in ["torso","left_hand","right_hand","left_elbow","right_elbow","head"]:check(a[joint].distance_to(b[joint])<.001,"no recover pop "+id+" "+joint)
   check(absf(wrapf(active.roll-recover.roll,-PI,PI))<.001,"no roll snap "+id)
   var idle: Dictionary=Pose.sample({},"chase",0,0,0,angle);var end: Dictionary=Pose.sample(d,"recover",0,0,0,angle)
   check(end.tip.distance_to(idle.tip)<.001 and absf(end.lift-idle.lift)<.001,"settled anchor joins rest "+id)
 var cast: Dictionary=Pose.sample(th,"attack",0,th.release,0,0);check(cast.frame==3,"arm finishes cast before released flight")
 var hold: Dictionary=Pose.sample(th,"attack",0,th.out_end,0,0);check(hold.animation=="throw_active" and hold.frame==3,"outbound holds followthrough")
 var reel: Dictionary=Pose.sample(th,"attack",0,(th.return_start+th.catch_time)*.5,0,0);check(reel.animation=="throw_reel","return visibly reels")
 var sl:=Rules.definition("slam");var impact: Dictionary=Pose.sample(sl,"attack",0,sl.active*sl.impact,0,0);check(impact.frame==2,"slam body impact matches ground contact")
 finish()
func finish() -> void:
 print("CAPTAIN HANDOFFS: ",n," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
