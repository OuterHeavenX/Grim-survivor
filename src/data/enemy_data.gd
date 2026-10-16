class_name EnemyData
extends Resource
# One kind of foe. Behaviour beyond "walk at the player" is composed from the
# optional behavior script rather than branched on inside enemy.gd.

@export var id: StringName
@export var display_name := ""
@export var base_hp := 20.0
@export var base_damage := 9.0
@export var speed := 120.0
@export var xp_value := 1
@export var radius := 16.0
# Frame count of assets/sprites/<id>_walk.png. 0 = procedural fallback body.
@export var walk_frames := 0
@export var behavior: Script
@export var behavior_params: Dictionary = {}
# skeletal, bog, heavy, ranged, support, objective, summon, boss ...
@export var tags: PackedStringArray = PackedStringArray()
# How high water treats this enemy: normal, resist or ignore.
@export var water_response := "normal"
# Multipliers applied to incoming statuses, e.g. {"slow": 0.5}.
@export var status_resist: Dictionary = {}
# standard: gem + shard roll. none: nothing (objects, summoned props).
# leech: also returns the XP it stole.
@export var drop_profile := "standard"
@export var is_boss := false
@export var tint := Color(1, 1, 1)


func has_tag(t: String) -> bool:
	return tags.has(t)


func to_legacy_dictionary() -> Dictionary:
	return {"hp": base_hp, "dmg": base_damage, "speed": speed,
		"xp": xp_value, "radius": radius}
