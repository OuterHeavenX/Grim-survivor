class_name RelicData
extends Resource
# A run relic: a rule-changing item chosen at a stage's reward altar. The only
# persistent state is whether it has been discovered.

@export var id: StringName
@export var display_name := ""
@export var rarity := "common"
@export var tags: PackedStringArray = PackedStringArray()
@export var description := ""
# Stat modifiers while held. Multiplicative stats (damage, speed, ...) are
# factors; additive ones (armor, pierce, crit) are added. See GameManager.
@export var modifiers: Dictionary = {}
# Optional RelicEffect script for behaviour a stat cannot express.
@export var effect: Script
# Only offered if the run holds one of these weapons (empty = always).
@export var requires_weapons: PackedStringArray = PackedStringArray()
@export var icon_color := Color(1, 0.8, 0.4)
@export var discovered_by_default := true
# Stage whose boss reveals this relic the first time it falls.
@export var discover_stage: StringName
