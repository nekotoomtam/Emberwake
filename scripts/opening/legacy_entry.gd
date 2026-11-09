extends Node
@export var start_in_dungeon:=false
var game
var party: Array[Dictionary] = []
func _ready() -> void:
 game=load("res://scenes/game.tscn").instantiate()
 game.use_cutout_avatar=true
 game.expedition_companions=party.slice(1,3)
 if Engine.has_meta("harbor_native_qa"):game.loadout.save_path=""
 add_child(game)
 if not party.is_empty():
  game.avatar.cutout.apply_look(party[0].look)
  game.set_weapon_family(party[0].weapon)
  game.expedition_starting_flasks = party[0].get("flasks", -1)
 if start_in_dungeon:game.start_dungeon()
