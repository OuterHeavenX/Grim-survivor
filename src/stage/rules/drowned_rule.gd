extends StageRule
# The Drowned Reach: The Dead Tide.
#
# Low tide bares the seabed and its treasure caches. High tide brings
# spectral currents: visible bands of moving chevrons that carry whatever is
# inside them. Strength is tuned per kind (player < enemies < pickups) and a
# current only ever adds to movement; the player's own walking always wins
# (player.gd caps outside pushes below walking speed).
#
# Caches open once (stand on one for cache_open seconds at low tide) and stay
# open through every later tide. From 3:00 opening one wakes drowned foes.
# 4:15 Dead Tide: the currents hold, reverse twice (with a warning), and
# ghost ships cross the fight firing clearly marked broadsides. At 5:00 the
# water forms a ring current around the boss arena.

const CacheScript := preload("res://src/stage/tide_cache.gd")

var tide := "low"
var currents: Array = []        # [{from, to, width, sign}]
var _tide_t := 0.0
var _cycles := false
var _dead_tide := false
var _reversals: Array = []
var _rev_warned := false
var _ship_next := 0.0
var _ring_center := Vector2.ZERO
var ring_active := false
var _field: Node2D


func setup() -> void:
	for i in int(p("caches", 6)):
		var c = CacheScript.new()
		c.rule = self
		c.position = Vector2(rng.randf_range(-1200.0, 1200.0), rng.randf_range(-1200.0, 1200.0))
		if i < 2:
			c.position = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(300.0, 480.0)
		add_stage_object(c)
	_field = TideField.new()
	_field.rule = self
	add_stage_object(_field)


func caches() -> Array:
	return get_tree().get_nodes_in_group("tide_caches")


func low_tide() -> bool:
	return tide == "low"


func set_tide(state: String) -> void:
	tide = state
	_tide_t = 0.0
	match state:
		"warning":
			announce("THE TIDE RUSHES IN")
			_lay_currents()
		"high":
			pass
		"low":
			currents.clear()


func _lay_currents() -> void:
	# Bands across the player's area, alternating direction, with calm water
	# between them.
	currents.clear()
	var a := rng.randf() * PI
	var u := Vector2.from_angle(a)
	var nrm := Vector2(-u.y, u.x)
	var w: float = float(p("lane_width", 150.0))
	var n: int = int(p("lanes", 3))
	for i in n:
		var off := (float(i) - float(n - 1) * 0.5) * (w + 190.0)
		var c := ppos() + nrm * off
		currents.append({"from": c - u * 800.0, "to": c + u * 800.0, "width": w,
			"sign": 1.0 if i % 2 == 0 else -1.0})


func current_at(pos: Vector2) -> Vector2:
	# Direction of the current at pos (unit or zero).
	if tide != "high":
		return Vector2.ZERO
	for c in currents:
		if HazardShape.seg_dist(c["from"], c["to"], pos) <= float(c["width"]) * 0.5:
			return (Vector2(c["to"]) - Vector2(c["from"])).normalized() * float(c["sign"])
	return Vector2.ZERO


func reverse_currents() -> void:
	for c in currents:
		c["sign"] = -float(c["sign"])


func on_event(id: String, ev: StageEventData) -> void:
	super.on_event(id, ev)
	if id != "dead_tide":
		return
	_dead_tide = true
	if tide != "high":
		set_tide("warning")
	var t0: float = gm.run_time
	_reversals = [t0 + 9.0, t0 + 18.0]
	_ship_next = t0 + 3.0


func on_intensity(level: int) -> void:
	super.on_intensity(level)
	if level >= 1 and not _cycles:
		_cycles = true
		_tide_t = 0.0


func tick(delta: float, t: float) -> void:
	if stopped:
		return
	_tide_t += delta
	if _dead_tide:
		if tide == "warning" and _tide_t >= 2.0:
			set_tide("high")
		if not _reversals.is_empty() and not _rev_warned and t >= float(_reversals[0]) - 1.5:
			_rev_warned = true
			announce("THE CURRENTS TURN")
		if not _reversals.is_empty() and t >= float(_reversals[0]):
			_reversals.pop_front()
			_rev_warned = false
			reverse_currents()
		if t >= _ship_next:
			_ship_next = t + float(p("ship_interval", 9.0))
			sail_ship()
	elif _cycles:
		match tide:
			"low":
				if _tide_t >= float(p("low_len", 22.0)):
					set_tide("warning")
			"warning":
				if _tide_t >= 2.0:
					set_tide("high")
			"high":
				if _tide_t >= float(p("high_len", 10.0)):
					set_tide("low")
	apply_currents()


func apply_currents() -> void:
	if tide != "high":
		return
	var pl = player()
	if pl:
		var d := current_at(pl.global_position)
		if d != Vector2.ZERO:
			pl.add_push(d * float(p("player_push", 95.0)))
	for e in get_tree().get_nodes_in_group("enemies"):
		var d2 := current_at(e.global_position)
		if d2 != Vector2.ZERO:
			e.push += d2 * float(p("enemy_push", 120.0))
	if gm.has_relic("tide_lodestone"):
		return
	var dt := get_physics_process_delta_time()
	for g in get_tree().get_nodes_in_group("gems") + get_tree().get_nodes_in_group("shards"):
		var d3 := current_at(g.global_position)
		if d3 != Vector2.ZERO:
			g.position = main.clamp_arena(g.position + d3 * float(p("pickup_push", 170.0)) * dt, 30.0)


