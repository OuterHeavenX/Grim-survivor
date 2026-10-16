extends StageRule
# Throne of Cinders: The Furnace Court.
#
# Furnace mouths open at the edge of the fight and fire heat lanes across it.
# Each lane shows its furnace, its direction (chevrons running down the lane)
# and its timing (the fill), then burns, then cools. Standing just behind an
# active furnace's mouth is the risk: it grants Furnace Blessing.
#
# Blessing: +damage and +speed per stack, max boon_max stacks, each furnace
# can grant one stack once; gaining a stack refreshes the timer to boon_time.
#
#   0:00  one furnace at a time
#   1:00  opposing pairs leave a corridor through the player's position
#   3:00  while an elite lives, it stokes extra furnaces aimed at you
#   4:20  Royal Decree: four furnace waves, one quadrant left safe, turning
#   5:00  furnaces answer only to the Cinder King (furnace_command)

const FurnaceScript := preload("res://src/stage/furnace.gd")

var boon_stacks := 0
var boon_left := 0.0
var _next := 0.0
var _decree_steps: Array = []    # stage times at which decree waves land
var _decree_center := Vector2.ZERO
var _decree_safe := 0
var _stoke_announced := false


func setup() -> void:
	_next = data.grace


func tick(delta: float, t: float) -> void:
	_tick_boon(delta)
	if stopped:
		return
	if not _decree_steps.is_empty():
		if t >= float(_decree_steps[0]):
			_decree_steps.pop_front()
			fire_decree_wave()
		return
	if in_grace(t) or t < _next:
		return
	match intensity:
		0:
			_next = t + float(p("interval_0", 7.0))
			fire_furnace(rng.randf() * TAU, rng.randf_range(-120.0, 120.0), data.warn_time)
		1:
			_next = t + float(p("interval_1", 6.5))
			fire_pair()
		_:
			if elites_alive() > 0:
				if not _stoke_announced:
					_stoke_announced = true
					announce("ELITES STOKE THE FURNACES")
				_next = t + float(p("elite_interval", 5.0))
				fire_furnace((ppos() - ring_point(ppos(), 300, 400)).angle(), 0.0, data.warn_time)
			else:
				_next = t + float(p("interval_2", 6.0))
				fire_pair()


func elites_alive() -> int:
	return get_tree().get_nodes_in_group("elites").size()


func lane_shape(angle: float, offset: float) -> Dictionary:
	var u := Vector2.from_angle(angle)
	var nrm := Vector2(-u.y, u.x)
	var origin := ppos() - u * float(p("standoff", 560.0)) + nrm * offset
	return HazardShape.line(origin, origin + u * float(p("lane_length", 1500.0)), float(p("lane_width", 120.0)))


func fire_furnace(angle: float, offset: float, warn: float, owner := "stage", ctl = null) -> TimedHazard:
	var s := lane_shape(angle, offset)
	if owner == "stage" and (not room_for(1) or not pattern_ok([s])):
		return null
	if owner == "boss" and ctl and not SafeSpace.pattern_ok(get_tree(), ppos(), [s], 420.0,
			ctl.data.min_safe_fraction, data.safe_reach):
		return null
	var h: TimedHazard
	if owner == "boss" and ctl:
		h = ctl.spawn_hazard(s, warn, float(p("active", 1.5)), ctl.boss.dmg * 0.9, "furnace_command")
	else:
		h = spawn_hazard(s, warn, float(p("active", 1.5)), scaled(float(p("dmg", 14.0))))
	h.enemy_damage = float(p("enemy_dmg", 30.0))
	h.recover_time = float(p("recover", 0.6))
	h.icon = "flame"
	var f = FurnaceScript.new()
	f.rule = self
	f.lane = h
	f.position = s["pos"]
	f.dir = (Vector2(s["to"]) - Vector2(s["pos"])).normalized()
	add_stage_object(f)
	return h


func fire_pair() -> void:
	# Two lanes running opposite ways, either side of the player: the space
	# between them is the corridor to walk.
	var a := rng.randf() * TAU
	var half := float(p("lane_width", 120.0)) * 0.5 + 110.0
	var shift := rng.randf_range(-60.0, 60.0)
	var shapes := [lane_shape(a, -half + shift), lane_shape(a + PI, -half - shift)]
	if not room_for(2) or not pattern_ok(shapes):
		return
	fire_furnace(a, -half + shift, data.warn_time)
	fire_furnace(a + PI, -half - shift, data.warn_time)


func on_event(id: String, ev: StageEventData) -> void:
	super.on_event(id, ev)
	if id != "royal_decree":
		return
	announce("ROYAL DECREE")
	_decree_center = ppos()
	_decree_safe = rng.randi() % 4
	_decree_steps.clear()
	var gap: float = float(p("decree_gap", 3.2))
	for i in int(p("decree_steps", 4)):
		_decree_steps.append(gm.run_time + 0.5 + gap * float(i))


func decree_shapes(safe_q: int) -> Array:
	var out: Array = []
	for q in 4:
		if q == safe_q:
			continue
		out.append(HazardShape.sector(_decree_center, float(p("decree_radius", 720.0)),
			PI * 0.5 * float(q) + PI * 0.25, PI * 0.25))
	return out


func fire_decree_wave() -> int:
	# Each wave burns three quadrants; the safe one turns clockwise. The safe
	# quadrant plus everything beyond the decree's radius is always open.
	var shapes := decree_shapes(_decree_safe)
	var n := 0
	for s in shapes:
		var h := spawn_hazard(s, maxf(data.warn_time, 1.2), float(p("decree_active", 1.4)), scaled(float(p("dmg", 14.0))))
		h.enemy_damage = float(p("enemy_dmg", 30.0))
		h.icon = "flame"
		n += 1
	_decree_safe = (_decree_safe + 1) % 4
	return n


func decree_safe_quadrant() -> int:
	return _decree_safe


# --- the blessing ----------------------------------------------------------

func grant_boon() -> void:
	boon_stacks = mini(boon_stacks + 1, int(p("boon_max", 3)))
	boon_left = float(p("boon_time", 6.0))
	_apply_boon()
	announce("FURNACE BLESSING x%d" % boon_stacks)


func _apply_boon() -> void:
	if boon_stacks <= 0:
		gm.mods.clear_source("stage:furnace_boon")
		return
	gm.mods.set_mod("stage:furnace_boon", "damage", 1.0 + float(p("boon_damage", 0.1)) * float(boon_stacks))
	gm.mods.set_mod("stage:furnace_boon", "speed", 1.0 + float(p("boon_speed", 0.05)) * float(boon_stacks))


func _tick_boon(delta: float) -> void:
	if boon_stacks <= 0:
		return
	boon_left -= delta
	if boon_left <= 0.0:
		boon_stacks = 0
		_apply_boon()


func on_boss(boss) -> void:
	super.on_boss(boss)
	_decree_steps.clear()


func boss_tick(delta: float) -> void:
	_tick_boon(delta)


func cleanup() -> void:
	super.cleanup()
	boon_stacks = 0
	if gm:
		gm.mods.clear_source("stage:furnace_boon")


func debug_state() -> Dictionary:
	var d := super.debug_state()
	d["boon"] = boon_stacks
	d["decree_left"] = _decree_steps.size()
	d["furnaces"] = get_tree().get_nodes_in_group("furnaces").size()
	return d
