class_name BossData
extends Resource
# A stage boss: a body (an EnemyData) plus phases, attacks and the attack
# budget that keeps its patterns from overlapping into unavoidable damage.

@export var id: StringName
@export var display_name := ""
@export var base_enemy: StringName
@export var hp_mult := 1.0
@export var aura := Color(1, 0.5, 0.2)
@export var tint := Color(1, 1, 1)
@export var phases: Array[Resource] = []
@export var cast_gap := 5.5
@export var min_cast_gap := 2.2
# Below this fraction the boss casts faster. Faster, never wider: enrage
# shortens gaps but leaves the hazard budget alone.
@export var enrage_threshold := 0.3
@export var enrage_cadence := 0.75
# Optional last-gasp escalation (the Sovereign). 0 disables it.
@export var final_stand_threshold := 0.0
@export var final_stand_cadence := 0.85
@export var max_hazards := 18
@export var min_safe_fraction := 0.35
@export var min_warn := 0.65
@export var summon_enemy: StringName = &"skeleton"
@export var summon_interval := 9.0
@export var summon_count := 2
@export var reward_tags: PackedStringArray = PackedStringArray()
@export var intro_text := ""
@export var defeat_text := ""
# Legacy bosses keep the single signature move they had before this system.
@export var legacy := false


func phase(i: int) -> BossPhaseData:
	if i < 0 or i >= phases.size():
		return null
	return phases[i] as BossPhaseData


func all_attacks() -> Array:
	var out: Array = []
	for p in phases:
		var ph := p as BossPhaseData
		if ph == null:
			continue
		out.append_array(ph.attacks)
		out.append_array(ph.passives)
	return out
