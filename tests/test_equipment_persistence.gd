extends SceneTree
const Model = preload("res://scripts/loadout_inventory.gd")
var failures: Array[String] = []
var checks := 0
var game
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures.append(why);printerr("FAIL: ",why)
func _initialize() -> void: call_deferred("run")
func loc(index: int) -> Dictionary: return {"kind":"bag","index":index}
func hand(index: int, key: String) -> Dictionary: return {"kind":"slot","set":index,"hand":key}
func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;root.push_input(event,true)
func tick(seconds: float) -> void:
	for i in range(int(ceil(seconds*120))):
		await physics_frame
		game.tick(1.0/120)
func click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new();motion.position=position;root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.pressed=down;root.push_input(event,true)
	await process_frame
func run() -> void:
	var m = Model.new();m.save_path=""
	check(m.valid_state() and m.items.size()==12,"initial item conservation")
	check(m.for_pair()==["sword0","pistol0"],"each click plans main then off")
	var old: Array = m.sets.duplicate(true)
	check(not m.move_item(loc(m.bag.find("rifle0")),hand(0,"off")) and m.sets==old and m.valid_state(),"reject two-hand offhand without losing anything")
	check(m.move_item(loc(m.bag.find("rifle0")),hand(0,"main")),"equip two-handed rifle")
	check(m.sets[0].off=="" and "pistol0" in m.bag and "sword0" in m.bag and m.valid_state(),"two-hand returns previous main and offhand safely")
	check(not m.move_item(loc(m.bag.find("mace0")),hand(0,"off")) and m.valid_state(),"reserved off slot refuses item")
	check(m.unequip(hand(0,"main")) and m.primary(0)=="" and m.valid_state(),"empty set legal")
	check(m.move_item(loc(m.bag.find("pistol0")),hand(0,"main")) and m.move_item(loc(m.bag.find("pistol1")),hand(0,"off")),"identical weapons use two distinct items")
	check(m.for_pair()==["pistol0","pistol1"] and m.valid_state(),"same family still routes individual IDs")
	m.save_path="user://stats-v40-save-test.json";check(m.save_data(),"save loadout")
	var copy = Model.new();copy.save_path=m.save_path
	check(copy.load_data() and copy.bag==m.bag and copy.sets==m.sets,"load equipment and bag")
	var file := FileAccess.open(m.save_path,FileAccess.WRITE);file.store_string("{invalid");file.close()
	copy.defaults();check(not copy.load_data() and copy.valid_state(),"corrupt JSON retains valid defaults")
	DirAccess.remove_absolute(m.save_path)
	print("EQUIPMENT PERSISTENCE: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
