extends RefCounted
## Harbor-scoped appearance selection; legacy combat art is intentionally
## still owned by the original hero modules. Switching never deletes art.
const LegacyDirections=preload("res://scripts/hero_directions.gd")
const LegacyCoffee=preload("res://scripts/opening/harbor_coffee_art.gd")
const TravelerFrames=preload("res://scripts/opening/traveler_harbor_frames.gd")
const TravelerCoffee=preload("res://scripts/opening/harbor_traveler_coffee_art.gd")
static var profile_id: String="traveler"
static func select(id: String) -> void:profile_id="legacy" if id=="legacy" else "traveler"
static func is_traveler() -> bool:return profile_id=="traveler"
static func frames(direction: String) -> SpriteFrames:
 return TravelerFrames.frames(direction) if is_traveler() else LegacyDirections.frames(direction)
static func choose(aim: Vector3,camera: Camera3D,current: String) -> String:
 return LegacyDirections.choose(aim,camera,current)
static func seated() -> Texture2D:
 return TravelerCoffee.seated() if is_traveler() else LegacyCoffee.seated()
static func sipping(index: int) -> Texture2D:
 return TravelerCoffee.sipping(index) if is_traveler() else LegacyCoffee.sipping(index)
static func rising(index: int) -> Texture2D:
 return TravelerCoffee.rising(index) if is_traveler() else LegacyCoffee.rising(index)
