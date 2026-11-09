extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run():
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var life=g.world.dock_life;var foliage=g.world.foliage_study
 check(life.chat.size()==2 and life.marked_workers.size()==2,"two conversational residents and exactly two marked haulers")
 check(life.chat[0].aim.dot(life.chat[1].aim)<-.99,"conversation partners still face each other")
 await physics_frame
 for actor in life.chat+life.marked_workers:
  check(actor.move_on_route(actor.position),"actual person spawns clear of native walls/stock/people: "+str(actor.name))
  check(is_equal_approx(actor.sprite.pixel_size,.018),"normal human scale: "+str(actor.name))
 check(life.source_boxes.size()==2,"only the two real marked stock representations")
 for box in life.source_boxes:
  box.hide();check(box.get_node("CrateFootprint").collision_layer==0,"invisible source stock has no collider")
  box.show();check(box.get_node("CrateFootprint").collision_layer==1,"visible stock restores collision")
 var meshes: Array=[]
 for card in foliage.cards:meshes.append(card.mesh.get_instance_id())
 for frame in ceili(2*Engine.physics_ticks_per_second):await physics_frame;g.world.tick(1.0/Engine.physics_ticks_per_second,g.camera)
 var after: Array=[]
 for card in foliage.cards:after.append(card.mesh.get_instance_id())
 check(meshes==after and foliage.clusters.size()>7,"denser foliage retains its meshes while moving")
 check(g.world.square_garden.trees.all(func(t):return t.get_node_or_null("HybridFoliage")!=null and t.get_node_or_null("TrunkFootprint")!=null and t.get_node_or_null("BedFootprint")!=null),"both trees receive leaf canopies and retain physical trunk/bed")
 g.audio.shutdown();g.free()
 print("HARBOR DOCK LIFE v103 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
