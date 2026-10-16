extends StageRule
# The Bone Desert: Ossuary Storm.
#
# Wind always blows one way (seeded). Light wind just drifts loose pickups;
# a storm darkens everything past a small circle, pushes pickups hard and
# shoves the player, unless the player stands in the lee of a fossil rib.
# Ribs are solid: they constrain movement for everyone.
#
# Bone piles collect fragments from skeletal foes that fall near them. Walk
# over a pile to shatter it for XP. Necromancers want the same piles to raise
# the dead; raised dead give nothing (no XP, shards or kill), so the race is
# for the pile, not a farm.
#
#   1:00  short storms; 3:00 necromancer waves; 4:15 Ossuary Storm: the storm
#   holds, piles pay double and necromancers raise more; 5:00 the wind drops.
# Pickups are clamped to the arena: wind can never push them out of reach.

const PileScript := preload("res://src/stage/bone_pile.gd")

var wind := Vector2.RIGHT
var ribs: Array = []          # obstacle dictionaries {pos, to, radius}
var storm := false
var _storm_t := 0.0
var _next_storm := 0.0
var _ossuary := false
var _necro_next := 0.0
var _field: Node2D


func setup() -> void:
	wind = Vector2.from_angle(rng.randf() * TAU)
	_make_ribs()
	_make_piles()
	_field = DesertField.new()
	_field.rule = self
	add_stage_object(_field)
	_next_storm = float(data.phase_times[0]) if data.phase_times.size() > 0 else 60.0


func _make_ribs() -> void:
	# Ribs lie across the wind so their lee is a usable shelter. Two are
	# always close to the start.
	var n: int = int(p("ribs", 10))
	var L: float = float(p("rib_length", 260.0))
	var across := Vector2(-wind.y, wind.x)
	var spots: Array = [-wind * 320.0 + across * 160.0, wind * 360.0 - across * 200.0]
	var tries := 0
	while spots.size() < n and tries < 300:
		tries += 1
		var c := Vector2(rng.randf_range(-1250.0, 1250.0), rng.randf_range(-1250.0, 1250.0))
		if c.length() < 260.0:
			continue
		var ok := true
		for s in spots:
			if c.distance_to(s) < 420.0:
				ok = false
		if ok:
			spots.append(c)
	for c in spots:
		var o := {"pos": c - across * L * 0.5, "to": c + across * L * 0.5, "radius": float(p("rib_radius", 26.0))}
		ribs.append(o)
		director.add_obstacle(o)


func _make_piles() -> void:
	for i in int(p("piles", 10)):
		var pile = PileScript.new()
		pile.rule = self
		pile.fragments = rng.randi_range(1, 2)
		pile.max_fragments = int(p("pile_max", 5))
		pile.position = Vector2(rng.randf_range(-1200.0, 1200.0), rng.randf_range(-1200.0, 1200.0))
		if i < 2:
			pile.position = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(260.0, 420.0)
		add_stage_object(pile)


func piles() -> Array:
	return get_tree().get_nodes_in_group("bone_piles")


func sheltered(pos: Vector2) -> bool:
	# In the lee of a rib: downwind of it, within shelter_depth, and within
	# the rib's span.
	var depth: float = float(p("shelter_depth", 230.0))
	for r in ribs:
		var a: Vector2 = r["pos"]
		var b: Vector2 = r["to"]
		var mid := (a + b) * 0.5
		var span := (b - a).length() * 0.5
		var rel := pos - mid
		var down := rel.dot(wind)
		var side := absf(rel.dot((b - a).normalized()))
		if down > 0.0 and down < depth and side <= span:
			return true
	return false


func wind_strength() -> float:
	return float(p("wind_storm", 60.0)) if storm else float(p("wind_light", 10.0))


func start_storm() -> void:
	storm = true
	_storm_t = 0.0
	announce("SANDSTORM")
	director.veil.set_veil(float(p("storm_dark", 0.5)), 260.0, Color(0.16, 0.12, 0.07))


func end_storm() -> void:
	storm = false
	director.veil.set_veil(0.0)


func on_event(id: String, ev: StageEventData) -> void:
	super.on_event(id, ev)
	if id == "ossuary_storm":
		_ossuary = true
		if not storm:
			start_storm()


func pile_multiplier() -> int:
	return 2 if _ossuary else 1


func tick(delta: float, t: float) -> void:
	if stopped:
		return
	if intensity >= 1 and not _ossuary:
		if storm:
			_storm_t += delta
			if _storm_t >= float(p("storm_len", 9.0)):
				end_storm()
				_next_storm = t + float(p("storm_every", 26.0))
		elif t >= _next_storm:
			start_storm()
	apply_wind(delta)
	if _ossuary and t >= _necro_next:
		# Ossuary Storm: one extra necromancer at a time on top of the
		# scheduled trickle, and every one raises an extra corpse.
		_necro_next = t + float(p("necro_interval", 18.0))
		if main.count_alive("necromancer") < int(p("necro_max", 3)) + 1:
			main._spawn_enemy("necromancer", main._ring_pos())
	if _ossuary:
		for e in get_tree().get_nodes_in_group("enemies"):
			if String(e.etype) == "necromancer" and e.behavior:
				e.behavior.params["raise"] = 3


