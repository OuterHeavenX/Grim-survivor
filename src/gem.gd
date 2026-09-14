extends Node2D


var value := 1
var vel := Vector2.ZERO

var gm = null
var player = null
var _age := 0.0


func _ready() -> void:
	add_to_group("gems")
	gm = get_node("/root/GameManager")
	vel = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 170.0)


func _physics_process(delta: float) -> void:
	_age += delta
	position += vel * delta
	vel = vel.move_toward(Vector2.ZERO, 420.0 * delta)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var d: Vector2 = player.global_position - global_position
	var dist := d.length()
	if dist < 95.0 * gm.magnet_mult():
		vel = d.normalized() * 720.0 if dist > 1.0 else Vector2.ZERO
	if dist < 28.0:
		gm.add_xp(value)
		get_node("/root/AudioMan").play_gem()
		get_node("/root/JuiceMan").gem_sparkle(global_position)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var bob := sin(_age * 5.0) * 2.0
	var col := Color(0.35, 1.0, 0.45)
	if value >= 20:
		col = Color(0.9, 0.45, 1.0)
	elif value >= 5:
		col = Color(0.45, 0.7, 1.0)
	elif value >= 3:
		col = Color(0.55, 1.0, 0.6)
	var s := 7.0 + minf(float(value), 10.0)
	draw_circle(Vector2(0, bob), s + 3.0, Color(col, 0.22))
	draw_colored_polygon([
		Vector2(0, -s + bob), Vector2(s * 0.7, bob),
		Vector2(0, s + bob), Vector2(-s * 0.7, bob),
	], col)
	draw_colored_polygon([
		Vector2(0, -s * 0.45 + bob), Vector2(s * 0.32, bob),
		Vector2(0, s * 0.45 + bob), Vector2(-s * 0.32, bob),
	], Color(1, 1, 1, 0.75))
