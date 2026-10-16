extends Node2D
# A treasure cache on the Drowned Reach seabed. Openable only at low tide by
# standing on it. `opened` is permanent for the stage: the tide coming back
# in never refills it.

const RADIUS := 40.0

var rule = null
var opened := false
var _hold := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("tide_caches")
	z_index = -1


func can_open() -> bool:
	return not opened and rule != null and rule.low_tide() and not rule.stopped


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not can_open():
		_hold = 0.0
		return
	var p = get_tree().get_first_node_in_group("player")
	if p and bool(p.get("alive")) and p.global_position.distance_to(global_position) < RADIUS:
		_hold += delta
		if _hold >= float(rule.p("cache_open", 1.0)):
			open()
	else:
		_hold = 0.0


func open() -> bool:
	if opened or rule == null:
		return false
	opened = true
	rule.open_cache(self)
	return true


func _draw() -> void:
	if opened:
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 16, Color(0.5, 0.6, 0.7, 0.4), 2.0)
		return
	var shown: bool = rule != null and rule.low_tide()
	var a := 1.0 if shown else 0.25
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.95, 0.85, 0.5, 0.08 * a))
	draw_rect(Rect2(-16, -10, 32, 20), Color(0.35, 0.3, 0.22, a))
	draw_rect(Rect2(-16, -10, 32, 20), Color(0.95, 0.85, 0.5, (0.6 + 0.3 * pulse) * a), false, 2.0)
	if shown:
		draw_line(Vector2(0, -26), Vector2(0, -42), Color(1, 0.9, 0.5, 0.9), 3.0)
		draw_circle(Vector2(0, -46), 4.0, Color(1, 0.9, 0.5, 0.9))
	if _hold > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 6.0, -PI * 0.5, -PI * 0.5 + TAU * _hold / float(rule.p("cache_open", 1.0)), 24, Color(1, 1, 1, 0.9), 4.0)
