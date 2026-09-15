extends Node2D
# A weapon relic lying in the stage. Unlike gems and shards it is not drawn to
# the player by the magnet -- it has to be found -- so it sits still and glows.

signal collected

const PICKUP_RADIUS := 46.0

var weapon_id := ""
var tint := Color(1.0, 0.85, 0.4)

var _anim := 0.0
var _taken := false


func _ready() -> void:
	z_index = 6
	add_to_group("relics")


func _physics_process(delta: float) -> void:
	_anim += delta
	queue_redraw()
	if _taken:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return
	if global_position.distance_to(p.global_position) < PICKUP_RADIUS:
		_taken = true
		collected.emit()
		queue_free()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_anim * 3.0)
	var lift := sin(_anim * 2.0) * 3.0

	# A glow on the ground so it reads from a distance without a minimap.
	for i in 3:
		var f := 1.0 - float(i) / 3.0
		draw_circle(Vector2(0, 10), 30.0 * (1.0 + f), Color(tint, 0.06 + 0.05 * pulse * f))

	draw_arc(Vector2(0, 10), 26.0 + 3.0 * pulse, 0.0, TAU, 32,
		Color(tint, 0.35 + 0.25 * pulse), 2.0)

	var c := Vector2(0, lift)
	draw_colored_polygon([
		c + Vector2(0, -16), c + Vector2(11, 0), c + Vector2(0, 16), c + Vector2(-11, 0),
	], Color(tint, 0.95))
	draw_colored_polygon([
		c + Vector2(0, -8), c + Vector2(5, 0), c + Vector2(0, 8), c + Vector2(-5, 0),
	], Color(1, 1, 1, 0.8))
