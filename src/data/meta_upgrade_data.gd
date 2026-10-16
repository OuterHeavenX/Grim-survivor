class_name MetaUpgradeData
extends Resource

@export var id: StringName
@export var display_name := ""
@export var description := ""
@export var costs: PackedInt32Array = PackedInt32Array()
@export var per_rank := 1.0
@export var fmt := ""
@export var short_fmt := ""
@export var max_rank := 5
# Which GameManager stat the rank feeds (damage, max_hp, speed, magnet,
# revives, xp), so the catalog can check every track does something.
@export var hook := ""


func to_legacy_dictionary() -> Dictionary:
	return {"id": String(id), "name": display_name, "desc": description,
		"costs": Array(costs), "fmt": fmt, "short": short_fmt}
