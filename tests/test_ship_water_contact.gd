extends SceneTree
const Spectrum=preload("res://scripts/opening/harbor_wave_spectrum.gd")
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
 if not ok:failures.append(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var path:="res://scripts/opening/ship_water_contact.gd"
 check(ResourceLoader.exists(path),"ship water contact helper is available")
 if not failures.is_empty():
  print("SHIP WATER CONTACT RED ",failures);quit(1);return
 var helper=load(path).new()
 var world:=Node3D.new();root.add_child(world)
 var bob_pivot:=Node3D.new();world.add_child(bob_pivot)
 var hull:=Node3D.new();bob_pivot.add_child(hull)
 helper.hull=hull;helper.phase=1.7;world.add_child(helper)
 helper.tick(0.0)
 check(helper.contact_count>=30,"both hull sides receive sufficient contact patches")
 check(helper.bow_contact_count>=4,"bow has curved contact patches")
 check(helper.side_contact_count>=32,"both sides have segmented contact strips")
 check(helper.intensity>0.1,"docked hull retains gentle lapping")
 var before_clock:float=helper.phase_clock
 var before_mesh=helper.get_node("FoamAndCrests").mesh
 bob_pivot.position=Vector3(8.0,1.5,-11.0)
 bob_pivot.rotation=Vector3(.07,.63,-.05)
 helper.tick(0.5)
 check(is_equal_approx(helper.global_position.y,Spectrum.MEAN),"foam remains at sea level while hull bobs")
 check(absf(helper.global_position.x-hull.global_position.x)<.0001,"foam follows hull x")
 check(absf(helper.global_position.z-hull.global_position.z)<.0001,"foam follows hull z")
 check(absf(helper.global_rotation.x)<.0001 and absf(helper.global_rotation.z)<.0001,"water does not inherit hull pitch or roll")
 check(helper.phase_clock>before_clock,"tick advances shader animation")
 var dock_intensity:float=helper.intensity
 helper.cruising=1.0;helper.tick(1.0)
 check(helper.intensity>dock_intensity,"cruising strengthens water response")
 check(helper.get_node("FoamAndCrests").mesh==before_mesh,"ticks reuse static mesh geometry")
 check(is_equal_approx(helper.water_height,Spectrum.MEAN),"observable water height matches sea contact")
 world.queue_free()
 await process_frame
 print("SHIP WATER CONTACT 13 checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
