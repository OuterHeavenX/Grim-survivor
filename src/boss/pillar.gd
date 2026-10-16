extends Node2D
# A roadblock pillar: an obstacle registered with the stage director while it
# stands. It expires on its own, and shatters with a telegraphed shockwave
# when the Warden charges into it.

const RADIUS := 34.0

var life := 14.0
var _age := 0.0
var _obstacle := {}
var _shatter_in := -1.0


func _ready() -> void:
	add_to_group("pillars")
	z_index = 2
	_obstacle = {"pos": global_position, "radius": RADIUS}
	var m = get_tree().get_first_node_in_group("main")
	if m and m.director:
		m.director.add_obstacle(_obstacle)


func shatter_in(t: float) -> void:
	_shatter_in = maxf(0.05, t)


func shatter() -> void:
	var m = get_tree().get_first_node_in_group("main")
	if m and m.boss and is_instance_valid(m.boss) and m.boss.controller:
		var h: TimedHazard = m.boss.controller.spawn_hazard(HazardShape.circle(global_position, 130.0), 0.65, 0.3,
			float(m.boss.dmg) * 0.8, "pillar_shatter")
		h.icon = "warn"
	if m and m.jm:
		m.jm.shockwave(global_position, Color(0.85, 0.8, 0.7), 160.0)
	queue_free()


func _physics_process(delta: float) -> void:
	_age += delta
	if _shatter_in > 0.0:
		_shatter_in -= delta
		if _shatter_in <= 0.0:
			shatter()
			return
	if _age >= life:
		queue_free()
	queue_redraw()


func _exit_tree() -> void:
	var m = get_tree().get_first_node_in_group("main") if is_inside_tree() else null
	if m and m.director and is_instance_valid(m.director):
		m.director.remove_obstacle(_obstacle)


func _draw() -> void:
	var fade := clampf((life - _age) / 1.0, 0.25, 1.0)
	draw_circle(Vector2(4, 8), RADIUS, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.36, 0.32, 0.28, fade))
	draw_circle(Vector2(-6, -6), RADIUS * 0.6, Color(0.5, 0.45, 0.38, fade))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 28, Color(0.95, 0.8, 0.45, 0.8 * fade), 3.0)
	if _shatter_in > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 8.0, 0.0, TAU, 28, Color(1, 0.4, 0.3, 0.9), 4.0)
