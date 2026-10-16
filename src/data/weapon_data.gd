class_name WeaponData
extends Resource

@export var id: StringName
@export var display_name := ""
@export_range(1, 99, 1) var max_level := 5
@export_multiline var description := ""
@export_multiline var upgrade_description := ""
@export var evolution_passive_id: StringName
@export var evolution_name := ""
@export_multiline var evolution_description := ""


func to_legacy_weapon() -> Dictionary:
	return {
		"name": display_name,
		"max": max_level,
		"desc": description,
		"up": upgrade_description,
	}


func to_legacy_evolution() -> Dictionary:
	return {
		"passive": String(evolution_passive_id),
		"name": evolution_name,
		"desc": evolution_description,
	}
