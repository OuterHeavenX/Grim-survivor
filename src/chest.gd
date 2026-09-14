extends Node2D



var opened := false
var _age := 0.0


func _ready() -> void:
	add_to_group("chests")


func _physics_process(delta: float) -> void:
	_age += delta
	var player = get_tree().get_first_node_in_group("player")
	if player and bool(player.get("alive")) and not opened:
		if global_position.distance_to(player.global_position) < 36.0:
			opened = true
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("open_chest"):
				main.open_chest(self)
	queue_redraw()


func _draw() -> void:
	var bob := sin(_age * 3.5) * 3.0
	var o := Vector2(0, bob)

	var pulse := 0.5 + 0.5 * sin(_age * 4.0)
	draw_circle(o, 34.0, Color(1.0, 0.75, 0.25, 0.1 + 0.08 * pulse))

	draw_set_transform(o + Vector2(0, 20), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_rect(Rect2(o + Vector2(-24, -6), Vector2(48, 26)), Color(0.28, 0.16, 0.08))
	draw_rect(Rect2(o + Vector2(-24, -6), Vector2(48, 26)), Color(1.0, 0.75, 0.25), false, 3.0)

	draw_colored_polygon([
		o + Vector2(-24, -6), o + Vector2(-16, -20),
		o + Vector2(16, -20), o + Vector2(24, -6),
	], Color(0.36, 0.2, 0.1))
	draw_line(o + Vector2(-24, -6), o + Vector2(-16, -20), Color(1.0, 0.75, 0.25), 3.0)
	draw_line(o + Vector2(24, -6), o + Vector2(16, -20), Color(1.0, 0.75, 0.25), 3.0)
	draw_line(o + Vector2(-16, -20), o + Vector2(16, -20), Color(1.0, 0.75, 0.25), 3.0)

	draw_rect(Rect2(o + Vector2(-5, -10), Vector2(10, 12)), Color(1.0, 0.8, 0.3))
	draw_circle(o + Vector2(0, -4), 2.5, Color(0.25, 0.12, 0.04))

	var g := int(_age * 3.0) % 3
	var glints: Array = [o + Vector2(-18, -14), o + Vector2(14, 2), o + Vector2(2, -24)]
	var gp: Vector2 = glints[g]
	draw_line(gp + Vector2(-5, 0), gp + Vector2(5, 0), Color(1, 1, 1, 0.9), 2.0)
	draw_line(gp + Vector2(0, -5), gp + Vector2(0, 5), Color(1, 1, 1, 0.9), 2.0)
