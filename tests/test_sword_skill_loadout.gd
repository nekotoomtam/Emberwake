extends SceneTree
const Model = preload("res://scripts/loadout_inventory.gd")
const SkillUI = preload("res://scripts/sword_skill_ui.gd")
class PanelFactory:
	extends RefCounted
	func panel() -> StyleBoxFlat: return StyleBoxFlat.new()
class GameStub:
	extends Node
	var ui = PanelFactory.new()
	var sword_skills_open := false
	var sword_skill_cooldowns := {}
	var inventory_open := false
	var stats_open := false
	var body_lab_open := false
	var mode := "practice"
	var mana := 100.0
	var stats := {"attributes": {}}
	var compatible := true
	var last_slot := -1
	func primary_family() -> String: return "sword"
	func sword_skills_available() -> bool: return compatible
	func request_skill_slot(index: int) -> bool:
		last_slot = index
		return true
	func toggle_sword_skills() -> void: sword_skills_open = not sword_skills_open
var failures: Array[String] = []
var checks := 0
const PATH := "user://test-sword-skills-v5.json"
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)
		printerr("FAIL: ", why)
func write_data(value: Dictionary) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
func _initialize() -> void:
	var model = Model.new()
	model.save_path = PATH
	check(model.skill_slots == Model.DEFAULT_SKILLS, "three safe default slots")
	check(model.equip_skill(0, "vacuum_slice"), "equip unlocked Lv20 prototype skill")
	check(model.equip_skill(1, "stormcaller") and model.equip_skill(2, "sword_dance"), "equip three distinct selected skills")
	var copy = Model.new()
	copy.save_path = PATH
	check(copy.load_data() and copy.skill_slots == model.skill_slots and copy.valid_state(), "v5 save reload preserves exact slots and inventory")
	var sword_before: Array = model.skill_slots.duplicate()
	check(model.equip_skill(1, "mace_gather") and model.skill_slots == sword_before, "equipping mace does not alter sword slots")
	check(copy.load_data() and copy.mace_skill_slots == model.mace_skill_slots and copy.mace_skill_slots[1] == "mace_gather", "mace slots survive save and reload")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(saved.version == 5 and saved.skill_slots.size() == 3, "schema version 5 includes exactly three slots")
	var before: Array = model.skill_slots.duplicate()
	check(model.equip_skill(0, "stormcaller") and model.skill_slots == ["stormcaller", "vacuum_slice", "sword_dance"], "moving equipped skill swaps slots without duplication")
	check(model.equip_skill(1, "stormcaller") and model.skill_slots == before, "swapping back restores original selection")
	check(not model.equip_skill(0, "unknown") and not model.equip_skill(-1, "square_off") and not model.equip_skill(3, "square_off") and model.skill_slots == before, "reject unknown IDs and invalid slot bounds")
	model.save_path = "user://missing-skill-test-directory/skills.json"
	check(not model.equip_skill(0, "square_off") and model.skill_slots == before and model.message.contains("ไม่สำเร็จ"), "failed save rolls back memory and reports error")
	check(copy.load_data() and copy.skill_slots == before, "failed save leaves existing disk selection intact")
	for version in range(1, 5):
		var legacy = Model.new()
		var bag: Array = legacy.bag.duplicate()
		var absent: Array = []
		if version == 1: absent.append_array(["bow0", "bow1"])
		if version <= 2: absent.append_array(["crossbow0", "crossbow1"])
		if version <= 3: absent.append_array(["shield0", "shield1"])
		for id in absent: bag[bag.find(id)] = ""
		write_data({"version": version, "bag": bag, "sets": legacy.sets, "active": legacy.active})
		check(copy.load_data() and copy.valid_state() and copy.skill_slots == Model.DEFAULT_SKILLS, "v%d migration supplies default skills and retains inventory" % version)
	for value in [["stormcaller", "stormcaller", "unknown"], ["vacuum_slice"], [15, null, "square_off", "storm_blade"], "broken", []]:
		saved.skill_slots = value
		write_data(saved)
		check(copy.load_data() and copy.skill_slots.size() == 3, "malformed skills sanitized into three slots")
		check(copy.skill_slots == copy._sanitize_skills(value) and copy.skill_slots[0] != copy.skill_slots[1] and copy.skill_slots[1] != copy.skill_slots[2] and copy.skill_slots[0] != copy.skill_slots[2], "sanitization deterministic and unique")
	write_data(saved)
	check(copy.load_data(), "valid load before corrupt equipment check")
	before = copy.skill_slots.duplicate()
	saved.bag = []
	saved.skill_slots = ["double_slash", "square_off", "storm_blade"]
	write_data(saved)
	check(not copy.load_data() and copy.skill_slots == before and copy.valid_state(), "invalid inventory preserves previous valid state and skill slots")
	DirAccess.remove_absolute(PATH)
	call_deferred("run_ui")

