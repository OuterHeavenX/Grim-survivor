extends StageRule
# The Sunken Road: The Procession.
#
# A lantern convoy creeps along a ruined road. Inside its light the player
# sees further and takes less damage ("stage:lantern"). Outside, the dark
# closes in. Pushing ahead of the convoy finds treasure but draws ambushes.
#
# Anti-soft-lock invariants
# - The convoy only moves along the road, which lies inside the arena.
# - It waits whenever the player falls more than wait_dist behind, so it can
#   never be lost; an off-screen indicator also points at it.
# - Roadblocks pause it until their wardens fall OR roadblock_timeout passes.
# - Shrines are optional and never on the road.
# - The bridge hold has a time limit; failing it only forfeits the reward.
# - At 5:00 the boss fight happens wherever the convoy is: the gate is the
#   convoy's position, with a soft ring that eases the player back in.

const ConvoyScript := preload("res://src/stage/convoy.gd")
const ShrineScript := preload("res://src/stage/shrine.gd")

var road: PackedVector2Array = PackedVector2Array()
var road_len := 0.0
var convoy = null
var convoy_s := 0.0
var paused_for := ""             # "", "roadblock", "bridge"
var _roadblock_at: Array = []    # convoy distances where roadblocks stand
var _roadblock_obj = null
var _roadblock_t := 0.0
var _ambush_cd := 0.0
var _treasure_cd := 0.0
var _shrines_made := false
var _bridge = null
var _bridge_waves := 0
var _bridge_wave_t := 0.0
var _gate_center := Vector2.ZERO
var gate_active := false


func setup() -> void:
	_make_road()
	convoy = ConvoyScript.new()
	convoy.rule = self
	convoy.position = road[0]
	add_stage_object(convoy)
	var n: int = int(p("roadblocks", 2))
	for i in n:
		_roadblock_at.append(road_len * (0.22 + 0.22 * float(i)))


func _make_road() -> void:
	# South to north through the start, gently winding; never near the walls.
	var pts := PackedVector2Array()
	var phase := rng.randf() * TAU
	for i in 10:
		var y := lerpf(420.0, -1320.0, float(i) / 9.0)
		pts.append(Vector2(sin(phase + float(i) * 0.8) * 260.0, y))
	road = pts
	road_len = 0.0
	for i in road.size() - 1:
		road_len += road[i].distance_to(road[i + 1])


func road_point(s: float) -> Vector2:
	var left := clampf(s, 0.0, road_len)
	for i in road.size() - 1:
		var seg := road[i].distance_to(road[i + 1])
		if left <= seg:
			return road[i].lerp(road[i + 1], left / maxf(seg, 0.001))
		left -= seg
	return road[road.size() - 1]


func road_progress(pos: Vector2) -> float:
	# Distance along the road of the closest road point.
	var best := 0.0
	var bd := INF
	var acc := 0.0
	for i in road.size() - 1:
		var a := road[i]
		var b := road[i + 1]
		var ab := b - a
		var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := pos.distance_to(a + ab * t)
		if d < bd:
			bd = d
			best = acc + ab.length() * t
		acc += ab.length()
	return best


func convoy_pos() -> Vector2:
	return convoy.global_position if convoy and is_instance_valid(convoy) else road_point(convoy_s)


func in_light(pos: Vector2) -> bool:
	return pos.distance_to(convoy_pos()) <= float(p("aura", 270.0))


func convoy_should_move() -> bool:
	if paused_for != "" or stopped:
		return false
	# Waits for a player who has fallen behind, so it can never be lost.
	if ppos().distance_to(convoy_pos()) > float(p("wait_dist", 900.0)):
		return false
	return convoy_s < road_len


func tick(delta: float, t: float) -> void:
	if stopped:
		_tick_gate(delta)
		return
	if convoy_should_move():
		convoy_s = minf(road_len, convoy_s + float(p("convoy_speed", 9.0)) * delta)
	convoy.global_position = road_point(convoy_s)
	_apply_light()
	_tick_ahead(delta)
	if intensity >= 1 and intensity < 3:
		_tick_roadblocks(delta)
	if intensity >= 2 and not _shrines_made:
		_make_shrines()
	if _bridge:
		_tick_bridge(delta)


