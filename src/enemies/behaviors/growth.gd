extends EnemyBehavior
# Mire growth: rooted, and feeds the boss that planted it while it lives.
# The beam to the boss shows exactly which growth is healing it.

var _boss = null


func step(delta: float, _dir: Vector2) -> Vector2:
	t += delta
	_boss = enemy.get("summoner")
	if _boss and is_instance_valid(_boss) and not bool(_boss.get("dead")):
		_boss.hp = minf(float(_boss.max_hp), float(_boss.hp) + pf("heal_frac", 0.012) * float(_boss.max_hp) * delta)
	return Vector2.ZERO


func can_contact() -> bool:
	return false


func draw_body(c: CanvasItem) -> bool:
	shadow(c, 20.0)
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	c.draw_circle(Vector2.ZERO, 20.0, Color(0.2, 0.35, 0.15))
	for i in 5:
		var a := TAU * float(i) / 5.0 + t * 0.4
		c.draw_line(Vector2.ZERO, Vector2.from_angle(a) * 26.0, Color(0.35, 0.6, 0.25), 4.0)
	c.draw_circle(Vector2.ZERO, 8.0 + 3.0 * pulse, Color(0.6, 1.0, 0.5, 0.8))
	if _boss and is_instance_valid(_boss):
		var to: Vector2 = _boss.global_position - enemy.global_position
		c.draw_line(Vector2.ZERO, to, Color(0.5, 1.0, 0.45, 0.25 + 0.2 * pulse), 5.0)
	return true
