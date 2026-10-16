extends EnemyBehavior
# Cultist archer: keeps between min_dist and max_dist, then plants its feet
# and paints a line before loosing along it. The line is a TimedHazard, so it
# obeys the same warning floor as everything else. Archer shots share a cap.

const MAX_SHOTS := 10

var _fire := 2.0
var _aim := 0.0
var _strafe := 1.0


func _setup() -> void:
	_fire = randf_range(1.0, pf("interval", 3.4))
	_strafe = 1.0 if randf() < 0.5 else -1.0


func step(delta: float, dir: Vector2) -> Vector2:
	t += delta
	if _aim > 0.0:
		_aim -= delta
		return Vector2.ZERO
	var dist: float = enemy.global_position.distance_to(ppos())
	_fire -= delta
	if _fire <= 0.0 and dist <= pf("max_dist", 430.0) + 80.0:
		_fire = pf("interval", 3.4)
		_shoot()
		return Vector2.ZERO
	if dist < pf("min_dist", 300.0):
		return -dir
	if dist > pf("max_dist", 430.0):
		return dir
	return Vector2(-dir.y, dir.x) * _strafe * 0.6


func _shoot() -> void:
	var m = main()
	if m == null or enemy.get_tree().get_nodes_in_group("enemy_hazards").size() >= MAX_SHOTS:
		return
	var d: Vector2 = (ppos() - enemy.global_position).normalized()
	var from: Vector2 = enemy.global_position + d * 20.0
	var h := TimedHazard.new()
	h.setup(HazardShape.line(from, from + d * pf("length", 560.0), pf("width", 26.0)),
		pf("warn", 0.8), 0.15, float(enemy.dmg), Color(1.0, 0.45, 0.4), "enemy:ranged_cultist", "enemy")
	h.icon = "warn"
	m.add_hazard_node(h)
	_aim = h.warn_time + 0.15


func can_contact() -> bool:
	return true


func draw_body(c: CanvasItem) -> bool:
	robe(c, Color(0.3, 0.1, 0.12), Color(1.0, 0.5, 0.4), Color(1.0, 0.6, 0.4))
	c.draw_arc(Vector2(10, 0), 14.0, -1.2, 1.2, 12, Color(0.55, 0.4, 0.25), 3.0)
	if _aim > 0.0:
		c.draw_circle(Vector2(0, -26), 4.0, Color(1, 0.4, 0.3, 0.9))
	return true