func _apply_light() -> void:
	var lit := in_light(ppos())
	if lit:
		gm.mods.set_mod("stage:lantern", "damage_taken", float(p("aura_armor", 0.82)))
		director.veil.set_veil(0.15, 420.0)
	else:
		gm.mods.clear_source("stage:lantern")
		director.veil.set_veil(float(p("dark", 0.55)), 300.0)


func _tick_ahead(delta: float) -> void:
	_ambush_cd = maxf(0.0, _ambush_cd - delta)
	_treasure_cd = maxf(0.0, _treasure_cd - delta)
	var ahead := road_progress(ppos()) - convoy_s
	if ahead < float(p("ahead_dist", 520.0)) or in_grace(gm.run_time):
		return
	if _treasure_cd <= 0.0:
		_treasure_cd = 30.0
		_drop_treasure()
	if _ambush_cd <= 0.0:
		_ambush_cd = float(p("ambush_cd", 18.0))
		announce("AMBUSH")
		var pool: Array = gm.stage_data()["pool"]
		for i in 4:
			if main._enemy_count() >= main.MAX_ENEMIES:
				break
			main._spawn_enemy(str(pool[i % pool.size()]), ring_point(ppos(), 260.0, 360.0))


func _drop_treasure() -> void:
	# Treasure off the road ahead: shards, and sometimes a mimic sitting
	# beside it. Never a mandatory reward.
	var s := minf(road_len, road_progress(ppos()) + 220.0)
	var at := clamp_arena(road_point(s) + Vector2(rng.randf_range(-180.0, 180.0), 0.0))
	for i in 4:
		main.spawn_shard(at + Vector2.from_angle(rng.randf() * TAU) * 18.0, 1)
	main.spawn_gem(at, 5)
	if int(p("mimics", 1)) > 0 and main.count_alive("mimic") < int(p("mimics", 1)) and rng.randf() < 0.5:
		main._spawn_enemy("mimic", clamp_arena(at + Vector2(90, 0)))


func _tick_roadblocks(delta: float) -> void:
	if paused_for == "roadblock":
		_roadblock_t += delta
		var cleared := true
		for w in _roadblock_obj.wardens:
			if is_instance_valid(w) and not w.dead:
				cleared = false
		if _roadblock_obj.objective and is_instance_valid(_roadblock_obj.objective):
			_roadblock_obj.objective.progress = float(_roadblock_obj.killed())
		if cleared or _roadblock_t >= float(p("roadblock_timeout", 40.0)):
			_clear_roadblock(cleared)
		return
	if not _roadblock_at.is_empty() and convoy_s >= float(_roadblock_at[0]):
		_roadblock_at.pop_front()
		_start_roadblock()


func _start_roadblock() -> void:
	paused_for = "roadblock"
	_roadblock_t = 0.0
	announce("ROADBLOCK")
	var at := road_point(convoy_s + 120.0)
	var rb := Roadblock.new()
	rb.position = at
	add_stage_object(rb)
	_roadblock_obj = rb
	for i in int(p("wardens", 2)):
		var w = main._spawn_enemy("shield_bearer", clamp_arena(at + Vector2((float(i) - 0.5) * 120.0, -40.0)))
		if w:
			rb.wardens.append(w)
	var obj := StageObjective.new()
	obj.kind = "manual"
	obj.label = "CLEAR THE ROADBLOCK"
	obj.goal = float(rb.wardens.size())
	obj.time_limit = float(p("roadblock_timeout", 40.0))
	obj.position = at
	add_stage_object(obj)
	rb.objective = obj


func _clear_roadblock(by_force: bool) -> void:
	paused_for = ""
	announce("THE ROAD IS CLEAR" if by_force else "THE WARDENS WITHDRAW")
	if _roadblock_obj and is_instance_valid(_roadblock_obj):
		if _roadblock_obj.objective and is_instance_valid(_roadblock_obj.objective):
			_roadblock_obj.objective.state = "done"
		_roadblock_obj.queue_free()
	_roadblock_obj = null


