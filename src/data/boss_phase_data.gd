class_name BossPhaseData
extends Resource

# Health fraction at or below which this phase begins. Phase one is 1.0.
@export var threshold := 1.0
@export var title := ""
@export var banner := ""
# Multiplies the gap between casts; below 1 is faster.
@export var cadence := 1.0
@export var attacks: Array[Resource] = []
@export var passives: Array[Resource] = []