func sail_ship() -> int:
	# A ghost ship crosses the background and fires a broadside: a row of
	# marked impacts parallel to its course, through the player's area.
	var u := Vector2.from_angle(rng.randf() * TAU)
	var nrm := Vector2(-u.y, u.x)
	var ship := GhostShip.new()
	ship.position = ppos() - u * 700.0 + nrm * 420.0
	ship.dir = u
	add_stage_object(ship)
	var n: int = int(p("broadside", 7))
	var r: float = float(p("broadside_radius", 70.0))
	var row := ppos() + nrm * rng.randf_range(-60.0, 60.0)
	var shapes: Array = []
	for i in n:
		shapes.append(HazardShape.circle(clamp_arena(row + u * (float(i) - float(n - 1) * 0.5) * r * 2.6), r))
	if not room_for(shapes.size()) or not pattern_ok(shapes):
		return 0
	for s in shapes:
		var h := spawn_hazard(s, maxf(data.warn_time, 1.2), 0.3, scaled(14.0))
		h.icon = "warn"
		h.enemy_damage = 40.0
	return shapes.size()


func open_cache(c) -> void:
	main.spawn_gem(c.global_position, 8)
	for i in 3:
		main.spawn_shard(c.global_position + Vector2.from_angle(float(i) * 2.1) * 22.0, 1)
	if intensity >= 2:
		# The deep remembers who robs it.
		announce("THE DROWNED WAKE")
		var pool: Array = gm.stage_data()["pool"]
		for i in int(p("drowned_per_cache", 3)):
			if main._enemy_count() >= main.MAX_ENEMIES:
				break
			main._spawn_enemy(str(pool[0]), ring_point(c.global_position, 90.0, 160.0))
	if gm.run_stats:
		gm.run_stats.log_event("cache opened")


func on_boss(boss) -> void:
	super.on_boss(boss)
	_dead_tide = false
	_cycles = false
	set_tide("low")
	_ring_center = ppos()
	ring_active = true


func boss_tick(_delta: float) -> void:
	# The boss arena's ring current: a band between 60% and 100% of
	# ring_radius that carries you round the arena, never out of it.
	if not ring_active:
		return
	var R: float = float(p("ring_radius", 640.0))
	var pl = player()
	if pl == null:
		return
	var d: Vector2 = pl.global_position - _ring_center
	if d.length() > R * 0.6 and d.length() < R:
		pl.add_push(Vector2(-d.y, d.x).normalized() * float(p("ring_push", 80.0)))
	elif d.length() >= R:
		pl.add_push(-d.normalized() * 100.0)


func cleanup() -> void:
	super.cleanup()
	currents.clear()
	ring_active = false


func debug_state() -> Dictionary:
	var d := super.debug_state()
	d["tide"] = tide
	d["currents"] = currents.size()
	d["dead_tide"] = _dead_tide
	var opened := 0
	for c in caches():
		if c.opened:
			opened += 1
	d["caches_opened"] = opened
	return d


class GhostShip extends Node2D:
	var dir := Vector2.RIGHT
	var t := 0.0

	func _ready() -> void:
		z_index = -2

	func _process(d: float) -> void:
		t += d
		position += dir * 160.0 * d
		if t > 9.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(minf(t, 9.0 - t), 0.0, 1.0) * 0.45
		draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-110, -26), Vector2(90, -26), Vector2(130, 0), Vector2(90, 26), Vector2(-110, 26)]), Color(0.6, 0.85, 1.0, a))
		draw_line(Vector2(-20, 0), Vector2(-20, -90), Color(0.8, 0.95, 1.0, a), 4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-20, -88), Vector2(40, -60), Vector2(-20, -30)]), Color(0.8, 0.95, 1.0, a * 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class TideField extends Node2D:
	# Low tide: exposed-seabed ripples. High tide: current bands with
	# chevrons running the way the water flows.
	var rule = null
	var t := 0.0

	func _ready() -> void:
		z_index = -2

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		if rule == null:
			return
		for c in rule.currents:
			var a: Vector2 = c["from"]
			var b: Vector2 = c["to"]
			var w: float = c["width"]
			var u := (b - a).normalized() * float(c["sign"])
			var nrm := Vector2(-u.y, u.x) * w * 0.5
			var col := Color(0.55, 0.85, 1.0, 0.18 if rule.tide == "high" else 0.08)
			draw_colored_polygon(PackedVector2Array([a + nrm, b + nrm, b - nrm, a - nrm]), col)
			draw_line(a + nrm, b + nrm, Color(0.7, 0.95, 1.0, 0.5), 2.0)
			draw_line(a - nrm, b - nrm, Color(0.7, 0.95, 1.0, 0.5), 2.0)
			var L := (b - a).length()
			var k := 0.0
			while k < L:
				var start: Vector2 = a if c["sign"] > 0.0 else b
				var p: Vector2 = start + u * fposmod(k + t * 140.0, L)
				var n2 := nrm * 0.5
				draw_polyline(PackedVector2Array([p - u * 16.0 + n2, p, p - u * 16.0 - n2]), Color(0.85, 1.0, 1.0, 0.75), 3.0)
				k += 120.0
		if rule.ring_active:
			var R: float = float(rule.p("ring_radius", 640.0))
			for i in 8:
				var s := t * 0.6 + TAU * float(i) / 8.0
				draw_arc(rule._ring_center, R * 0.8, s, s + 0.4, 8, Color(0.6, 0.9, 1.0, 0.55), 6.0)
			draw_arc(rule._ring_center, R, 0.0, TAU, 64, Color(0.6, 0.9, 1.0, 0.35), 3.0)
