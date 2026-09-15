extends Node2D

# Enemy-side attacks. The player's weapons use projectile.gd, but that only ever
# damages enemies, so anything that hits the player back needs its own node.
#
# Everything here telegraphs before it bites. A boss that can kill you from
# off-screen with no warning is not difficulty, it is a coin flip, so the
# eruption draws its ring for a beat before it lands and the charge paints its
# lane before the boss commits to it.

const ARENA := 1500.0

# bolt      travels, hits once, dies
# eruption  warns in place, then detonates
# pool      lingers, re-damages on a timer
# lane      a charge telegraph: shows where a boss is about to run, no damage
var mode := "bolt"
var damage := 10.0
var vel := Vector2.ZERO
var radius := 18.0
var life := 4.0
var color := Color(1.0, 0.5, 0.2)
var telegraph := 0.9
var tick := 0.55
var lane_to := Vector2.ZERO

var player = null
var jm = null

var _age := 0.0
var _bit := false
var _cd := 0.0


func setup(p_mode: String, pos: Vector2, dmg: float, col: Color) -> void:
	mode = p_mode
	position = pos
	damage = dmg
	color = col


func _ready() -> void:
	add_to_group("hazards")
	player = get_tree().get_first_node_in_group("player")
	jm = get_node_or_null("/root/JuiceMan")
	z_index = -1 if mode == "pool" or mode == "lane" else 1


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	match mode:
		"bolt":
			_step_bolt(delta)
		"eruption":
			_step_eruption()
		"pool":
			_step_pool(delta)
	queue_redraw()


func _can_bite() -> bool:
	return player != null and is_instance_valid(player) and bool(player.get("alive"))


func _dist_to_player() -> float:
	if not _can_bite():
		return 1e9
	return global_position.distance_to(player.global_position)


func _step_bolt(delta: float) -> void:
	position += vel * delta
	position.x = clampf(position.x, -ARENA, ARENA)
	position.y = clampf(position.y, -ARENA, ARENA)
	if _dist_to_player() < radius + 14.0:
		player.take_damage(damage)
		if jm:
			jm.shockwave(global_position, color, radius * 1.6)
		queue_free()


func _step_eruption() -> void:
	if _bit or _age < telegraph:
		return
	# The warning ring has had its moment; this is where it actually hurts.
	_bit = true
	if _dist_to_player() < radius:
		player.take_damage(damage)
	if jm:
		jm.shockwave(global_position, color, radius * 1.3)
		jm.add_trauma(0.18)


func _step_pool(delta: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	if _dist_to_player() < radius:
		player.take_damage(damage)
		_cd = tick


func _draw() -> void:
	match mode:
		"bolt":
			draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.35))
			draw_circle(Vector2.ZERO, radius * 0.55, color)
		"eruption":
			_draw_eruption()
		"pool":
			_draw_pool()
		"lane":
			_draw_lane()


func _draw_eruption() -> void:
	if _age < telegraph:
		# Warning: an outline that stays put and a disc that fills towards the
		# moment of impact, so the deadline is readable at a glance.
		var f := clampf(_age / telegraph, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.9), 3.0, true)
		draw_circle(Vector2.ZERO, radius * f, Color(color.r, color.g, color.b, 0.22))
		return
	var g := clampf(1.0 - (_age - telegraph) / maxf(0.01, life - telegraph), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * (0.6 + 0.4 * g), Color(color.r, color.g, color.b, 0.55 * g))


func _draw_pool() -> void:
	var fade := clampf(minf(_age / 0.4, (life - _age) / 0.8), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.26 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.5 * fade), 2.0, true)


func _draw_lane() -> void:
	var fade := clampf((life - _age) / life, 0.0, 1.0)
	var d: Vector2 = lane_to - global_position
	if d.length() < 1.0:
		return
	var n := d.normalized()
	var perp := Vector2(-n.y, n.x) * radius
	var pts := PackedVector2Array([-perp, perp, d + perp, d - perp])
	draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.18 * fade))
	draw_line(-perp, d - perp, Color(color.r, color.g, color.b, 0.55 * fade), 2.0, true)
	draw_line(perp, d + perp, Color(color.r, color.g, color.b, 0.55 * fade), 2.0, true)
