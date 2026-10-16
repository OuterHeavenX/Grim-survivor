extends EnemyBehavior
# A rooted object (the Drowned Maw's anchors): stands, takes hits, gives
# nothing. Expires after `life` so forgotten anchors cannot pile up.


func step(delta: float, _dir: Vector2) -> Vector2:
	t += delta
	if t >= pf("life", 22.0):
		enemy.queue_free()
	return Vector2.ZERO


func can_contact() -> bool:
	return false


func draw_body(c: CanvasItem) -> bool:
	shadow(c, 22.0)
	c.draw_line(Vector2(0, -26), Vector2(0, 18), Color(0.3, 0.35, 0.42), 7.0)
	c.draw_arc(Vector2(0, 8), 18.0, 0.2, PI - 0.2, 12, Color(0.3, 0.35, 0.42), 7.0)
	c.draw_line(Vector2(-12, -18), Vector2(12, -18), Color(0.3, 0.35, 0.42), 6.0)
	c.draw_circle(Vector2(0, -30), 6.0, Color(0.5, 0.75, 1.0, 0.8))
	return true
