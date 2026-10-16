extends EnemyBehavior
# Burrower: fights on the surface for a while, then dives. Underground it
# cannot be hit or touch you; it heads for where you are going (lead capped
# at 0.6 s of your movement), marks its exit with a warning circle, and bursts
# out there.

var underground := false
var _timer := 0.0
var _exit := Vector2.ZERO
var _marked := false


func _setup() -> void:
	_timer = pf("surface_time", 4.0) * randf_range(0.6, 1.0)


func step(delta: float, dir: Vector2) -> Vector2:
	t += delta
	_timer -= delta
	if not underground:
		if _timer <= 0.0:
			_dive()
		return dir
	if not _marked and _timer <= pf("warn", 0.9):
		_mark_exit()
	if _timer <= 0.0:
		_surface()
		return Vector2.ZERO
	var to: Vector2 = _exit - enemy.global_position
	return to.normalized() * 1.4 if to.length() > 10.0 else Vector2.ZERO


func _dive() -> void:
	underground = true
	_marked = false
	enemy.set_targetable(false)
	_timer = pf("burrow_time", 2.2)
	var p = player()
	var lead := minf(pf("lead", 0.6), 0.6)
	var aim: Vector2 = ppos() + (p.velocity * lead if p else Vector2.ZERO)
	_exit = main().clamp_arena(aim) if main() else aim


func _mark_exit() -> void:
	_marked = true
	var m = main()
	if m == null:
		return
	var h := TimedHazard.new()
	h.setup(HazardShape.circle(_exit, pf("radius", 70.0)), maxf(_timer, 0.65), 0.2,
		float(enemy.dmg), Color(0.75, 0.55, 0.3), "enemy:burrower", "enemy")
	h.icon = "warn"
	m.add_hazard_node(h)
	_timer = maxf(_timer, 0.65)


func _surface() -> void:
	underground = false
	enemy.set_targetable(true)
	enemy.global_position = _exit
	_timer = pf("surface_time", 4.0)


func can_contact() -> bool:
	return not underground


func draw_body(c: CanvasItem) -> bool:
	if underground:
		# A travelling mound of earth: visible, but clearly not a target.
		c.draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.5))
		c.draw_circle(Vector2.ZERO, 16.0 + 2.0 * sin(t * 12.0), Color(0.35, 0.27, 0.18, 0.9))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return true
	shadow(c, 16.0)
	c.draw_circle(Vector2.ZERO, 16.0, Color(0.45, 0.32, 0.2))
	for i in 5:
		var a := -PI * 0.5 + (float(i) - 2.0) * 0.35
		c.draw_line(Vector2.from_angle(a) * 12.0, Vector2.from_angle(a) * 22.0, Color(0.9, 0.85, 0.7), 3.0)
	c.draw_circle(Vector2(-5, -4), 2.2, Color(1, 0.6, 0.2))
	c.draw_circle(Vector2(5, -4), 2.2, Color(1, 0.6, 0.2))
	return true
