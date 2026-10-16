class_name BossAttackData
extends Resource
# Tuning for one boss attack. The implementation is a BossAttack script, so a
# shape of attack (a volley, a ring with a gap) is written once and reused by
# several bosses with different numbers.

@export var id: StringName
@export var impl: Script
# Seconds of telegraph before the attack lands. Clamped up to the boss's
# min_warn at runtime, so data cannot make an attack unreadable.
@export var warn := 0.85
@export var cooldown := 0.0
# Hazard slots this attack may occupy at once; checked against the boss's
# max_hazards so overlapping attacks cannot fill the arena.
@export var budget_cost := 3
@export var weight := 1.0
# A major attack opens a punish window on bosses that have one.
@export var major := false
@export var movement_pressure := false
@export var positional := false
# A passive runs for the whole phase (armour, trails, pull) instead of casting.
@export var passive := false
@export var params: Dictionary = {}
