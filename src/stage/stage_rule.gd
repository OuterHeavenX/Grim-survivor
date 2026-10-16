class_name StageRule
extends Node2D
# Base for a stage's environmental rule. A rule is a child of the
# StageDirector: it owns whatever it spawns (hazards via the director's caps,
# props in "stage_objects") and must leave nothing behind after cleanup().
#
# Lifecycle: setup() -> tick() every frame of the stage -> on_intensity() at
# each timeline beat -> on_event() for scheduled events -> on_boss() when the
# boss arrives (stop scheduling, clear pending threats) -> boss_tick() during
# the fight -> cleanup().

var director: StageDirector
var data: StageRuleData
var main = null
var gm = null
var rng: RandomNumberGenerator
var intensity := 0
var event_active := false
var stopped := false


func setup() -> void:
	pass


func tick(_delta: float, _t: float) -> void:
	pass


func on_intensity(level: int) -> void:
	intensity = level


func on_event(_id: String, _ev: StageEventData) -> void:
	event_active = true


func on_boss(_boss) -> void:
	# Default contract: no new patterns, and pending stage threats vanish so
	# the boss's attack budget starts from an empty arena.
	stopped = true
	event_active = false
	clear_stage_hazards()


func boss_tick(_delta: float) -> void:
	pass


func on_element(_kind: String, _pos: Vector2, _radius: float, _source: String) -> void:
	pass


func on_enemy_died(_e) -> void:
	pass


func cleanup() -> void:
	stopped = true
	clear_stage_hazards()


func debug_state() -> Dictionary:
	return {"intensity": intensity, "event": event_active, "stopped": stopped}


# --- helpers ---------------------------------------------------------------

func player():
	return main.player if main and main.player and is_instance_valid(main.player) else null


func ppos() -> Vector2:
	var p = player()
	return p.global_position if p else Vector2.ZERO


func pvel() -> Vector2:
	var p = player()
	return p.velocity if p else Vector2.ZERO


func p(key: String, fallback: Variant) -> Variant:
	return data.p(key, fallback) if data else fallback


func in_grace(t: float) -> bool:
	return t < data.grace or main.intermission > 0.0


func scaled(base: float) -> float:
	# Stage hazards follow the same damage curve as the horde.
	return base * gm.enemy_dmg_mult(gm.stage, gm.run_time)


func source_tag() -> String:
	return "stage:" + String(data.id)


func stage_hazard_count() -> int:
	return get_tree().get_nodes_in_group("stage_hazards").size()


func room_for(n: int) -> bool:
	return stage_hazard_count() + n <= data.max_hazards


func pattern_ok(shapes: Array, center := Vector2.INF) -> bool:
	var c := ppos() if center == Vector2.INF else center
	return SafeSpace.pattern_ok(get_tree(), c, shapes, 420.0, data.min_safe_fraction, data.safe_reach)


func spawn_hazard(shape: Dictionary, warn: float, active: float, dmg: float,
		col := Color(-1, 0, 0)) -> TimedHazard:
	var h := TimedHazard.new()
	h.setup(shape, maxf(warn, data.warn_time), active, dmg, data.color if col.r < 0.0 else col,
		source_tag(), "stage")
	main.add_hazard_node(h)
	return h


func add_stage_object(n: Node) -> void:
	n.add_to_group("stage_objects")
	main.run.add_child(n)


func clear_stage_hazards() -> void:
	for h in get_tree().get_nodes_in_group("stage_hazards"):
		h.remove_from_group("stage_hazards")
		h.remove_from_group("hazards")
		h.remove_from_group("timed_hazards")
		h.queue_free()


func clamp_arena(v: Vector2, margin := 40.0) -> Vector2:
	return main.clamp_arena(v, margin)


func ring_point(center: Vector2, rmin: float, rmax: float) -> Vector2:
	return clamp_arena(center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(rmin, rmax))


func announce(text: String) -> void:
	if main.hud:
		main.hud.show_warning(text)
