class_name PassiveData
extends Resource

@export var id: StringName
@export var display_name := ""
@export_range(1, 99, 1) var max_level := 5
@export_multiline var description := ""


func to_legacy_dictionary() -> Dictionary:
	return {
		"name": display_name,
		"max": max_level,
		"desc": description,
	}
