extends EnemyBehavior
# Soul leech: goes for loose XP gems instead of you, swallowing them (up to
# max_stored). Killing it returns everything it swallowed as one gem, so it is
# a race, never a loss.

var stored := 0
var _target = null
var _scan := 0.0


func step(delta: float, dir: Vector2) -> Vector2:
	t += delta
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.3
		_target = null
		if stored < int(pf("max_stored", 60.0)):
			var bd := pf("seek", 600.0)
			for g in enemy.get_tree().get_nodes_in_group("gems"):
				var d: float = g.global_position.distance_to(enemy.global_position)
				if d < bd:
					bd = d
					_target = g
	if _target and is_instance_valid(_target):
		var to: Vector2 = _target.global_position - enemy.global_position
		if to.length() < 26.0:
			swallow(_target)
			_target = null
			return Vector2.ZERO
		return to.normalized()
	return dir * 0.6


func swallow(g) -> void:
	var room := int(pf("max_stored", 60.0)) - stored
	var v := mini(int(g.value), room)
	if v <= 0:
		return
	stored += v
	g.remove_from_group("gems")
	g.queue_free()
	enemy.queue_redraw()


func on_death() -> void:
	var m = main()
	if m and stored > 0:
		m.spawn_gem(enemy.global_position, stored)
		stored = 0


func draw_body(c: CanvasItem) -> bool:
	var bloat := 1.0 + minf(float(stored) / 30.0, 1.0) * 0.6
	var wob := sin(t * 9.0) * 0.08
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(bloat * (1.0 + wob), bloat * (1.0 - wob)))
	c.draw_circle(Vector2.ZERO, 13.0, Color(0.25, 0.15, 0.35, 0.9))
	c.draw_circle(Vector2.ZERO, 8.0, Color(0.4, 1.0, 0.5, 0.25 + minf(float(stored) / 30.0, 1.0) * 0.6))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_circle(Vector2(-4, -6), 2.0, Color(0.9, 1.0, 0.6))
	c.draw_circle(Vector2(4, -6), 2.0, Color(0.9, 1.0, 0.6))
	return true
