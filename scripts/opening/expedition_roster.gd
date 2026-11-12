extends RefCounted

const FINAL_STAND_THRESHOLD := 200
const STAND_UP_SANITY := 40
const STAND_UP_HEALTH := .50
const SAVE_PATH := "user://expedition_roster.cfg"
static var session_losses: Dictionary = {}

static func losses() -> Dictionary:
	var data := ConfigFile.new()
	data.load(SAVE_PATH)
	var result := session_losses.duplicate()
	for id in data.get_section_keys("lost_recruits") if data.has_section("lost_recruits") else []:
		if data.get_value("lost_recruits", id, false):
			result[id] = true
	return result

static func record_loss(id: String) -> void:
	session_losses[id] = true
	var data := ConfigFile.new()
	for lost_id in losses():
		data.set_value("lost_recruits", lost_id, true)
	var error := data.save(SAVE_PATH)
	if error != OK:
		push_error("Cannot save expedition roster loss for %s: %s" % [id, error_string(error)])
