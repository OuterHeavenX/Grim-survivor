extends Node2D
# A furnace mouth at the head of one heat lane. It lives exactly as long as
# its lane. While the lane burns, the small zone behind the mouth blesses a
# player standing in it (once per furnace).

var rule = null
var lane: TimedHazard = null
var dir := Vector2.RIGHT
var _blessed := false
var _t := 0.0

const ZONE_BACK := 100.0


func _ready() -> void:
	add_to_group("furnaces")
	z_index = 3


func boon_center() -> Vector2:
	return global_position - dir * ZONE_BACK


func _physics_process(delta: float) -> void:
	_t += delta
	if lane == null or not is_instance_valid(lane):
		queue_free()
		return
	if lane.is_damaging() and not _blessed and rule and rule.has_method("grant_boon"):
		var p = get_tree().get_first_node_in_group("player")
		if p and bool(p.get("alive")) and p.global_position.distance_to(boon_center()) <= float(rule.p("boon_radius", 90.0)):
			_blessed = true
			rule.grant_boon()
	queue_redraw()


func _draw() -> void:
	var a := dir.angle()
	var hot := lane != null and is_instance_valid(lane) and lane.is_damaging()
	draw_set_transform(Vector2.ZERO, a, Vector2.ONE)
	draw_rect(Rect2(-46, -44, 52, 88), Color(0.18, 0.1, 0.08))
	draw_rect(Rect2(-46, -44, 52, 88), Color(0.9, 0.5, 0.2), false, 3.0)
	draw_rect(Rect2(-6, -30, 14, 60), Color(1.0, 0.6, 0.2) if hot else Color(0.4, 0.15, 0.08))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if rule and lane and is_instance_valid(lane) and lane.is_threat():
		# The blessing zone: a dashed circle with a plus, so "stand here" reads
		# by shape.
		var c := boon_center() - global_position
		var r: float = float(rule.p("boon_radius", 90.0))
		for i in 16:
			var s := TAU * float(i) / 16.0
			draw_arc(c, r, s, s + TAU / 32.0, 3, Color(1.0, 0.85, 0.4, 0.75 if hot else 0.4), 3.0)
		draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), Color(1, 0.9, 0.5, 0.9), 3.0)
		draw_line(c + Vector2(0, -10), c + Vector2(0, 10), Color(1, 0.9, 0.5, 0.9), 3.0)
