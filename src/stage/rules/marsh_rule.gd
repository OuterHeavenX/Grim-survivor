extends StageRule
# The Weeping Marsh: Rising Mire.
#
# The water cycles low -> warning -> high. At high water everything off the
# raised islands wades:
#   player          speed x player_slow (a "stage:water" modifier, so it
#                   composes with boots, class speed and every other mod)
#   ordinary foes   x enemy_slow  (gentler than the player's, so kiting
#                   through water is not free)
#   heavy foes      x resist_slow
#   bog creatures   unaffected
# High water reads without colour: animated wave lines cover the water and
# islands keep a hard rim.
#
# 1:15 first tide; 2:00 cycles lengthen and soul-lights drift to the islands
# you should make for; 4:15 Mire Bloom: toxic blooms rise in the water and a
# fire blast detonates them. A bloom's blast is not fire, so blooms never set
# each other off. At the boss the tide settles low and stays there.

const BloomScript := preload("res://src/stage/marsh_bloom.gd")

var islands: Array = []          # [{pos, radius, sunk_until}]
var tide := "low"
var _tide_t := 0.0
var _cycle := 0
var _field: Node2D
var _lights: Array = []
var _bloom_next := 0.0
var _blooming := false


func setup() -> void:
	_make_islands()
	_field = MarshField.new()
	_field.rule = self
	add_stage_object(_field)


func _make_islands() -> void:
	var r: float = float(p("island_radius", 150.0))
	var n: int = int(p("islands", 9))
	# One island always sits a short walk from the start, so the first tide
	# never asks the impossible.
	islands.append({"pos": Vector2(0, -260), "radius": r, "sunk_until": -1.0})
	var tries := 0
	while islands.size() < n and tries < 400:
		tries += 1
		var pos := Vector2(rng.randf_range(-1300.0, 1300.0), rng.randf_range(-1300.0, 1300.0))
		var ok := true
		for isl in islands:
			if pos.distance_to(isl["pos"]) < 420.0:
				ok = false
				break
		if ok:
			islands.append({"pos": pos, "radius": r, "sunk_until": -1.0})


func island_points() -> Array:
	var out: Array = []
	for isl in islands:
		if not is_sunk(isl):
			out.append(isl["pos"])
	return out


func is_sunk(isl: Dictionary) -> bool:
	return float(isl["sunk_until"]) > gm.run_time


func on_island(pos: Vector2, pad := 0.0) -> bool:
	for isl in islands:
		if not is_sunk(isl) and pos.distance_to(isl["pos"]) <= float(isl["radius"]) + pad:
			return true
	return false


func nearest_islands(pos: Vector2, n: int) -> Array:
	var list := islands.filter(func(i): return not is_sunk(i))
	list.sort_custom(func(a, b): return pos.distance_to(a["pos"]) < pos.distance_to(b["pos"]))
	return list.slice(0, n)


func high_water() -> bool:
	return tide == "high"


func set_tide(state: String) -> void:
	tide = state
	_tide_t = 0.0
	match state:
		"warning":
			announce("THE TIDE RISES")
			if intensity >= 1:
				_spawn_lights()
		"high":
			_clear_lights()
		"low":
			_clear_lights()


func _tide_length(state: String) -> float:
	match state:
		"warning":
			return float(p("tide_warn", 3.0))
		"high":
			if _cycle <= 1:
				return float(p("first_high", 8.0))
			return float(p("high_2", 15.0)) if intensity >= 1 else float(p("high_1", 12.0))
		_:
			return float(p("low_2", 13.0)) if intensity >= 1 else float(p("low_1", 16.0))


func on_event(id: String, ev: StageEventData) -> void:
	super.on_event(id, ev)
	match id:
		"first_tide":
			_cycle = 1
			set_tide("warning")
		"mire_bloom":
			_blooming = true
			_bloom_next = gm.run_time


func tick(delta: float, t: float) -> void:
	if stopped:
		return
	_tide_t += delta
	if _cycle > 0 and _tide_t >= _tide_length(tide):
		match tide:
			"warning":
				set_tide("high")
			"high":
				set_tide("low")
			_:
				_cycle += 1
				set_tide("warning")
	apply_water()
	if _blooming and t >= _bloom_next:
		_bloom_next = t + float(p("bloom_interval", 6.0))
		spawn_blooms(int(p("bloom_count", 6)) if get_tree().get_nodes_in_group("blooms").is_empty() else 2)


func apply_water() -> void:
	var src := "stage:water"
	var pl = player()
	if high_water() and pl and not on_island(pl.global_position):
		gm.mods.set_mod(src, "speed", float(p("player_slow", 0.68)))
	else:
		gm.mods.clear_source(src)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.env_speed = water_factor(e)


func water_factor(e) -> float:
	if not high_water() or on_island(e.global_position):
		return 1.0
	var resp: String = e.data.water_response if e.data else "normal"
	match resp:
		"ignore":
			return 1.0
		"resist":
			return float(p("resist_slow", 0.93))
	return float(p("enemy_slow", 0.82))


