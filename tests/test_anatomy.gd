extends SceneTree
var n:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,s: String) -> void:
 n+=1
 if not ok:failures.append(s);printerr("FAIL: ",s)
func near(a: float,b: float,s: String) -> void:check(absf(a-b)<.001,s)
func run() -> void:
 if not ResourceLoader.exists("res://scripts/anatomy_state.gd"):
  check(false,"anatomy state absent");print("ANATOMY: FAIL",failures);quit(1);return
 var a=load("res://scripts/anatomy_state.gd").new()
 check(a.integrity.size()==10 and a.arm_count()==2 and a.leg_count()==2,"ten intact parts")
 a.remove("right_arm");near(a.hp_multiplier(),.9,"arm maxHP share");check(a.arm_count()==1 and not a.functional("right_arm"),"arm unavailable")
 a.remove("left_leg");near(a.hp_multiplier(),.75,"shares additive originalmax");near(a.dash_multiplier(),.6,"oneleg shortdash")
 a.remove("right_leg");check(a.dash_multiplier()==.25 and a.move_multiplier()>0 and a.move_multiplier()<.2,"onearmcrawl")
 a.remove("left_arm");near(a.hp_multiplier(),.5,"alllimbs leaves50percentmax");check(a.move_multiplier()>0 and a.move_multiplier()<.1,"wriggle remainspossible")
 a.reset();a.set_integrity("torso",0);check(not a.dead(),"torso0 alive");a.damage("torso",20,false);near(a.integrity.head,80,"torso spill half raw HP into head capacity50")
 a.reset();a.damage("right_arm",200,false);check(a.present("right_arm") and a.functional("right_arm"),"zero HP arm stays usable");near(a.hp_multiplier(),1,"zero HP does not reduce max health")
 a.damage("right_arm",1,true);check(not a.present("right_arm"),"red finishes zeroarm")
 a.reset();a.set_integrity("left_leg",25);a.damage("left_leg",5,true);check(a.present("left_leg"),"red smallhit notinstaloss");a.damage("left_leg",30,true);check(not a.present("left_leg"),"criticalred tozero loss")
 a.reset();a.damage("right_forearm",3.125);near(a.integrity.right_forearm,75,"forearm tracks its own damage");near(a.integrity.right_upper_arm,100,"upper arm stays intact")
 a.remove("right_forearm");check(not a.present("right_upper_arm") and not a.present("right_forearm") and a.arm_count()==1,"forearm loss removes the whole arm");near(a.hp_multiplier(),.9,"both segments lower max health")
 a.restore("right_forearm");check(a.arm_count()==2,"restoring a missing segment returns the whole arm");a.remove("right_upper_arm");check(not a.present("right_forearm") and a.arm_count()==1,"upper arm loss also removes downstream forearm");near(a.hp_multiplier(),.9,"both arm segment shares applied")
 a.reset();a.remove("left_lower_leg");check(not a.present("left_thigh") and not a.present("left_lower_leg") and a.leg_count()==1,"lower leg loss removes the whole leg")
 a.reset();a.set_integrity("right_forearm",0);var torso_before: float=a.part_hp("torso");a.damage("right_arm",4,true)
 check(not a.present("right_arm") and is_equal_approx(a.part_hp("torso"),torso_before),"one red hit that severs a limb does not hit the torso again")
 a.reset();a.damage("head",100,false);check(a.dead(),"head0 dead")
 a.reset();a.set_integrity("head",NAN);near(a.integrity.head,100,"invalidvalue rejected");a.damage("head",-5,true);near(a.integrity.head,100,"negativehit rejected")
 print("ANATOMY: ",n," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
