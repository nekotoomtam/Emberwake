extends SceneTree
const Spectrum=preload("res://scripts/opening/harbor_wave_spectrum.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func finish() -> void:
 print("SHIP BOW WAVE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 var path:="res://scripts/opening/ship_bow_wave.gd"
 check(ResourceLoader.exists(path),"dedicated bow-displacement wave is available")
 if not ResourceLoader.exists(path):finish();return
 var owner:=Node3D.new();root.add_child(owner)
 var hull:=Node3D.new();owner.add_child(hull)
 var contact=load("res://scripts/opening/ship_water_contact.gd").new();contact.hull=hull;owner.add_child(contact)
 var wave=contact.get("bow_wave")
 check(wave!=null,"actual shared water-contact owner includes the bow wave")
 if wave==null:owner.free();finish();return
 check(wave.get_parent()==contact,"wave follows the sea-level contact transform")
 check(wave.visual.mesh.get_surface_count()==1,"two curved branches share one reusable mesh")
 check(wave.find_children("*","CollisionObject3D",true,false).is_empty(),"bow wave is purely visual")
 var start: Vector3=wave.centerline(0,1)
 var end: Vector3=wave.centerline(1,1)
 check(start.x>14 and start.x<14.5 and absf(start.z)<.5,"crest starts immediately ahead of the actual pointed bow")
 check(end.x<6 and end.z>start.z+2.5,"crest sweeps aft and outward along the hull")
 var mirror:=true;var outside:=true
 var hull_shape=load("res://scripts/opening/ship_hull_surface.gd")
 for i in 21:
  var point: Vector3=wave.centerline(float(i)/20,1);var opposite: Vector3=wave.centerline(float(i)/20,-1)
  mirror=mirror and point.x==opposite.x and point.z==-opposite.z
  outside=outside and point.z>hull_shape.waterline_half_width(point.x)
 check(mirror,"port and starboard waves are mirrored")
 check(outside,"wave follows the outside of the actual hull waterline")
 var mesh=wave.visual.mesh;var material=wave.material
 contact.cruising=1;contact.tick(.75)
 check(is_equal_approx(float(material.get_shader_parameter("drive")),1),"cruising activates the stronger displacement wave")
 check(is_equal_approx(float(material.get_shader_parameter("clock")),contact.phase_clock),"wave uses the owner clock instead of uncontrolled TIME")
 hull.position=Vector3(4,2,-3);hull.rotation=Vector3(.08,.7,.05);contact.tick(.2)
 check(absf(contact.global_position.y-Spectrum.MEAN)<.0001 and absf(contact.global_rotation.x)<.0001 and absf(contact.global_rotation.z)<.0001,"wave stays on the sea while ship pitches and rolls")
 check(absf(contact.global_position.x-hull.global_position.x)<.0001 and absf(contact.global_position.z-hull.global_position.z)<.0001,"wave follows the actual hull translation")
 check(wave.visual.mesh==mesh and wave.material==material,"ticks reuse mesh and material")
 var time: float=contact.phase_clock;contact.tick(0)
 check(is_equal_approx(float(material.get_shader_parameter("clock")),time),"paused tick freezes wave animation")
 contact.cruising=0;contact.phase_clock=0;contact.tick(0)
 check(is_zero_approx(float(material.get_shader_parameter("drive"))) and is_zero_approx(float(material.get_shader_parameter("clock"))),"berthing and replay reset wave drive and clock")
 owner.free();await process_frame;finish()
