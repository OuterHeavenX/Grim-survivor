class_name GameModifiers
extends RefCounted
# Run-scoped stat modifiers keyed by source, so a boon, a curse, a relic and a
# marsh slow can all touch move speed without knowing about each other, and
# each can be removed by name when it ends. Sources starting with "stage:" are
# dropped on every stage transition; everything else lasts the run.

# Multiplicative stats: factors are multiplied together.
const MULT_STATS := ["damage", "speed", "damage_taken", "magnet", "cooldown",
	"knockback", "xp", "objective_speed", "max_hp"]
# Additive stats: values are summed.
const ADD_STATS := ["armor", "pierce", "crit_chance", "regen"]
const KNOWN_STATS := MULT_STATS + ADD_STATS

# Hard clamps on the composed result. Stacking is bounded here once rather
# than trusted to every caller.
const CLAMP := {
	"damage": Vector2(0.25, 4.0),
	"speed": Vector2(0.35, 2.0),
	"damage_taken": Vector2(0.4, 2.0),
	"magnet": Vector2(0.5, 5.0),
	"cooldown": Vector2(0.45, 2.0),
	"knockback": Vector2(0.0, 3.0),
	"xp": Vector2(0.5, 3.0),
	"objective_speed": Vector2(0.5, 3.0),
	"max_hp": Vector2(0.5, 3.0),
	"armor": Vector2(0.0, 20.0),
	"pierce": Vector2(0.0, 10.0),
	"crit_chance": Vector2(0.0, 0.6),
	"regen": Vector2(0.0, 10.0),
}

var _by_source := {}


func set_mod(source: String, stat: String, value: float) -> void:
	assert(KNOWN_STATS.has(stat), "unknown modifier stat " + stat)
	if not _by_source.has(source):
		_by_source[source] = {}
	_by_source[source][stat] = value


func set_mods(source: String, mods: Dictionary) -> void:
	for k in mods:
		set_mod(source, String(k), float(mods[k]))


func clear_source(source: String) -> void:
	_by_source.erase(source)


func clear_prefix(prefix: String) -> void:
	for s in _by_source.keys():
		if String(s).begins_with(prefix):
			_by_source.erase(s)


func clear_all() -> void:
	_by_source.clear()


func has_source(source: String) -> bool:
	return _by_source.has(source)


func get_mod(source: String, stat: String, fallback := 0.0) -> float:
	return float(_by_source.get(source, {}).get(stat, fallback))


func mult(stat: String) -> float:
	var v := 1.0
	for s in _by_source:
		var m: Dictionary = _by_source[s]
		if m.has(stat):
			v *= float(m[stat])
	var c: Vector2 = CLAMP.get(stat, Vector2(0.0, 100.0))
	return clampf(v, c.x, c.y)


func add(stat: String) -> float:
	var v := 0.0
	for s in _by_source:
		var m: Dictionary = _by_source[s]
		if m.has(stat):
			v += float(m[stat])
	var c: Vector2 = CLAMP.get(stat, Vector2(-100.0, 100.0))
	return clampf(v, c.x, c.y)


func sources() -> Array:
	return _by_source.keys()
