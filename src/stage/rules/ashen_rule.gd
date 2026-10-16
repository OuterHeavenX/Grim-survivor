extends StageRule
# Ashen Hollow: Embers Beneath the Ash.
#
# Cinder scars crack, glow and erupt; spent scars cool into grey ash that no
# new scar may form on for a while. The pattern escalates on the timeline:
#   0:00  single scars, away from the player, to teach the rule
#   1:00  linked lines of three, away from the player; from 2:00 one link
#         lands where the player is heading (lead capped)
#   3:00  alternating eruption bands that leave walkable lanes
#   4:30  Ashfall: the light drops, scars come faster, cooled ash matters
#   5:00  the boss arrives: no new scars, pending ones are cleared
#
# Every pattern is checked with SafeSpace before it is placed; a pattern
# that would leave no reachable safe ground is skipped, not shrunk.

var _next := 0.0
var _band_flip := false
var _ashfall := false
var _last_pattern := ""


func setup() -> void:
	_next = data.grace


func on_event(id: String, ev: StageEventData) -> void:
	super.on_event(id, ev)
	if id == "ashfall":
		_ashfall = true
		director.veil.set_veil(float(p("ash_dark", 0.45)), 340.0, Color(0.06, 0.05, 0.05))
		_next = minf(_next, gm.run_time + 1.0)


func interval() -> float:
	if _ashfall:
		return float(p("interval_3", 1.8))
	match intensity:
		0:
			return float(p("interval_0", 3.4))
		1:
			return float(p("interval_1", 2.6))
		_:
			return float(p("interval_2", 3.2))


func tick(_delta: float, t: float) -> void:
	if stopped or in_grace(t) or t < _next:
		return
	_next = t + interval()
	if _ashfall:
		# Ashfall alternates the two hardest shapes.
		if _last_pattern == "linked":
			spawn_bands()
		else:
			spawn_linked(true)
		return
	match intensity:
		0:
			spawn_single()
		1:
			spawn_linked(t >= 120.0)
		_:
			spawn_bands()


func scar_params() -> Dictionary:
	return data.params


func _free_spot(pos: Vector2) -> bool:
	var r: float = float(p("radius", 70.0))
	return not AshScar.on_cooled_ground(get_tree(), pos, r)


func spawn_single() -> int:
	var r: float = float(p("radius", 70.0))
	for attempt in 8:
		var pos := ring_point(ppos(), 180.0, 420.0)
		if not _free_spot(pos):
			continue
		var s := HazardShape.circle(pos, r)
		if room_for(1) and pattern_ok([s]):
			AshScar.make(self, pos, scar_params())
			_last_pattern = "single"
			return 1
	return 0


func spawn_linked(predict: bool) -> int:
	var r: float = float(p("radius", 70.0))
	var center: Vector2
	if predict:
		# Lead is capped: the scar lands where you are going, not where you
		# could be in two seconds.
		center = clamp_arena(ppos() + pvel() * minf(float(p("lead", 0.55)), 0.6))
	else:
		center = ring_point(ppos(), 220.0, 400.0)
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var spots: Array = []
	for i in 3:
		spots.append(clamp_arena(center + dir * (float(i) - 1.0) * r * 2.1))
	var shapes: Array = []
	var keep: Array = []
	for sp in spots:
		if not _free_spot(sp):
			continue
		shapes.append(HazardShape.circle(sp, r))
		keep.append(sp)
	if keep.is_empty() or not room_for(keep.size()) or not pattern_ok(shapes):
		return 0
	for sp in keep:
		AshScar.make(self, sp, scar_params())
	_last_pattern = "linked"
	return keep.size()


func band_shapes() -> Array:
	# Parallel bands across the player's area. Lanes between them are
	# band_gap wide; the set shifts by half a period every time, so the lane
	# you stand in now is the band next time.
	var w: float = float(p("band_width", 110.0))
	var gap: float = float(p("band_gap", 150.0))
	var period := w + gap
	var ang := (PI * 0.5) if int(gm.run_time / 20.0) % 2 == 0 else 0.0
	var u := Vector2.from_angle(ang)
	var nrm := Vector2(-u.y, u.x)
	_band_flip = not _band_flip
	var shift := period * 0.5 if _band_flip else 0.0
	var out: Array = []
	for k in range(-2, 3):
		var c := ppos() + nrm * (float(k) * period + shift)
		out.append(HazardShape.line(c - u * 520.0, c + u * 520.0, w))
	return out


func spawn_bands() -> int:
	var shapes := band_shapes()
	if not room_for(shapes.size()) or not pattern_ok(shapes):
		return 0
	for s in shapes:
		var h := spawn_hazard(s, data.warn_time + float(p("crack_time", 0.6)), float(p("active", 0.35)),
			scaled(float(p("dmg", 16.0))))
		h.enemy_damage = float(p("enemy_dmg", 40.0))
		h.recover_time = 0.3
		h.icon = "flame"
	_last_pattern = "bands"
	return shapes.size()


func on_boss(boss) -> void:
	super.on_boss(boss)
	_ashfall = false
	director.veil.set_veil(0.0)


func cleanup() -> void:
	super.cleanup()
	if director and director.veil:
		director.veil.set_veil(0.0)


func debug_state() -> Dictionary:
	var d := super.debug_state()
	var cooled := 0
	var live := 0
	for s in get_tree().get_nodes_in_group("ash_scars"):
		if s.is_lingering():
			cooled += 1
		elif s.is_threat():
			live += 1
	d["scars"] = live
	d["cooled"] = cooled
	d["ashfall"] = _ashfall
	d["pattern"] = _last_pattern
	return d
