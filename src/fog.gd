extends Node2D


var fog_radius := 520.0
var fog_color := Color(0.4, 0.5, 0.7, 0.06)

var wind := Vector2(16.0, 7.0)
var _t := 0.0
var _seed := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _seed == 0.0:
		_seed = fposmod(float(get_instance_id()), 100.0)
	queue_redraw()


func _draw() -> void:
	var drift := wind * Vector2(sin(_t * 0.1 + _seed), cos(_t * 0.083 + _seed * 1.7)) * 9.0
	var wobble := 1.0 + sin(_t * 0.4 + _seed) * 0.04
	var r := fog_radius * wobble

	for i in 5:
		var f := 1.0 - float(i) / 5.0
		draw_circle(drift, r * f, Color(fog_color, fog_color.a * (0.35 + 0.65 * f)))
