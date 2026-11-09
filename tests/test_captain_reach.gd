extends SceneTree
var checks:=0
var failures: Array=[]
func check(v: bool,s: String) -> void:
 checks+=1
 if not v:failures.append(s);printerr("FAIL: ",s)
func _initialize() -> void:
 var rules=load("res://scripts/captain_rules.gd")
 for id in ["sweep","throw","slam"]:
  var d: Dictionary=rules.definition(id);var old: float={"sweep":1.9,"throw":5.2,"slam":2.0}[id]
  check(absf(d.reach-old*1.15)<.0001,"reach15percent "+id)
  check(d.has("trigger"),"shared trigger "+id)
  check(d.damage=={"sweep":18.0,"throw":24.0,"slam":30.0}[id],"same damage "+id)
  for i in range(21):
   var t: float=d.active*i/20;var p: Vector3=rules.tip(d,0,t);check(rules.contains(Vector3.ZERO,0,p,d),"drawn tip inside footprint "+id+str(i))
 print("CAPTAIN REACH: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
