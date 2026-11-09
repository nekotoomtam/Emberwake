extends SceneTree
var game
var failures: Array[String]=[]
var checks := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func equip(id: String,hand: String) -> void:
 var index: int=game.loadout.bag.find(id)
 var source: Dictionary={"kind":"bag","index":index}
 if index<0:
  for i in range(2):
   for slot in ["main","off"]:
    if game.loadout.sets[i][slot]==id:source={"kind":"slot","set":i,"hand":slot}
 var target := {"kind":"slot","set":0,"hand":hand}
 if source!=target:check(game.loadout.move_item(source,target),"equip fixture")
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 for a in ["sword","mace","pistol"]:
  for b in ["sword","mace","pistol"]:
   game.loadout.defaults();game.loadout.save_path="";equip(a+"0","main");equip(b+("1" if a==b else "0"),"off");game.loadout_edited();game.start_run(true)
   for entry in [["front",Vector3.BACK],["back",Vector3.FORWARD],["left",Vector3.LEFT],["right",Vector3.RIGHT]]:
    game.aim=entry[1]
    for i in range(120):game._visual_tick(1.0/120)
    var center: float=game.camera.unproject_position(game.player.position).x
    for i in range(2):
     var side: float=(-1.0 if entry[0]=="front" else 1.0)*(1 if i==0 else -1)
     var points: Dictionary=game.dual_visual.rigs[i].get_blade_points()
     var grip: Vector2=game.camera.unproject_position(points.grip)
     var tip: Vector2=game.camera.unproject_position(points.tip)
     var u: float=(12.0 if entry[0]=="front" else 20.0) if i==0 else (20.0 if entry[0]=="front" else 12.0)
     var expected: Vector3=game.avatar.body.global_transform*Vector3((u*4-64)*.018,(64-78)*.018,0)
     check(game.dual_visual.rigs[i].grip_visual.shoulder_world.distance_to(expected)<.00001,"arm starts on actual shirt shoulder")
     check((grip.x-center)*side>5,a+"/"+b+"/"+entry[0]+" hand "+str(i)+" wrist remains on its body side")
     check((tip.x-grip.x)*side>5,a+"/"+b+"/"+entry[0]+" hand "+str(i)+" passive weapon points away from body")
    if entry[0]!="back":
     var image: Image=game.avatar.body.sprite_frames.get_frame_texture("idle",0).get_image()
     var extra := 0
     for y in range(20*4,24*4):
      for x in range(9*4,13*4):
       var px: int=127-x if entry[0]=="left" else x
       var color := image.get_pixel(px,y)
       if color.is_equal_approx(Color("ffd4ad")) or color.is_equal_approx(Color("e7a183")):extra+=1
     check(extra==0,"paired body has no third resting hand: "+entry[0])
 game.queue_free();await process_frame
 print("PAIR READABILITY: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL", " ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
