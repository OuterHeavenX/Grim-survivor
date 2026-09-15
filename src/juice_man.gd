extends Node



const MAX_SHAKE := 26.0
const DECAY := 1.5

var trauma := 0.0
var _hitstop := false


class SoulWisp extends Node2D:
	var t := 0.0
	var dur := 0.9

	func _process(d: float) -> void:
		t += d
		position.y -= 70.0 * d
		queue_redraw()
		if t >= dur:
			queue_free()

	func _draw() -> void:
		var a := clampf(1.0 - t / dur, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 9.0, Color(0.55, 0.75, 1.0, a * 0.3))
		draw_circle(Vector2.ZERO, 4.0, Color(0.85, 0.95, 1.0, a))


class Sparkle extends Node2D:
	var t := 0.0
	var dur := 0.28

	func _process(d: float) -> void:
		t += d
		queue_redraw()
		if t >= dur:
			queue_free()

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var a := 1.0 - f
		draw_arc(Vector2.ZERO, 6.0 + 26.0 * f, 0, TAU, 24, Color(0.6, 1.0, 0.6, a * 0.9), 3.0)
		draw_circle(Vector2.ZERO, 5.0 * a + 1.0, Color(1, 1, 1, a))


class ShardSparkle extends Node2D:
	var t := 0.0
	var dur := 0.34

	func _process(d: float) -> void:
		t += d
		queue_redraw()
		if t >= dur:
			queue_free()

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var a := 1.0 - f
		draw_arc(Vector2.ZERO, 6.0 + 30.0 * f, 0, TAU, 24, Color(0.7, 0.35, 1.0, a * 0.9), 3.0)
		draw_circle(Vector2.ZERO, 5.0 * a + 1.0, Color(0.92, 0.8, 1.0, a))


class ShockRing extends Node2D:
	var t := 0.0
	var dur := 0.45
	var max_r := 140.0
	var ring_color := Color(1.0, 0.7, 0.3)

	func _process(d: float) -> void:
		t += d
		queue_redraw()
		if t >= dur:
			queue_free()

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var a := 1.0 - f
		var e := 1.0 - (1.0 - f) * (1.0 - f)
		draw_arc(Vector2.ZERO, max_r * e, 0, TAU, 56, Color(ring_color, a * 0.85), 7.0 * a + 2.0)
		draw_arc(Vector2.ZERO, max_r * e * 0.72, 0, TAU, 48, Color(1, 1, 1, a * 0.45), 3.0)


class LightPillar extends Node2D:
	var t := 0.0
	var dur := 0.9

	func _process(d: float) -> void:
		t += d
		queue_redraw()
		if t >= dur:
			queue_free()

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var a := 1.0 - f

		var top_fade := 0.55
		for i in 4:
			var w := 56.0 - float(i) * 12.0
			draw_rect(Rect2(-w / 2.0, -460.0, w, 460.0),
				Color(0.55, 0.72, 1.0, a * 0.07 * top_fade * (1.0 - float(i) / 4.0)))
		draw_rect(Rect2(-7, -460.0, 14, 460.0), Color(0.8, 0.9, 1.0, a * 0.32 * top_fade))

		var e := 1.0 - (1.0 - f) * (1.0 - f)
		draw_arc(Vector2.ZERO, 30.0 + 130.0 * e, 0, TAU, 48, Color(0.6, 0.8, 1.0, a * 0.8), 5.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - DECAY * delta)
	var cam = get_tree().get_first_node_in_group("shake_camera")
	if cam == null:
		return
	if trauma > 0.003:
		var t := Time.get_ticks_msec() / 1000.0
		var s := trauma * trauma * MAX_SHAKE
		cam.offset = Vector2(
			s * (0.6 * sin(t * 39.7) + 0.4 * sin(t * 23.3)),
			s * (0.6 * cos(t * 34.1) + 0.4 * cos(t * 27.7)))
	else:
		cam.offset = Vector2.ZERO