func _spawn_lights() -> void:
	# Soul-lights leave the player and settle on the nearest two islands.
	_clear_lights()
	for isl in nearest_islands(ppos(), 2):
		var l := SoulLight.new()
		l.position = ppos()
		l.target = isl["pos"]
		add_stage_object(l)
		_lights.append(l)


func _clear_lights() -> void:
	for l in _lights:
		if is_instance_valid(l):
			l.queue_free()
	_lights.clear()


func spawn_blooms(n: int) -> int:
	var made := 0
	var cap := 8
	for attempt in n * 6:
		if made >= n or get_tree().get_nodes_in_group("blooms").size() >= cap:
			break
		var pos := ring_point(ppos(), 160.0, 480.0)
		if on_island(pos, float(p("bloom_radius", 58.0))):
			continue
		var b = BloomScript.new()
		b.rule = self
		b.position = pos
		b.radius = float(p("bloom_radius", 58.0))
		add_stage_object(b)
		made += 1
	return made


func on_element(kind: String, pos: Vector2, radius: float, _source: String) -> void:
	if kind != "fire":
		return
	for b in get_tree().get_nodes_in_group("blooms"):
		if b.global_position.distance_to(pos) <= radius + float(b.radius):
			b.detonate()


func sink_island(near: Vector2, duration: float) -> Dictionary:
	# Maw of the Mire's island break. Returns the island it sank, so the boss
	# attack can put its hazard exactly there.
	var list := nearest_islands(near, 1)
	if list.is_empty():
		return {}
	var isl: Dictionary = list[0]
	isl["sunk_until"] = gm.run_time + duration
	return isl


func on_boss(boss) -> void:
	super.on_boss(boss)
	_blooming = false
	_cycle = 0
	set_tide("low")
	gm.mods.clear_source("stage:water")
	for b in get_tree().get_nodes_in_group("blooms"):
		b.queue_free()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.env_speed = 1.0


func boss_tick(_delta: float) -> void:
	apply_water()


func cleanup() -> void:
	super.cleanup()
	_clear_lights()
	if gm:
		gm.mods.clear_source("stage:water")


func debug_state() -> Dictionary:
	var d := super.debug_state()
	d["tide"] = tide
	d["cycle"] = _cycle
	d["islands"] = islands.size()
	d["blooms"] = get_tree().get_nodes_in_group("blooms").size()
	return d


class SoulLight extends Node2D:
	var target := Vector2.ZERO
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		global_position = global_position.move_toward(target, 260.0 * d)
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		draw_circle(Vector2.ZERO, 16.0 + 4.0 * pulse, Color(0.6, 1.0, 0.8, 0.25))
		draw_circle(Vector2.ZERO, 7.0, Color(0.9, 1.0, 0.95, 0.95))


class MarshField extends Node2D:
	# Islands and, at high water, animated wave lines over the water.
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
		var hi: bool = rule.tide != "low"
		for isl in rule.islands:
			var pos: Vector2 = isl["pos"]
			var r: float = isl["radius"]
			if rule.is_sunk(isl):
				draw_arc(pos, r, 0.0, TAU, 40, Color(0.4, 0.6, 0.45, 0.35), 2.0)
				continue
			draw_circle(pos + Vector2(6, 10), r, Color(0, 0, 0, 0.3))
			draw_circle(pos, r, Color(0.2, 0.26, 0.15))
			draw_circle(pos, r * 0.8, Color(0.25, 0.32, 0.18))
			draw_arc(pos, r, 0.0, TAU, 48, Color(0.75, 0.85, 0.55, 0.85), 4.0)
			for k in 6:
				var a := TAU * float(k) / 6.0
				var b := pos + Vector2.from_angle(a) * r * 0.55
				draw_line(b, b + Vector2(0, -12), Color(0.5, 0.7, 0.35), 2.0)
		var pl = rule.player()
		if pl == null:
			return
		var c: Vector2 = pl.global_position
		var a := 0.55 if rule.tide == "high" else (0.25 if hi else 0.0)
		if a <= 0.0:
			return
		# Wave strokes on a grid around the player, skipped over islands.
		# Reduced effects quarters the strokes but keeps the pattern, so high
		# water still reads by shape rather than tint.
		var step := 140.0 if bool(rule.gm.setting("reduced_effects")) else 70.0
		var nx := int(600.0 / step) + 1
		var ny := int(900.0 / step) + 1
		for gx in range(-nx, nx + 1):
			for gy in range(-ny, ny + 1):
				var p := Vector2(floor(c.x / step) * step + gx * step, floor(c.y / step) * step + gy * step)
				if rule.on_island(p, 10.0):
					continue
				var off := sin(t * 2.0 + p.x * 0.02 + p.y * 0.03) * 6.0
				draw_arc(p + Vector2(off, 0), 12.0, PI * 1.15, PI * 1.85, 6, Color(0.55, 0.85, 0.9, a), 2.0)
