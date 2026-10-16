extends Node2D
# The lantern convoy: a wagon and its circle of light. Position is driven by
# the Sunken Road rule; this only draws it, and puts it in "objectives" so
# the off-screen indicator points back to it.

var rule = null
var _t := 0.0


func _ready() -> void:
	add_to_group("convoy")
	z_index = -1


func is_active() -> bool:
	return rule != null and not rule.stopped


func hud_text() -> String:
	return ""


func frac() -> float:
	return 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var aura: float = float(rule.p("aura", 270.0)) if rule else 270.0
	var flick := 0.5 + 0.5 * sin(_t * 7.0)
	draw_circle(Vector2.ZERO, aura, Color(1.0, 0.8, 0.45, 0.07 + 0.02 * flick))
	for i in 24:
		var a := TAU * float(i) / 24.0 + _t * 0.2
		draw_arc(Vector2.ZERO, aura, a, a + TAU / 48.0, 3, Color(1, 0.85, 0.5, 0.55), 3.0)
	draw_rect(Rect2(-34, -20, 68, 40), Color(0.28, 0.2, 0.14))
	draw_rect(Rect2(-34, -20, 68, 40), Color(0.9, 0.7, 0.35), false, 2.0)
	draw_circle(Vector2(-24, 22), 9.0, Color(0.2, 0.15, 0.1))
	draw_circle(Vector2(24, 22), 9.0, Color(0.2, 0.15, 0.1))
	draw_line(Vector2(0, -20), Vector2(0, -48), Color(0.35, 0.28, 0.2), 3.0)
	draw_circle(Vector2(0, -54), 8.0 + 2.0 * flick, Color(1.0, 0.85, 0.4))
	if rule and rule.paused_for != "":
		draw_string(ThemeDB.fallback_font, Vector2(-40, -70), "HALTED", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color(1, 0.8, 0.5))
