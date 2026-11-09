extends SceneTree
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var people: Array=g.world.townspeople+g.world.crew
 check(people.size()==12,"all twelve civilians retained")
 var styles: Dictionary={};var sexes: Dictionary={};var snapshots: Array=[]
 var art=load("res://scripts/opening/harbor_human_art.gd")
 for npc in people:
  var p: Dictionary=npc.profile
  check(p.has("hairstyle") and p.has("male"),"generated appearance "+p.id)
  check(not p.get("cap",true),"no hat hides approved hair "+p.id)
  if p.has("hairstyle"):styles[p.hairstyle]=true;sexes[p.male]=true
  snapshots.append(p.duplicate(true))
 check(styles.size()==10,"all ten hairstyles represented")
 check(sexes.size()==2,"both face bases represented")
 for i in 360:g.tick(1.0/60)
 for i in people.size():check(people[i].profile==snapshots[i],"appearance stable during movement "+people[i].name)
 if styles.size()==10:
  var p: Dictionary=people[0].profile.duplicate(true)
  for dir in ["front","back","left","right"]:
   for action in ["idle","walk","work","carry_walk"]:
    var im: Image=art.frame(p,dir,action,0).get_image()
    check(im.get_size()==Vector2i(128,128),dir+" "+action+" frame dimensions")
    check(im.get_used_rect().end.y<=112,dir+" "+action+" foot baseline")
  var walk0: PackedByteArray=art.frame(p,"front","walk",0).get_image().get_data()
  check(walk0!=art.frame(p,"front","walk",1).get_image().get_data(),"new civilian walk visibly animates")
  var idle: PackedByteArray=art.frame(p,"front","idle",0).get_image().get_data()
  p.hairstyle=(int(p.hairstyle)+1)%10
  check(idle!=art.frame(p,"front","idle",0).get_image().get_data(),"hair changes shape independently of palette")
  p=people[0].profile.duplicate(true)
  var same: PackedByteArray=art.frame(p,"front","idle",0).get_image().get_data()
  p.skin="845b46";check(same!=art.frame(p,"front","idle",0).get_image().get_data(),"skin palette independent of hair")
  p=people[0].profile.duplicate(true);same=art.frame(p,"front","idle",0).get_image().get_data()
  p.male=not p.male;check(same!=art.frame(p,"front","idle",0).get_image().get_data(),"face base independent of hair")
 var before: Array=snapshots.duplicate(true)
 var world=g.world.get_script().new();g.add_child(world)
 var again: Array=world.townspeople+world.crew
 for i in people.size():check(again[i].profile==before[i],"same harbor seed reproduces identity "+people[i].name)
 world.free();g.free();await process_frame
 print("HARBOR APPEARANCE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
