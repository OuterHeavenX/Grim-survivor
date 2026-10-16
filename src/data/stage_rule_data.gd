class_name StageRuleData
extends Resource
# Tuning for a stage's environmental rule. impl is the StageRule script; the
# numbers it uses come from here so a stage can be retuned without code.

@export var id: StringName
@export var impl: Script
# One short sentence naming the rule, shown on the stage card.
@export var intro := ""
# Stage-time seconds where the rule's intensity steps up (timeline beats).
@export var phase_times: PackedFloat32Array = PackedFloat32Array()
# No stage hazard spawns before this many seconds: the stage banner, the
# five-second intermission and an opening breath come first.
@export var grace := 8.0
@export var warn_time := 0.9
@export var max_hazards := 24
# Share of the area around the player that must stay free of threats, and how
# far away a safe spot may be (roughly what one warning lets you walk).
@export var min_safe_fraction := 0.45
@export var safe_reach := 230.0
@export var color := Color(1, 0.5, 0.2)
@export var params: Dictionary = {}


func p(key: String, fallback: Variant) -> Variant:
	return params.get(key, fallback)
