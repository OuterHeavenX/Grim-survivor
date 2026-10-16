extends EnemyBehavior
# Shield bearer: a tower shield that soaks `block` of any hit arriving inside
# its arc. It turns towards the player at a limited rate, which is the whole
# counterplay: circle it, or let a second weapon hit it from behind.

var facing := Vector2.DOWN
var _flash := 0.0


func step(delta: float, dir: Vector2) -> Vector2:
	t += delta
	_flash = maxf(0.0, _flash - delta)
	if dir.length() > 0.1:
		var diff := wrapf(dir.angle() - facing.angle(), -PI, PI)
		var rate := pf("turn_rate", 1.6)
		facing = facing.rotated(clampf(diff, -rate * delta, rate * delta))
	return dir


func blocks(from_pos: Vector2) -> bool:
	var d: Vector2 = from_pos - enemy.global_position
	if d.length() < 1.0:
		return false
	return absf(wrapf(d.angle() - facing.angle(), -PI, PI)) <= pf("arc", 1.05)


func modify_damage(amount: float, from_pos: Vector2, _source: String) -> float:
	if blocks(from_pos):
		_flash = 0.15
		return amount * (1.0 - pf("block", 0.8))
	return amount


func draw_body(c: CanvasItem) -> bool:
	shadow(c, 20.0)
	c.draw_circle(Vector2.ZERO, 18.0, Color(0.3, 0.3, 0.34))
	c.draw_circle(Vector2(0, -8), 9.0, Color(0.45, 0.45, 0.5))
	c.draw_set_transform(Vector2.ZERO, -enemy.rotation, Vector2.ONE)
	var a := facing.angle()
	var arc := pf("arc", 1.05)
	var col := Color(1, 1, 0.8) if _flash > 0.0 else Color(0.75, 0.72, 0.6)
	c.draw_arc(Vector2.ZERO, 27.0, a - arc, a + arc, 16, col, 9.0)
	c.draw_arc(Vector2.ZERO, 32.0, a - arc, a + arc, 16, Color(0.9, 0.7, 0.3, 0.8), 2.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
