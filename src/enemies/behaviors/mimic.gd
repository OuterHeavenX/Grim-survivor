extends EnemyBehavior
# Mimic: sits as a chest, but a fair one: a row of teeth along the lid seam,
# a slow breathing heave and an eye that blinks open give it away. It wakes
# when the player comes within `wake` or hits it, hesitates for `reveal`,
# then gives chase. Mimics are only ever extra treasure: they are not in the
# "chests" group and never stand in for an elite's reward chest.

var awake := false
var _reveal := 0.0


func step(delta: float, dir: Vector2) -> Vector2:
	t += delta
	if not awake:
		if enemy.global_position.distance_to(ppos()) <= pf("wake", 150.0):
			_wake()
		return Vector2.ZERO
	if _reveal > 0.0:
		_reveal -= delta
		return Vector2.ZERO
	return dir


func _wake() -> void:
	if awake:
		return
	awake = true
	_reveal = pf("reveal", 0.55)
	if main() and main().hud:
		main().hud.show_warning("MIMIC!")


func modify_damage(amount: float, _from: Vector2, _source: String) -> float:
	_wake()
	return amount


func can_contact() -> bool:
	return awake and _reveal <= 0.0


func draw_body(c: CanvasItem) -> bool:
	var heave := 1.0 + sin(t * (1.6 if not awake else 9.0)) * 0.04
	c.draw_set_transform(Vector2.ZERO, -enemy.rotation, Vector2(1.0, heave))
	c.draw_rect(Rect2(Vector2(-24, -6), Vector2(48, 26)), Color(0.28, 0.16, 0.08))
	c.draw_rect(Rect2(Vector2(-24, -6), Vector2(48, 26)), Color(0.75, 0.55, 0.25), false, 3.0)
	var lid := -6.0 - (10.0 if awake else 0.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-24, lid), Vector2(-16, lid - 14), Vector2(16, lid - 14), Vector2(24, lid)]), Color(0.36, 0.2, 0.1))
	# The tell: teeth along the seam, always visible.
	for i in 7:
		var x := -21.0 + float(i) * 7.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, -6), Vector2(x + 3.5, -1), Vector2(x + 7, -6)]), Color(0.95, 0.92, 0.8))
	var blink := fposmod(t, 3.2) < 0.25 or awake
	if blink:
		c.draw_circle(Vector2(0, 6), 3.0, Color(1, 0.2, 0.2))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
