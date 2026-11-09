extends SceneTree
var g
var count:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 count+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func close(a: float,b: float,label: String) -> void:check(absf(a-b)<.001,label+" got="+str(a))
func equip(id: String,hand: String) -> void:
 var index: int=g.loadout.bag.find(id)
 var src: Dictionary={"kind":"bag","index":index}
 if index<0:
  for i in range(2):
   for h in ["main","off"]:
    if g.loadout.sets[i][h]==id:src={"kind":"slot","set":i,"hand":h}
 var dst:={"kind":"slot","set":0,"hand":hand}
 if src!=dst:check(g.loadout.move_item(src,dst),"equip fixture")
func fresh(main: String,off: String="") -> void:
 g.loadout.defaults();g.loadout.unequip({"kind":"slot","set":0,"hand":"off"});equip(main,"main")
 if off!="":equip(off,"off")
 g.loadout_edited();g.start_run(true);g.test_aim=Vector3.RIGHT;g.move_input=Vector2.ZERO;g.stats.base.critical_chance=0
 for e in g.enemies:e.position=Vector3(100,0,100)
func advance(t: float) -> void:
 while t>.0000001:
  var dt: float=minf(t,1.0/120);g.tick(dt);t-=dt
func right(on: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=on;root.push_input(e,true)
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.loadout.save_path=""
 fresh("pistol0");g.remove_body_part("left_leg");g.remove_body_part("right_leg");close(g.anatomy.dash_multiplier(),.25,"noleg quarterdash");advance(.26);g.health=10;var before: float=g.stamina
 check(g.request_dodge(Vector3.RIGHT),"noleg elbowdash allowed");close(g.stamina,before-30,"existing dash cost");check(not g.body_action_ready(),"ready stance invalidated onpush");check(not g.use_health_flask(),"no movingcrawl potion");check(not g.request_dodge(Vector3.RIGHT),"cannotrepeat dash")
 advance(.10);close(g.player.velocity.length(),2.625,"quarterdash velocity");check(g.avatar.body.animation!="dodge","no standingroll whileprone");check(not g.avatar.weapon.visible,"weapon tucked duringpush");check(g.avatar.grip_visual.visible,"floor arms visible");check(g.avatar.body.scale.y<.8,"low body kept");check(not g.request_attack(),"no shot duringpush")
 var hp: float=g.health;g.incoming_attack(10,g.player.position+Vector3.RIGHT,true);close(g.health,hp,"existingiframe protection retained");advance(.4);check(g._dodge_left<=0 and g.body_action_ready(),"recover stationary stance")
 g.remove_body_part("right_arm");close(g.anatomy.dash_multiplier(),.25,"one arm also shortpush");check(g.request_dodge(Vector3.LEFT),"remainingarm push allowed");advance(.5);g.remove_body_part("left_arm");close(g.anatomy.dash_multiplier(),0,"noarms no elbowpush");check(not g.request_dodge(Vector3.RIGHT),"limbless cannotdash")
 fresh("pistol0");g.remove_body_part("left_leg");close(g.anatomy.dash_multiplier(),.6,"oneleg unchanged");fresh("pistol0");close(g.anatomy.dash_multiplier(),1,"intact unchanged")
 g.remove_body_part("left_leg");g.remove_body_part("right_leg");g.stamina=0;check(not g.request_dodge(Vector3.RIGHT),"stamina gate");g.stamina=100;g.toggle_body_lab();check(not g.request_dodge(Vector3.RIGHT),"paused lab gate");g.toggle_body_lab();g.start_run(true);check(g.anatomy.leg_count()==2,"reset restores legs")
 g.queue_free();await process_frame
 print("ELBOW DASH: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