func apply_wind(delta: float) -> void:
	var w := wind * wind_strength()
	var lode: bool = gm.has_relic("tide_lodestone")
	var push_pick := (float(p("pickup_push", 150.0)) if storm else float(p("wind_light", 10.0))) * (0.0 if lode else 1.0)
	for g in get_tree().get_nodes_in_group("gems") + get_tree().get_nodes_in_group("shards"):
		g.position = main.clamp_arena(g.position + wind * push_pick * delta, 30.0)
	if storm:
		var pl = player()
		if pl and not sheltered(pl.global_position):
			pl.add_push(wind * float(p("player_push", 55.0)))
		for e in get_tree().get_nodes_in_group("enemies"):
			e.push += w * 0.5


func on_enemy_died(e) -> void:
	# Only real deaths of skeletal foes feed the piles; the risen dead do not,
	# so raise-and-kill loops cannot grow a pile.
	if e.revived or e.no_credit or not e.has_tag("skeletal"):
		return
	for pile in piles():
		if pile.global_position.distance_to(e.global_position) < 140.0:
			pile.add_fragment()
			return


func nearest_pile(pos: Vector2, reach: float):
	var best = null
	var bd := reach
	for pile in piles():
		if pile.fragments <= 0:
			continue
		var d: float = pile.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = pile
	return best


func take_pile_spots(pos: Vector2, n: int) -> Array:
	# The Pale Herald drawing bones out of nearby piles.
	var out: Array = []
	var list := piles().filter(func(pl): return pl.fragments > 0 and pl.global_position.distance_to(pos) < 700.0)
	for pile in list:
		while out.size() < n and pile.consume(1) > 0:
			out.append(pile.global_position)
	return out


func on_boss(boss) -> void:
	super.on_boss(boss)
	_ossuary = false
	end_storm()


func cleanup() -> void:
	super.cleanup()
	if director and director.veil:
		director.veil.set_veil(0.0)


func debug_state() -> Dictionary:
	var d := super.debug_state()
	d["storm"] = storm
	d["ribs"] = ribs.size()
	d["piles"] = piles().size()
	d["wind"] = wind
	return d


class DesertField extends Node2D:
	# Ribs below actors; storm streaks and shelter outlines above the veil
	# (z 56), so shelter stays readable in a whiteout.
	var rule = null
	var t := 0.0
	var _top: Node2D

	func _ready() -> void:
		z_index = -2
		_top = TopDraw.new()
		_top.field = self
		_top.z_as_relative = false
		_top.z_index = 56
		add_child(_top)

	func _process(d: float) -> void:
		t += d
		queue_redraw()
		_top.queue_redraw()

	func _draw() -> void:
		for r in rule.ribs:
			var a: Vector2 = r["pos"]
			var b: Vector2 = r["to"]
			var rad: float = r["radius"]
			draw_line(a + Vector2(6, 8), b + Vector2(6, 8), Color(0, 0, 0, 0.35), rad * 2.0)
			draw_line(a, b, Color(0.82, 0.78, 0.66), rad * 1.6)
			draw_circle(a, rad, Color(0.88, 0.84, 0.72))
			draw_circle(b, rad, Color(0.88, 0.84, 0.72))
			var n := 5
			for i in n:
				var c := a.lerp(b, (float(i) + 0.5) / float(n))
				draw_arc(c - rule.wind * 18.0, 22.0, rule.wind.angle() - 1.2, rule.wind.angle() + 1.2, 8, Color(0.7, 0.66, 0.55), 5.0)

	func draw_top(c: CanvasItem) -> void:
		if not rule.storm:
			return
		var pl = rule.player()
		if pl == null:
			return
		var center: Vector2 = pl.global_position
		var depth: float = float(rule.p("shelter_depth", 230.0))
		for r in rule.ribs:
			var a: Vector2 = r["pos"]
			var b: Vector2 = r["to"]
			if (a + b).distance_to(center * 2.0) > 2400.0:
				continue
			var poly := PackedVector2Array([a, b, b + rule.wind * depth, a + rule.wind * depth, a])
			c.draw_polyline(poly, Color(1.0, 0.95, 0.7, 0.8), 3.0)
		for i in 40:
			var p := center + Vector2(fposmod(float(i) * 97.0 + t * 420.0, 1400.0) - 700.0,
				fposmod(float(i) * 61.0, 1400.0) - 700.0).rotated(rule.wind.angle())
			c.draw_line(p, p + rule.wind * 26.0, Color(0.95, 0.85, 0.6, 0.35), 2.0)


class TopDraw extends Node2D:
	var field = null

	func _draw() -> void:
		if field:
			field.draw_top(self)
