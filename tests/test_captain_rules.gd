extends SceneTree
var failures: Array=[]
var checks:=0
func check(v: bool,s: String) -> void:
 checks+=1
 if not v:failures.append(s);printerr("FAIL: ",s)
func _initialize() -> void:
 if not ResourceLoader.exists("res://scripts/captain_rules.gd"):check(false,"Captain geometry missing");finish();return
 var r=load("res://scripts/captain_rules.gd")
 for id in ["sweep","throw","slam"]:
  var d: Dictionary=r.definition(id);check(d.windup>=1.0 and d.recovery>=1.0,"readable timings "+id)
  check(d.base_parryable==(id!="slam"),"red rule "+id)
  for i in range(61):
   var t: float=d.active*i/60.0;var tip: Vector3=r.tip(d,0,t)
   check(r.contains(Vector3.ZERO,0,tip,d),"tip within telegraph "+id)
   check(r.contact(tip,tip,tip,d),"visible tip hits "+id)
   check(not r.contact(tip,tip,tip+Vector3.FORWARD*(d.radius+.02),d),"outside contact misses "+id)
 var sw: Dictionary=r.definition("sweep");check(not r.contains(Vector3.ZERO,0,Vector3.ZERO,sw),"sweep inner safe space");check(not r.contains(Vector3.ZERO,0,Vector3(3,0,0),sw),"outside sweep")
 var th: Dictionary=r.definition("throw");check(r.tip(th,0,0).distance_to(r.tip(th,0,th.active))<.001,"throw comes home");check(r.tip(th,0,th.active*.45).x>4,"long throw")
 var sl: Dictionary=r.definition("slam");check(not r.contains(Vector3.ZERO,0,Vector3(-2,0,0),sl),"slam only forward")
 finish()
func finish() -> void:
 print("CAPTAIN RULES: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
