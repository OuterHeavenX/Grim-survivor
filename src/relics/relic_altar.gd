extends Node2D
# The reward for a fallen boss: an altar at the start of the next stage.
# Walking into it opens a three-way relic choice weighted by the beaten
# stage's tags. Not a chest: elite loot and altars never share a group.

const PICKUP_RADIUS := 44.0

var tags := PackedStringArray()
var _anim := 0.0
var _taken := false


func _ready() -> void:
	add_to_group("relic_altars")
	z_index = 5


func _physics_process(delta: float) -> void:
	_anim += delta
	queue_redraw()
	if _taken:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p and bool(p.get("alive")) and global_position.distance_to(p.global_position) < PICKUP_RADIUS:
		var m = get_tree().get_first_node_in_group("main")
		if m and m.gm.state == m.gm.State.RUNNING:
			_taken = true
			m.open_relic_altar(self)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_anim * 3.0)
	draw_circle(Vector2(0, 12), 40.0, Color(1.0, 0.8, 0.4, 0.08 + 0.06 * pulse))
	draw_rect(Rect2(-22, -4, 44, 24), Color(0.25, 0.22, 0.2))
	draw_rect(Rect2(-22, -4, 44, 24), Color(1.0, 0.82, 0.45), false, 2.5)
	draw_rect(Rect2(-28, 18, 56, 8), Color(0.32, 0.28, 0.25))
	var lift := sin(_anim * 2.0) * 4.0
	var c := Vector2(0, -22 + lift)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(10, 0), c + Vector2(0, 14), c + Vector2(-10, 0)]), Color(1.0, 0.85, 0.45))
	draw_arc(c, 18.0 + 4.0 * pulse, 0.0, TAU, 24, Color(1, 0.9, 0.6, 0.6), 2.0)
