extends EnemyBehavior
# A siege portal: rooted, spits out a small group on a timer while it stands.
# The Last Bastion counts the ones the player closes.

var _spawn := 3.0


func step(delta: float, _dir: Vector2) -> Vector2:
	t += delta
	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = pf("interval", 7.0)
		var m = main()
		if m:
			for i in int(pf("count", 2.0)):
				if m._enemy_count() >= m.MAX_ENEMIES:
					break
				m._spawn_enemy(str(params.get("spawn", "imp")),
					m.clamp_arena(enemy.global_position + Vector2.from_angle(randf() * TAU) * 50.0))
	return Vector2.ZERO


func can_contact() -> bool:
	return false


func draw_body(c: CanvasItem) -> bool:
	for i in 4:
		var r := 36.0 - float(i) * 7.0
		c.draw_arc(Vector2.ZERO, r, t * (1.5 + float(i)), t * (1.5 + float(i)) + 4.5, 20,
			Color(0.9, 0.35 + 0.1 * float(i), 0.2, 0.85), 5.0)
	c.draw_circle(Vector2.ZERO, 12.0, Color(0.1, 0.02, 0.05))
	return true
