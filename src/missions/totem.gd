extends Node2D
# A corruption totem for the "Cleanse the Totems" mission: stand beside it
# for CHANNEL seconds to break it. Uncleansed, it pulses and calls a wisp now
# and then, so leaving them standing has a cost.

signal cleansed(totem)

const CHANNEL := 1.2
const REACH := 85.0
const CALL_EVERY := 3.5

var main = null
var progress := 0.0
var done := false
var _t := 0.0
var _call := 1.5


func _ready() -> void:
	add_to_group("stage_objects")
	add_to_group("mission_totems")
	z_index = -1


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if done:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p and bool(p.get("alive")) and p.global_position.distance_to(global_position) <= REACH:
		progress += delta
		if progress >= CHANNEL:
			done = true
			var jm = get_node_or_null("/root/JuiceMan")
			if jm:
				jm.shockwave(global_position, Color(0.6, 1.0, 0.85), 180.0)
				jm.add_trauma(0.15)
			var am = get_node_or_null("/root/AudioMan")
			if am:
				am.play("chest_open", -6.0, 1.2)
			cleansed.emit(self)
	else:
		progress = maxf(0.0, progress - delta * 0.5)
	_call -= delta
	if _call <= 0.0 and main:
		_call = CALL_EVERY
		if main._enemy_count() < main.MAX_ENEMIES:
			main._spawn_enemy("wisp", main.clamp_arena(global_position + Vector2.from_angle(randf() * TAU) * 60.0))


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	if done:
		draw_colored_polygon(PackedVector2Array([Vector2(-14, 10), Vector2(-4, -14), Vector2(6, 2), Vector2(14, 10)]), Color(0.25, 0.25, 0.28))
		draw_circle(Vector2.ZERO, 20.0, Color(0.6, 1.0, 0.85, 0.15))
		return
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, REACH, Color(0.75, 0.2, 1.0, 0.08 + 0.05 * pulse))
	draw_arc(Vector2.ZERO, REACH, 0, TAU, 40, Color(0.8, 0.3, 1.0, 0.5), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The obelisk.
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 14), Vector2(-9, -46), Vector2(0, -60), Vector2(9, -46), Vector2(14, 14)]), Color(0.12, 0.08, 0.14))
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -10), Vector2(0, -40), Vector2(5, -10), Vector2(0, -2)]), Color(0.85, 0.3, 1.0, 0.6 + 0.4 * pulse))
	draw_circle(Vector2(0, -24), 22.0 + 4.0 * pulse, Color(0.8, 0.3, 1.0, 0.12))
	if progress > 0.0:
		draw_arc(Vector2(0, -20), 34.0, -PI * 0.5, -PI * 0.5 + TAU * progress / CHANNEL, 32, Color(0.6, 1.0, 0.85), 5.0)
