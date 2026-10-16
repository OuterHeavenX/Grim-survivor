extends BossAttack
# The boss sinks, marks a few resurfacing spots, and comes up under one of
# them with an eruption. Only the real spot carries a warning icon; the
# others are ripples. Every candidate is validated: inside the arena, clear
# of obstacles, and not on top of the player.

const ARENA_MARGIN := 140.0

var _active := false
var _t := 0.0
var _spot := Vector2.ZERO
var _ripples: Array = []


static func valid_spot(m, p: Vector2, player_pos: Vector2, min_player: float) -> bool:
	var a: float = m.ARENA - ARENA_MARGIN
	if absf(p.x) > a or absf(p.y) > a:
		return false
	if p.distance_to(player_pos) < min_player:
		return false
	if m.director and is_instance_valid(m.director) and m.director.blocked(p, 60.0):
		return false
	return true


func candidates() -> Array:
	var m = main()
	var out: Array = []
	var pool: Array = []
	var r = rule()
	if r and r.has_method("island_points"):
		pool = r.island_points()
	for i in 24:
		pool.append(ppos() + Vector2.from_angle(rng().randf() * TAU) * rng().randf_range(260.0, 480.0))
	for p in pool:
		if out.size() >= pi("candidates", 3):
			break
		if p.distance_to(ppos()) > 700.0:
			continue
		if valid_spot(m, p, ppos(), pf("min_player", 220.0)):
			out.append(p)
	if out.is_empty():
		# Fallback that is valid by construction: straight away from the
		# player, clamped well inside the arena.
		out.append(clamp_arena(ppos() + (bpos() - ppos()).normalized() * 320.0, ARENA_MARGIN + 10.0))
	return out


func telegraph() -> void:
	# The sink itself is the wind-up: the boss dims while it goes under.
	var tw = boss().create_tween()
	tw.tween_property(boss(), "modulate:a", 0.35, warn_time())


func commit() -> void:
	var c := candidates()
	_spot = c[rng().randi() % c.size()]
	ctl.submerged = true
	boss().set_targetable(false)
	boss().modulate.a = 0.0
	_active = true
	_t = 0.0
	for p in c:
		if p == _spot:
			continue
		var rip := Ripple.new()
		rip.position = p
		ctl.own_object(rip)
		_ripples.append(rip)
	var h := hazard(HazardShape.circle(_spot, pf("radius", 95.0)), 0.35, pf("dmg", 1.1), pf("under", 1.6))
	h.icon = "skull"


func is_running() -> bool:
	return _active


func tick(delta: float) -> void:
	if not _active:
		return
	_t += delta
	if _t >= maxf(pf("under", 1.6), 0.65):
		boss().global_position = _spot
		boss().modulate.a = 1.0
		ctl.submerged = false
		boss().set_targetable(true)
		if main().jm:
			main().jm.shockwave(_spot, ctl.data.aura, 200.0)
		stop()


func stop() -> void:
	if ctl and ctl.submerged:
		ctl.submerged = false
		if is_instance_valid(boss()):
			boss().modulate.a = 1.0
			boss().set_targetable(true)
	_active = false
	for r in _ripples:
		if is_instance_valid(r):
			r.queue_free()
	_ripples.clear()


class Ripple extends Node2D:
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		for i in 3:
			var f := fposmod(t * 0.8 + float(i) / 3.0, 1.0)
			draw_arc(Vector2.ZERO, 20.0 + 70.0 * f, 0.0, TAU, 32, Color(0.6, 0.9, 0.7, 0.6 * (1.0 - f)), 2.0)