func add_trauma(a: float) -> void:
	trauma = minf(1.0, trauma + a)




func hit_stop(dur: float = 0.05) -> void:
	if _hitstop:
		return
	_hitstop = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop = false


func is_hitstop() -> bool:
	return _hitstop


func _run_node():
	var main = get_tree().get_first_node_in_group("main")
	if main == null:
		return null
	return main.get("run")



# Death-pose sheets built by tools/build_sprites.gd, keyed by enemy type.
# A type missing here just gets the particle burst, as before.
const DEATH_SHEETS := {
	"skeleton": 6, "husk": 6, "wisp": 6, "bogling": 6, "mire": 6,
	"imp": 6, "titan": 6, "herald": 10, "maw": 10, "cinderking": 14,
}
const DEATH_FPS := 14.0
const CORPSE_LINGER := 2.5
const CORPSE_FADE := 1.0
# Bodies are cosmetic, so drop new ones rather than let a big wave pile up.
const MAX_CORPSES := 24


func death_fx(pos: Vector2, big: bool = false, etype: String = "", facing: float = 0.0) -> void:
	var run = _run_node()
	if run == null:
		return
	var p := CPUParticles2D.new()
	p.amount = 26 if big else 14
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 12.0 if big else 8.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 240.0 if big else 190.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 6.0 if big else 4.0
	p.color = Color(0.5, 0.28, 0.75, 0.95)
	p.position = pos
	p.z_index = 40
	run.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var w := SoulWisp.new()
	w.position = pos + Vector2(0, -10)
	w.z_index = 41
	run.add_child(w)
	_corpse(run, pos, etype, facing)


func _corpse(run, pos: Vector2, etype: String, facing: float) -> void:
	if not DEATH_SHEETS.has(etype):
		return
	if get_tree().get_nodes_in_group("corpses").size() >= MAX_CORPSES:
		return
	var tex: Texture2D = load("res://assets/sprites/%s_death.png" % etype)
	if tex == null:
		return
	var frames: int = int(DEATH_SHEETS[etype])
	var body := Sprite2D.new()
	body.texture = tex
	body.hframes = frames
	body.position = pos
	body.rotation = facing
	# Below the living, above the ground.
	body.z_index = -1
	body.add_to_group("corpses")
	run.add_child(body)

	var t := body.create_tween()
	t.tween_property(body, "frame", frames - 1, float(frames) / DEATH_FPS).from(0)
	t.tween_interval(CORPSE_LINGER)
	t.tween_property(body, "modulate:a", 0.0, CORPSE_FADE)
	t.tween_callback(body.queue_free)



func gold_burst(pos: Vector2) -> void:
	var run = _run_node()
	if run == null:
		return
	var p := CPUParticles2D.new()
	p.amount = 34
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 7.0
	p.color = Color(1.0, 0.78, 0.28, 0.95)
	p.position = pos
	p.z_index = 42
	run.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func gem_sparkle(pos: Vector2) -> void:
	var run = _run_node()
	if run == null:
		return
	var s := Sparkle.new()
	s.position = pos
	s.z_index = 41
	run.add_child(s)



func shard_sparkle(pos: Vector2) -> void:
	var run = _run_node()
	if run == null:
		return
	var s := ShardSparkle.new()
	s.position = pos
	s.z_index = 41
	run.add_child(s)



func shockwave(pos: Vector2, color: Color, max_r := 140.0) -> void:
	var run = _run_node()
	if run == null:
		return
	var r := ShockRing.new()
	r.position = pos
	r.ring_color = color
	r.max_r = max_r
	r.z_index = 44
	run.add_child(r)



func pillar(pos: Vector2) -> void:
	var run = _run_node()
	if run == null:
		return
	var p := LightPillar.new()
	p.position = pos
	p.z_index = 43
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	run.add_child(p)
