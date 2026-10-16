extends BossAttack
# Passive: the Warden's tower shield. Hits arriving inside the shield's arc
# lose `block` of their damage. The shield turns towards the player at a
# limited rate, so circling round it is how you flank.

const TURN_RATE := 1.4

var facing := Vector2.DOWN
var _shield: Node2D = null


func start() -> void:
	facing = (ppos() - bpos()).normalized()
	_shield = ShieldArc.new()
	_shield.host = self
	ctl.own_object(_shield)


func tick(delta: float) -> void:
	var want := (ppos() - bpos())
	if want.length() < 1.0:
		return
	var diff := wrapf(want.angle() - facing.angle(), -PI, PI)
	var step := clampf(diff, -TURN_RATE * delta, TURN_RATE * delta)
	facing = facing.rotated(step)


func blocks(from_pos: Vector2) -> bool:
	var d := from_pos - bpos()
	if d.length() < 1.0:
		return false
	return absf(wrapf(d.angle() - facing.angle(), -PI, PI)) <= pf("arc", 1.05)


func modify_damage(amount: float, from_pos: Vector2, _source: String) -> float:
	return amount * (1.0 - pf("block", 0.7)) if blocks(from_pos) else amount


func stop() -> void:
	if _shield and is_instance_valid(_shield):
		_shield.queue_free()


class ShieldArc extends Node2D:
	var host = null

	func _process(_d: float) -> void:
		if host == null or not is_instance_valid(host.ctl.boss):
			return
		global_position = host.ctl.boss.global_position
		z_index = 6
		queue_redraw()

	func _draw() -> void:
		var a: float = host.facing.angle()
		var arc: float = host.pf("arc", 1.05)
		draw_arc(Vector2.ZERO, 78.0, a - arc, a + arc, 24, Color(0.85, 0.85, 0.95, 0.85), 10.0)
		draw_arc(Vector2.ZERO, 86.0, a - arc, a + arc, 24, Color(1, 0.85, 0.4, 0.6), 3.0)
