extends EnemyBehavior
# Soul Thief: never fights, only runs. It flees the player, weaving so it
# cannot be lined up, and turns along the arena edge instead of pinning itself
# in a corner. A mission spawns it and pays out when it dies.

var _weave := 0.0


func _setup() -> void:
	_weave = randf() * TAU


func can_contact() -> bool:
	return false


func step(delta: float, dir: Vector2) -> Vector2:
	t += delta
	enemy.queue_redraw()
	var away := -dir
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	# Weave across the escape line.
	var side := Vector2(-away.y, away.x) * sin(t * 2.6 + _weave) * 0.75
	var out := (away + side).normalized()
	# Slide along the edge rather than into it.
	var m = main()
	if m:
		var half: Vector2 = m.arena_half()
		var p: Vector2 = enemy.global_position
		var margin := 220.0
		if absf(p.x) > half.x - margin and signf(out.x) == signf(p.x):
			out.x = -out.x * 0.3
			out.y = signf(out.y if absf(out.y) > 0.05 else -p.y) * 1.0
		if absf(p.y) > half.y - margin and signf(out.y) == signf(p.y):
			out.y = -out.y * 0.3
			out.x = signf(out.x if absf(out.x) > 0.05 else -p.x) * 1.0
		out = out.normalized()
	# It is slow to start when the player is far, sprinting when chased.
	var d := ppos().distance_to(enemy.global_position)
	return out * clampf(1.25 - d / 900.0, 0.55, 1.15)


func draw_body(c: CanvasItem) -> bool:
	shadow(c, 13.0)
	var bob := sin(t * 14.0) * 1.5
	# Bulging sack of stolen souls, glowing through the cloth.
	var glow := 0.6 + 0.4 * sin(t * 6.0)
	c.draw_circle(Vector2(9, -2 + bob), 15.0, Color(1.0, 0.8, 0.3, 0.18 * glow))
	c.draw_circle(Vector2(9, -2 + bob), 9.0, Color(0.42, 0.32, 0.18))
	c.draw_circle(Vector2(9, -2 + bob), 4.0, Color(1.0, 0.85, 0.4, glow))
	# Hunched hooded runner.
	c.draw_colored_polygon(PackedVector2Array([Vector2(-10, -2), Vector2(8, -6), Vector2(11, 14), Vector2(-12, 14)]), Color(0.12, 0.1, 0.12))
	c.draw_circle(Vector2(-2, -10 + bob), 8.5, Color(0.08, 0.07, 0.09))
	c.draw_circle(Vector2(-4, -10 + bob), 1.8, Color(1.0, 0.85, 0.3))
	c.draw_circle(Vector2(1, -10 + bob), 1.8, Color(1.0, 0.85, 0.3))
	# Gold sparks shaken loose.
	for i in 3:
		var k := fmod(t * 1.7 + float(i) * 0.33, 1.0)
		c.draw_circle(Vector2(12 - k * 26.0, 6 + float(i) * 4.0 - k * 10.0), 2.2 * (1.0 - k), Color(1.0, 0.8, 0.3, 1.0 - k))
	return true
