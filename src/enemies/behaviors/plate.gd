extends EnemyBehavior
# A bone armour plate orbiting the Pale Herald. It moves with its anchor and
# cannot be shoved; break it to strip the boss's armour.

var anchor = null
var orbit_index := 0
var orbit_count := 4


func step(delta: float, _dir: Vector2) -> Vector2:
	t += delta
	if anchor == null or not is_instance_valid(anchor) or bool(anchor.get("dead")):
		enemy.queue_free()
		return Vector2.ZERO
	var a := t * pf("spin", 1.1) + TAU * float(orbit_index) / float(maxi(1, orbit_count))
	enemy.global_position = anchor.global_position + Vector2.from_angle(a) * pf("orbit", 92.0)
	return Vector2.ZERO


func can_contact() -> bool:
	return false


func draw_body(c: CanvasItem) -> bool:
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(15, -4), Vector2(10, 16), Vector2(-10, 16), Vector2(-15, -4)]), Color(0.88, 0.84, 0.72))
	c.draw_polyline(PackedVector2Array([Vector2(0, -20), Vector2(15, -4), Vector2(10, 16), Vector2(-10, 16), Vector2(-15, -4), Vector2(0, -20)]), Color(0.3, 0.25, 0.2), 2.5)
	c.draw_line(Vector2(-8, 0), Vector2(8, 4), Color(0.45, 0.4, 0.32), 2.0)
	return true