func run_ui() -> void:
	var game := GameStub.new()
	root.add_child(game)
	var model = Model.new()
	model.save_path = ""
	var view := SkillUI.new()
	view.game = game
	view.model = model
	root.add_child(view)
	await process_frame
	await process_frame
	check(view.combat_bar.visible and view.slot_buttons.size() == 3 and not view.slot_buttons[0].disabled, "practice shows three usable skill buttons")
	check(view.slot_buttons[0].tooltip_text.contains("มานา 16") and view.slot_buttons[1].tooltip_text.contains("มานา 20") and view.slot_buttons[2].tooltip_text.contains("มานา 26"), "tooltips show each skill's mana cost")
	game.mana = 20.0
	view._update_combat()
	check(not view.slot_buttons[0].disabled and not view.slot_buttons[1].disabled and view.slot_buttons[2].disabled and view.slot_buttons[2].text.contains("มานาไม่พอ"), "only the skill above current mana is disabled")
	game.mana = 100.0
	view.slot_buttons[2].pressed.emit()
	check(game.last_slot == 2, "button 3 dispatches slot index 2")
	game.sword_skill_cooldowns.impaling_thrust = 2.5
	view._update_combat()
	check(view.slot_buttons[0].disabled and view.slot_buttons[0].text.contains("2.5"), "cooldown disables only affected button and displays remaining time")
	game.compatible = false
	view._update_combat()
	check(view.slot_buttons[1].disabled, "incompatible weapon or busy state disables skill")
	game.toggle_sword_skills()
	view._update_combat()
	var shown_choices: Array = view.equip_buttons.filter(func(entry): return entry.button.is_visible_in_tree())
	check(view.catalog.visible and not view.combat_bar.visible and shown_choices.size() == 24, "catalog exposes 8 sword skills and 3 slot choices with combat bar hidden")
	view._equip(0, "vacuum_slice")
	check(model.skill_slots[0] == "vacuum_slice" and view.status.text == model.message, "catalog equips and reports persistence result")
	game.stats.attributes = {"intelligence": 8}
	game.mana = 31.5
	game.compatible = true
	game.sword_skills_open = false
	view.refresh()
	check(view.slot_buttons[0].tooltip_text.contains("มานา 31.5") and view.catalog_details.vacuum_slice.text.contains("มานา 31.5"), "catalog and tooltip show discounted mana")
	check(not view.slot_buttons[0].disabled, "the discounted skill is available at its exact mana cost")
	root.size = Vector2i(1024, 640)
	await process_frame
	await process_frame
	var rect: Rect2 = view.catalog_panel.get_global_rect()
	var bounds: Vector2 = view.surface.size
	check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= bounds.x and rect.end.y <= bounds.y, "scroll catalog stays in minimum window bounds with project stretch")
	game.sword_skills_open = false
	game.inventory_open = true
	view._update_combat()
	check(not view.combat_bar.visible and not view.catalog.visible, "inventory hides skill surfaces")
	view.queue_free()
	game.queue_free()
	print("Sword skill loadout: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
