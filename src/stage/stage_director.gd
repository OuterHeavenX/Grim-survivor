class_name StageDirector
extends Node2D
# Owns one stage's clock-driven content: the environmental rule's lifecycle,
# the scheduled events, intensity steps and the special-enemy trickle. main.gd
# makes one per stage and frees it on transition, so nothing a stage spawns can
# leak into the next one.
#
# Invariants
# - Placement randomness comes from `rng`, seeded from the run seed and the
#   stage index, so the same seed replays the same event layout.
# - When the boss arrives the director stops scheduling and hands the arena to
#   the boss; rules clear their own pending hazards.
# - cleanup() is idempotent and runs on stage change, restart, death, victory
#   and return to title (main.gd calls it before freeing the run).

const VeilScript := preload("res://src/stage/visibility_veil.gd")
const LayoutScript := preload("res://src/stage/stage_layout.gd")
const MissionScript := preload("res://src/missions/mission_director.gd")
# Static ruins are bucketed on a grid, so a horde of 300 checks only the few
# walls near each body; rule obstacles (few, and some move) stay a list.
const GRID := 256.0

signal event_fired(id: String)

var main = null
var gm = null
var stage_index := 0
var stage_data: StageData
var rule: StageRule = null
var rng := RandomNumberGenerator.new()
var seed_value := 0
var veil: Node2D
var intensity := -1
var boss_phase := false
var obstacles: Array = []   # [{pos, radius, to?}] capsules/circles actors cannot enter
var layout: Node2D = null
var missions: MissionDirector = null
var static_obstacles: Array = []
var _grid := {}

var _fired := {}
var _spawn_next := {}
var _cleaned := false


func setup(p_main, idx: int) -> void:
	main = p_main
	gm = main.gm
	stage_index = idx
	stage_data = gm.CONTENT.stage_at(idx)
	seed_value = gm.stage_rule_seed(idx)
	rng.seed = seed_value
	name = "StageDirector"
	z_index = -3
	veil = VeilScript.new()
	add_child(veil)
	if stage_data:
		layout = LayoutScript.new()
		var stone: Color = main.ground.get("theme").get("stone", Color(0.2, 0.22, 0.28)) if main.get("ground") else Color(0.2, 0.22, 0.28)
		add_child(layout)
		layout.setup(String(stage_data.id), stone)
		for o in layout.obstacles():
			_add_static(o)
	var rd: StageRuleData = stage_data.rule_data() if stage_data else null
	if rd != null and rd.impl != null:
		rule = rd.impl.new()
		rule.director = self
		rule.data = rd
		rule.main = main
		rule.gm = gm
		rule.rng = rng
		rule.name = "Rule"
		add_child(rule)
		rule.setup()
	missions = MissionScript.new()
	missions.setup(main, seed_value)
	add_child(missions)
	for item in (stage_data.special_enemies if stage_data else []):
		var sp := item as StageSpawnData
		if sp:
			_spawn_next[String(sp.enemy_id)] = sp.start_time
	if gm.run_stats:
		gm.run_stats.log_event("stage %d seed %d" % [idx + 1, seed_value])


func intro_text() -> String:
	return rule.data.intro if rule and rule.data else ""


func tick(delta: float) -> void:
	if _cleaned:
		return
	var t: float = gm.run_time
	if boss_phase:
		if rule:
			rule.boss_tick(delta)
		return
	var lvl := _level_at(t)
	if lvl != intensity:
		intensity = lvl
		if rule:
			rule.on_intensity(lvl)
	if stage_data:
		for item in stage_data.events:
			var ev := item as StageEventData
			if ev and not _fired.has(String(ev.id)) and t >= ev.time:
				fire_event(ev)
	if rule:
		rule.tick(delta, t)
	if missions:
		missions.tick(delta, t)
	_special_spawns(t)


func _level_at(t: float) -> int:
	if rule == null or rule.data == null:
		return 0
	var lvl := 0
	for pt in rule.data.phase_times:
		if t >= pt:
			lvl += 1
	return lvl


func fire_event(ev: StageEventData) -> void:
	if _fired.has(String(ev.id)):
		return
	_fired[String(ev.id)] = true
	if main.hud and ev.banner != "":
		main.hud.show_warning(ev.banner)
	if gm.run_stats:
		gm.run_stats.log_event("%s @%d:%02d" % [String(ev.id), int(gm.run_time) / 60, int(gm.run_time) % 60])
	if rule:
		rule.on_event(String(ev.id), ev)
	event_fired.emit(String(ev.id))


func has_fired(id: String) -> bool:
	return _fired.has(id)


func on_boss(boss) -> void:
	boss_phase = true
	if missions:
		missions.on_boss()
	if rule:
		rule.on_boss(boss)


