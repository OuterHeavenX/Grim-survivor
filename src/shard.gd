extends Node2D


var value := 1
var vel := Vector2.ZERO

var gm = null
var player = null
var _age := 0.0

# Pickups used to live until collected, so anything that drifted out of reach
# stayed forever: a long run accumulated thousands, each still running physics
# and redrawing every frame. Give them a generous life and fade them out.
const LIFETIME := 45.0
const FADE := 5.0


func _ready() -> void:
	add_to_group("shards")
	gm = get_node("/root/GameManager")
	vel = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 170.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	if _age > LIFETIME - FADE:
		modulate.a = clampf((LIFETIME - _age) / FADE, 0.0, 1.0)
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
		gm.add_shards(value)
		get_node("/root/AudioMan").play_shard()
		get_node("/root/JuiceMan").shard_sparkle(global_position)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var bob := sin(_age * 6.0) * 2.5
	var flick := 1.0 + sin(_age * 11.0) * 0.15
	var s := (6.0 + minf(float(value), 8.0)) * flick

	draw_circle(Vector2(0, bob), s + 7.0, Color(0.6, 0.2, 1.0, 0.2))

	draw_colored_polygon([
		Vector2(0, -s * 1.5 + bob), Vector2(s * 0.65, bob),
		Vector2(0, s + bob), Vector2(-s * 0.65, bob),
	], Color(0.62, 0.25, 1.0, 0.95))
	draw_circle(Vector2(0, bob * 0.9), s * 0.38, Color(0.9, 0.75, 1.0))
