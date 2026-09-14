extends Node2D


var _rng := RandomNumberGenerator.new()
var _stars: Array = []


func _ready() -> void:
	_rng.seed = 1337
	var vp := get_viewport_rect().size
	for i in 150:
		_stars.append({
			"p": Vector2(_rng.randf() * 900.0, _rng.randf() * 700.0),
			"r": _rng.randf_range(1.0, 2.6),
			"a": _rng.randf_range(0.25, 0.8),
		})
	get_tree().root.size_changed.connect(queue_redraw)


func _draw() -> void:
	var vp := get_viewport_rect().size

	var bands := 28
	for i in bands:
		var f := float(i) / float(bands)
		var c := Color(0.008, 0.012, 0.03).lerp(Color(0.045, 0.045, 0.095), f * f)
		draw_rect(Rect2(0, vp.y * f / bands * bands / bands, vp.x, vp.y / bands + 1.0), c)

	draw_circle(Vector2(vp.x * 0.2, vp.y * 0.3), 150.0, Color(0.25, 0.12, 0.35, 0.05))
	draw_circle(Vector2(vp.x * 0.2, vp.y * 0.3), 90.0, Color(0.3, 0.15, 0.4, 0.05))
	draw_circle(Vector2(vp.x * 0.9, vp.y * 0.55), 180.0, Color(0.1, 0.2, 0.35, 0.05))

	for s in _stars:
		var p: Vector2 = s["p"]
		var sx: float = p.x / 900.0 * vp.x
		var sy: float = p.y / 700.0 * vp.y * 0.8
		draw_circle(Vector2(sx, sy), float(s["r"]), Color(0.8, 0.85, 1.0, float(s["a"])))

	var moon := Vector2(vp.x * 0.78, vp.y * 0.16)
	draw_circle(moon, 74.0, Color(0.75, 0.82, 0.95, 0.1))
	draw_circle(moon, 52.0, Color(0.78, 0.85, 0.97, 0.16))
	draw_circle(moon, 38.0, Color(0.82, 0.88, 1.0, 0.95))
	draw_circle(moon + Vector2(-10, -6), 30.0, Color(0.88, 0.92, 1.0, 0.5))
