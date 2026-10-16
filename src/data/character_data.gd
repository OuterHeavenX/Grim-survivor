class_name CharacterData
extends Resource
# A playable survivor. Runtime state (hp, position) lives on the player node;
# this only describes the class.

@export var id: StringName
@export var display_name := ""
@export_multiline var flavor := ""
# "default" (always owned), "shards" (bought for unlock_cost) or "relic"
# (found in the world or handed out by the campaign; never bought).
@export var unlock_rule := "shards"
@export var unlock_cost := 0
@export var starting_weapon: StringName
@export var base_hp := 100.0
@export var damage_mult := 1.0
@export var speed_mult := 1.0
@export var magnet_mult := 1.0
@export var xp_mult := 1.0
@export var palette: Dictionary = {}
@export var walk_sheet := ""
@export var portrait := ""
@export var innate_trait := ""


func to_legacy_dictionary() -> Dictionary:
	# A cost of -1 is how the old tables marked "found, not bought".
	var cost := unlock_cost
	if unlock_rule == "relic":
		cost = -1
	elif unlock_rule == "default":
		cost = 0
	return {
		"id": String(id), "name": display_name, "cost": cost, "flavor": flavor,
		"hp": base_hp, "dmg": damage_mult, "speed": speed_mult,
		"magnet": magnet_mult, "xp": xp_mult, "weapon": String(starting_weapon),
		"palette": palette,
	}
