extends Node2D


var active := false
var origin := Vector2.ZERO
var cur := Vector2.ZERO


func set_joy(a: bool, o: Vector2, c: Vector2) -> void:
	active = a
	origin = o
	cur = c
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var d := (cur - origin).limit_length(70.0)
	draw_circle(origin, 80.0, Color(1, 1, 1, 0.08))
	draw_arc(origin, 80.0, 0, TAU, 48, Color(1, 1, 1, 0.28), 3.0)
	draw_circle(origin + d, 32.0, Color(0.75, 0.8, 0.95, 0.3))
	draw_arc(origin + d, 32.0, 0, TAU, 32, Color(1, 1, 1, 0.45), 2.0)
