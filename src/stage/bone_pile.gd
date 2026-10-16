extends Node2D
# A bone pile in the Bone Desert. Grows when skeletal foes fall near it.
# The player shatters it by walking over it (XP per fragment); necromancers
# and the Pale Herald consume fragments instead.

var rule = null
var fragments := 1
var max_fragments := 5
var _t := 0.0
var _cd := 0.0


func _ready() -> void:
	add_to_group("bone_piles")
	z_index = -1


func add_fragment() -> void:
	fragments = mini(fragments + 1, max_fragments)


func consume(n: int) -> int:
	var k := mini(n, fragments)
	fragments -= k
	return k


func _physics_process(delta: float) -> void:
	_t += delta
	_cd = maxf(0.0, _cd - delta)
	if fragments > 0 and _cd <= 0.0:
		var p = get_tree().get_first_node_in_group("player")
		if p and bool(p.get("alive")) and p.global_position.distance_to(global_position) < 40.0:
			shatter()
	queue_redraw()


func shatter() -> int:
	if fragments <= 0 or rule == null:
		return 0
	var mult: int = rule.pile_multiplier() if rule.has_method("pile_multiplier") else 1
	var value: int = fragments * int(rule.p("pile_xp", 2)) * mult
	fragments = 0
	_cd = 1.0
	rule.main.spawn_gem(global_position, value)
	if rule.main.jm:
		rule.main.jm.shockwave(global_position, Color(0.95, 0.9, 0.75), 70.0)
	return value


func _draw() -> void:
	var n := fragments
	draw_circle(Vector2(3, 6), 20.0, Color(0, 0, 0, 0.3))
	if n <= 0:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 16, Color(0.6, 0.56, 0.48, 0.5), 2.0)
		return
	for i in n:
		var a := TAU * float(i) / float(maxi(1, n)) + 0.4
		var c := Vector2.from_angle(a) * (6.0 + float(n))
		draw_line(c - Vector2(9, 3).rotated(a), c + Vector2(9, 3).rotated(a), Color(0.9, 0.87, 0.76), 5.0)
	draw_circle(Vector2(0, -4), 7.0, Color(0.92, 0.9, 0.8))
	# Fragment count as pips above the pile: mobile-readable, colour-free.
	for i in n:
		draw_circle(Vector2(-10.0 + float(i) * 5.0, -22.0), 2.2, Color(1, 1, 1, 0.9))