func emit_element(kind: String, pos: Vector2, radius: float, source: String) -> void:
	# Elemental events (a fire blast, a frost ring) that a stage may react to.
	if rule and not _cleaned:
		rule.on_element(kind, pos, radius, source)


func on_enemy_died(e) -> void:
	if missions and not _cleaned:
		missions.on_enemy_died(e)
	if rule and not _cleaned:
		rule.on_enemy_died(e)


func _special_spawns(t: float) -> void:
	if stage_data == null:
		return
	for item in stage_data.special_enemies:
		var sp := item as StageSpawnData
		if sp == null or t < sp.start_time or t > sp.end_time:
			continue
		var key := String(sp.enemy_id)
		if t < float(_spawn_next.get(key, 0.0)):
			continue
		_spawn_next[key] = t + sp.interval
		if main.count_alive(key) >= sp.max_alive or main._enemy_count() >= main.MAX_ENEMIES:
			continue
		main._spawn_enemy(key, main._ring_pos())


# --- obstacles -------------------------------------------------------------

func add_obstacle(o: Dictionary) -> void:
	obstacles.append(o)


func remove_obstacle(o: Dictionary) -> void:
	obstacles.erase(o)


func has_obstacles() -> bool:
	return not obstacles.is_empty() or not static_obstacles.is_empty()


func _add_static(o: Dictionary) -> void:
	var idx := static_obstacles.size()
	static_obstacles.append(o)
	var a: Vector2 = o["pos"]
	var b: Vector2 = o.get("to", a)
	# Pad by the largest body we expect to resolve (bosses are ~60).
	var pad: float = float(o["radius"]) + 70.0
	var lo := Vector2(minf(a.x, b.x) - pad, minf(a.y, b.y) - pad)
	var hi := Vector2(maxf(a.x, b.x) + pad, maxf(a.y, b.y) + pad)
	for gx in range(floori(lo.x / GRID), floori(hi.x / GRID) + 1):
		for gy in range(floori(lo.y / GRID), floori(hi.y / GRID) + 1):
			var key := Vector2i(gx, gy)
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(idx)


func resolve(pos: Vector2, radius: float) -> Vector2:
	# Push a body out of every obstacle it overlaps: the static ruins in its
	# grid cell, then the stage rule's own few obstacles.
	var p := pos
	if not static_obstacles.is_empty():
		var cell: Array = _grid.get(Vector2i(floori(p.x / GRID), floori(p.y / GRID)), [])
		for i in cell:
			p = _push_out(p, radius, static_obstacles[i])
	for o in obstacles:
		p = _push_out(p, radius, o)
	return p


func _push_out(p: Vector2, radius: float, o: Dictionary) -> Vector2:
	var r: float = float(o["radius"]) + radius
	var closest: Vector2 = o["pos"]
	if o.has("to"):
		var a: Vector2 = o["pos"]
		var ab: Vector2 = o["to"] - a
		var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		closest = a + ab * tt
	var d := p - closest
	var dl := d.length()
	if dl < r:
		return closest + (d / dl if dl > 0.01 else Vector2.RIGHT) * r
	return p


func blocked(pos: Vector2, radius: float) -> bool:
	return resolve(pos, radius).distance_to(pos) > 0.5


# --- cleanup and debug ---------------------------------------------------

func cleanup() -> void:
	if _cleaned:
		return
	_cleaned = true
	if missions:
		missions.cleanup()
	if rule:
		rule.cleanup()
	obstacles.clear()
	static_obstacles.clear()
	_grid.clear()
	for g in ["stage_hazards", "stage_objects", "objectives"]:
		for n in get_tree().get_nodes_in_group(g):
			n.remove_from_group(g)
			n.queue_free()
	gm.clear_stage_mods()
	var p = main.player if main else null
	if p and is_instance_valid(p):
		p.set("push", Vector2.ZERO)


func debug_state() -> Dictionary:
	var d := {
		"stage": stage_index, "seed": seed_value, "time": gm.run_time,
		"intensity": intensity, "boss_phase": boss_phase, "fired": _fired.keys(),
		"stage_hazards": get_tree().get_nodes_in_group("stage_hazards").size(),
	}
	if rule:
		d["rule"] = rule.debug_state()
	if missions:
		d["missions"] = missions.debug_state()
	return d


func debug_advance(seconds: float) -> void:
	# Jumps the stage clock. Events between now and then fire in order on the
	# next tick, exactly as they would have.
	gm.run_time = minf(gm.run_time + seconds, gm.RUN_DURATION - 0.05)


func debug_trigger_event(id := "") -> bool:
	if stage_data == null:
		return false
	for item in stage_data.events:
		var ev := item as StageEventData
		if ev and (id == "" or String(ev.id) == id) and not _fired.has(String(ev.id)):
			gm.run_time = maxf(gm.run_time, ev.time)
			fire_event(ev)
			return true
	return false
