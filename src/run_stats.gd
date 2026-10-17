class_name RunStats
extends RefCounted
# What happened in a run, for the post-run report. Everything is recorded at
# the point it happens (a hit, a heal, a kill) rather than reconstructed from
# end state, so the report cannot drift from what the player saw.

var run_seed := 0
var damage_by_source := {}
var damage_taken := 0.0
var damage_taken_by_source := {}
var hits_taken := 0
var healing := 0.0
var kills_by_enemy := {}
var elites_killed := 0
var bosses_killed := 0
var pickups := {"gems": 0, "shards": 0, "relics": 0, "chests": 0, "altars": 0}
var stage_events: Array[String] = []
# One entry per stage reached: {stage, name, boss_time, cleared, time}.
var stages: Array = []
var relics: Array[String] = []
var evolved: Array[String] = []
var completion_time := 0.0
var victory := false
var stages_cleared := 0
var interaction_procs := {}


func add_damage(source: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var key := source if source != "" else "other"
	damage_by_source[key] = float(damage_by_source.get(key, 0.0)) + amount


func add_damage_taken(source: String, amount: float) -> void:
	if amount <= 0.0:
		return
	damage_taken += amount
	hits_taken += 1
	var key := source if source != "" else "contact"
	damage_taken_by_source[key] = float(damage_taken_by_source.get(key, 0.0)) + amount


func add_healing(amount: float) -> void:
	if amount > 0.0:
		healing += amount


func add_kill(etype: String, elite: bool, boss: bool) -> void:
	kills_by_enemy[etype] = int(kills_by_enemy.get(etype, 0)) + 1
	if elite:
		elites_killed += 1
	if boss:
		bosses_killed += 1


func add_pickup(kind: String, n := 1) -> void:
	pickups[kind] = int(pickups.get(kind, 0)) + n


func add_proc(kind: String) -> void:
	interaction_procs[kind] = int(interaction_procs.get(kind, 0)) + 1


# Stalls the watchdog recovered from this run, by kind (shown on the end
# screen so a player can report exactly what happened).
var recoveries: Array[String] = []


func log_event(text: String) -> void:
	# Bounded: a long run fires many events and the report shows the last few.
	stage_events.append(text)
	if stage_events.size() > 64:
		stage_events.remove_at(0)


func begin_stage(idx: int, stage_name: String) -> void:
	stages.append({"stage": idx, "name": stage_name, "boss_time": -1.0, "cleared": false})


func boss_spawned(t: float) -> void:
	if not stages.is_empty():
		stages[-1]["boss_spawn"] = t


func stage_cleared(t: float) -> void:
	if stages.is_empty():
		return
	var s: Dictionary = stages[-1]
	s["cleared"] = true
	s["time"] = t
	if s.has("boss_spawn"):
		s["boss_time"] = maxf(0.0, t - float(s["boss_spawn"]))


func finish(total_time: float, won: bool, cleared: int, evolved_map: Dictionary) -> void:
	completion_time = total_time
	victory = won
	stages_cleared = cleared
	evolved.clear()
	for k in evolved_map:
		if bool(evolved_map[k]):
			evolved.append(String(k))


func top_damage(n := 6) -> Array:
	# [[source, amount], ...] largest first.
	var rows: Array = []
	for k in damage_by_source:
		rows.append([k, float(damage_by_source[k])])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	return rows.slice(0, n)


func total_damage() -> float:
	var t := 0.0
	for k in damage_by_source:
		t += float(damage_by_source[k])
	return t


func total_kills() -> int:
	var t := 0
	for k in kills_by_enemy:
		t += int(kills_by_enemy[k])
	return t
