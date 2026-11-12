extends Node
@export var start_in_dungeon:=false
var game
var party: Array[Dictionary] = []
var prepared_game: PackedScene
var arrival_locked := false
func _ready() -> void:
 var game_scene: PackedScene=prepared_game if prepared_game!=null else load("res://scenes/game.tscn")
 game=game_scene.instantiate()
 game.use_cutout_avatar=true
 game.expedition_companions=party.slice(1,3)
 if not party.is_empty():
  game.expedition_leader_attributes=party[0].get("attributes", {})
  game.expedition_leader_talents=party[0].get("talents", {})
  game.expedition_recruit_id=party[0].get("roster_id","")
 if Engine.has_meta("harbor_native_qa"):game.loadout.save_path=""
 add_child(game)
 if not party.is_empty():
  game.avatar.cutout.apply_look(party[0].look)
  game.set_weapon_family(party[0].weapon)
  game.expedition_starting_flasks = party[0].get("flasks", -1)
 if start_in_dungeon:game.start_dungeon()
 if arrival_locked:game.set_arrival_lock(true)
