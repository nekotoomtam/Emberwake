extends SceneTree
var n:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,s: String) -> void:
 n+=1
 if not ok:failures.append(s);printerr("FAIL: ",s)
func near(a: float,b: float,s: String) -> void:check(absf(a-b)<.001,s)
func run() -> void:
 var a=load("res://scripts/anatomy_state.gd").new()
 var api:=true
 for method in ["bind_max_hp","part_hp","part_max","injured","weapon_speed","sight_multiplier","action_cost_multiplier","dash_cost_multiplier"]:
  check(a.has_method(method),"body HP API: "+method);api=api and a.has_method(method)
 if not api:finish();return
 near(a.part_max("head"),50,"head weighted capacity")
 near(a.part_max("torso"),75,"torso weighted capacity")
 near(a.part_max("right_arm"),25,"arm weighted capacity")
 near(a.part_max("left_leg"),37.5,"leg weighted capacity")
 var budget:=0.0
 for id in a.PARTS:budget+=a.part_max(id)
 near(budget,250,"default total body budget")
 a.damage("head",10);near(a.part_hp("head"),40,"damage spends actual HP");near(a.integrity.head,80,"legacy percentage read")
 a.set_integrity("right_arm",40);near(a.part_hp("right_arm"),10,"percentage setter maps actual HP")
 a.remove("left_leg");a.bind_max_hp(200)
 near(a.part_hp("head"),80,"rebind preserves head percent");near(a.part_hp("right_arm"),20,"rebind preserves arm percent")
 near(a.part_max("left_leg"),75,"missing part capacity scales");near(a.part_hp("left_leg"),0,"missing remains zero");check(not a.present("left_leg"),"rebind keeps missing")
 a.bind_max_hp(200);near(a.part_hp("head"),80,"repeated binding does not compound")
 a.bind_max_hp(NAN);a.bind_max_hp(0);near(a.part_max("head"),100,"invalid binding ignored")
 a.restore("left_leg");near(a.part_hp("left_leg"),75,"restore uses rebound capacity")
 a.reset();near(a.part_hp("head"),100,"reset retains bound reference")
 a.bind_max_hp(100);a.set_integrity("torso",0);a.damage("torso",20)
 near(a.part_hp("head"),40,"zero torso transfers half raw HP");near(a.integrity.head,80,"overflow percentage uses head capacity")
 a.reset();a.set_integrity("torso",10);a.damage("torso",20);near(a.part_hp("head"),50,"crossing torso zero does not spill same hit")
 a.reset();a.set_integrity("right_arm",31);a.damage("right_arm",100,true);check(a.present("right_arm") and not a.functional("right_arm"),"red above threshold disables without removal")
 a.damage("right_arm",1,true);check(not a.present("right_arm"),"red zero part removes");near(a.hp_multiplier(),.9,"missing arm keeps original maxHP share")
 a.reset();a.set_integrity("left_leg",30);a.damage("left_leg",11,true);check(a.present("left_leg"),"red nonlethal does not remove");a.damage("left_leg",1,true);check(not a.present("left_leg"),"red at threshold removes after HP exhausted")
 a.reset();check(not a.injured("head"),"intact not injured");a.set_integrity("head",60);check(a.injured("head"),"injured threshold inclusive");near(a.sight_multiplier(),.8,"injured head narrows sight")
 a.set_integrity("head",60.01);near(a.sight_multiplier(),1,"above threshold sight normal")
 a.set_integrity("torso",60);near(a.action_cost_multiplier(),1.2,"injured torso increases action cost")
 a.set_integrity("torso",0);check(a.injured("torso") and a.present("torso") and not a.functional("torso"),"zero present torso injured");near(a.move_multiplier(),.45,"zero torso existing movement effect")
 a.reset();a.set_integrity("right_arm",60);near(a.weapon_speed("right_arm"),.9,"one hand injured selected arm");near(a.weapon_speed("left_arm"),1,"one hand healthy selected arm");near(a.weapon_speed("right_arm",true),.95,"two hand one injury")
 a.set_integrity("left_arm",0);near(a.weapon_speed("left_arm",true),.9,"two hand both injuries additive")
 a.remove("left_arm");check(not a.injured("left_arm"),"missing is not mild injury");near(a.weapon_speed("right_arm",true),.95,"missing arm excluded from mild injury count")
 a.reset();a.set_integrity("left_leg",60);near(a.dash_cost_multiplier(),1.25,"one injured leg dash cost");near(a.move_multiplier(),1,"mild leg injury no movement penalty");near(a.dash_multiplier(),1,"mild leg injury no dash distance penalty")
 a.set_integrity("right_leg",0);near(a.dash_cost_multiplier(),1.25,"both injured leg cost applied once");near(a.dash_multiplier(),.6,"zero leg short dash remains")
 a.remove("left_leg");a.remove("right_leg");near(a.dash_cost_multiplier(),1,"missing legs no mild injury cost");near(a.dash_multiplier(),.25,"missing legs elbow dash")
 a.reset();a.damage("head",50);check(a.dead(),"actual head HP exhaustion kills")
 near(a.part_hp("unknown"),0,"unknown HP query");near(a.part_max("unknown"),0,"unknown max query");check(not a.injured("unknown"),"unknown not injured")
 finish()
func finish() -> void:
 print("BODY HP: ",n," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