func _make_shrines() -> void:
	_shrines_made = true
	var kinds := ["blood", "haste", "greed"]
	for i in int(p("shrines", 3)):
		var s := minf(road_len, convoy_s + 260.0 + 220.0 * float(i))
		var side := -1.0 if i % 2 == 0 else 1.0
		var sh = ShrineScript.new()
		sh.rule = self
		sh.kind = kinds[i % kinds.size()]
		sh.position = clamp_arena(road_point(s) + Vector2(side * 360.0, 0.0), 120.0)
		add_stage_object(sh)
	announce("SHRINES OFF THE ROAD")


func on_event(id: String, ev: StageEventData) -> void:
	super.on_event(id, ev)
	if id != "broken_bridge":
		return
	if paused_for == "roadblock":
		_clear_roadblock(false)
	paused_for = "bridge"
	var obj := StageObjective.new()
	obj.kind = "hold"
	obj.label = "HOLD THE BRIDGE"
	obj.radius = float(p("bridge_radius", 170.0)) * (1.3 if gm.has_relic("road_lantern") else 1.0)
	obj.goal = float(p("bridge_time", 26.0))
	obj.time_limit = ev.duration - 1.0
	obj.position = convoy_pos() + Vector2(0, -60)
	obj.completed.connect(_on_bridge_done)
	obj.failed.connect(_on_bridge_failed)
	add_stage_object(obj)
	_bridge = obj
	_bridge_waves = 0
	_bridge_wave_t = 0.0


func _tick_bridge(delta: float) -> void:
	if not is_instance_valid(_bridge) or not _bridge.is_active():
		return
	_bridge_wave_t -= delta
	if _bridge_wave_t <= 0.0 and _bridge_waves < int(p("bridge_waves", 3)):
		_bridge_waves += 1
		_bridge_wave_t = 9.0
		var pool: Array = gm.stage_data()["pool"]
		for i in int(p("wave_size", 5)):
			if main._enemy_count() >= main.MAX_ENEMIES:
				break
			main._spawn_enemy(str(pool[i % pool.size()]), ring_point(_bridge.global_position, 380.0, 460.0))


func _on_bridge_done(_o) -> void:
	paused_for = ""
	announce("THE CONVOY CROSSES")
	main.spawn_chest(_bridge.global_position)
	if gm.run_stats:
		gm.run_stats.log_event("bridge held")


func _on_bridge_failed(_o) -> void:
	paused_for = ""
	announce("THE BRIDGE IS LOST")


func on_boss(boss) -> void:
	super.on_boss(boss)
	paused_for = ""
	for o in get_tree().get_nodes_in_group("objectives"):
		o.state = "done"
	_gate_center = convoy_pos()
	gate_active = true
	gm.mods.clear_source("stage:lantern")
	director.veil.set_veil(0.1, 520.0)


func _tick_gate(_delta: float) -> void:
	# The convoy's lanterns ring the boss arena. Straying outside eases you
	# back in; it never blocks or hurts.
	if not gate_active:
		return
	var pl = player()
	if pl == null:
		return
	var d: Vector2 = pl.global_position - _gate_center
	var r: float = float(p("gate_radius", 680.0))
	if d.length() > r:
		pl.add_push(-d.normalized() * 120.0)


func boss_tick(delta: float) -> void:
	_tick_gate(delta)


func cleanup() -> void:
	super.cleanup()
	gate_active = false
	if gm:
		gm.mods.clear_source("stage:lantern")
	if director and director.veil:
		director.veil.set_veil(0.0)


func debug_state() -> Dictionary:
	var d := super.debug_state()
	d["convoy_s"] = convoy_s
	d["road_len"] = road_len
	d["paused"] = paused_for
	d["roadblocks_left"] = _roadblock_at.size()
	return d


class Roadblock extends Node2D:
	var wardens: Array = []
	var objective = null

	func _ready() -> void:
		z_index = 1

	func killed() -> int:
		var n := 0
		for w in wardens:
			if not is_instance_valid(w) or w.dead:
				n += 1
		return n

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for i in 5:
			var x := -100.0 + 50.0 * float(i)
			draw_line(Vector2(x - 18, 14), Vector2(x + 18, -14), Color(0.45, 0.32, 0.2), 8.0)
			draw_line(Vector2(x - 18, -14), Vector2(x + 18, 14), Color(0.45, 0.32, 0.2), 8.0)
