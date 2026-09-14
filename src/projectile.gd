extends Node2D



var mode := "dagger"
var damage := 10.0
var vel := Vector2.ZERO
var pierce := 1
var life := 2.0
var aoe := 0.0
var weapon_lvl := 1
var orbit_index := 0
var orbit_count := 1
var orbit_radius := 95.0
var orbit_speed := 2.7
var orbit_angle := 0.0
var zap_points := PackedVector2Array()
var ring_radius := 0.0
var ring_max := 120.0
var ring_t := 0.0
var ring_color := Color(0.5, 0.85, 1.0, 0.8)
var slow_mult := 0.5
var slow_dur := 2.0
var scythe_radius := 150.0
var scythe_speed := 1.6
var raven_target = null
var cloud_radius := 140.0

var facing := Vector2.RIGHT
var bulwark_radius := 180.0

var evo := false

var gm = null
var main = null
var _hit := {}
var _hit_cd := {}
var _hits := 0
var _age := 0.0
var _exploded := false


func setup(p_mode: String, p_damage: float, pos: Vector2) -> void:
	mode = p_mode
	damage = p_damage
	position = pos
	if mode == "frost":
		life = 0.7
	elif mode == "zap":
		life = 0.25
	elif mode == "boom":
		life = 0.35


func setup_blade(index: int, count: int) -> void:
	mode = "blade"
	orbit_index = index
	orbit_count = maxi(1, count)
	orbit_angle = TAU * float(index) / float(maxi(1, count))
	position = Vector2.from_angle(orbit_angle) * orbit_radius


func setup_scythe() -> void:
	mode = "scythe"
	orbit_angle = 0.0
	position = Vector2.from_angle(orbit_angle) * scythe_radius


func setup_raven(p_damage: float, pos: Vector2, p_pierce: int) -> void:
	mode = "raven"
	damage = p_damage
	position = pos
	pierce = p_pierce
	life = 3.0
	vel = Vector2.from_angle(randf() * TAU) * 300.0


func _ready() -> void:
	gm = get_node("/root/GameManager")
	main = get_tree().get_first_node_in_group("main")
	if mode == "blade":
		orbit_angle = TAU * float(orbit_index) / float(maxi(1, orbit_count))


func _physics_process(delta: float) -> void:
	_age += delta
	match mode:
		"dagger":
			_tick_dagger(delta)
		"sdagger":
			_tick_dagger(delta)
		"bulwark":
			_tick_bulwark(delta)
		"fireball":
			_tick_fireball(delta)
		"frost":
			_tick_frost(delta)
		"blade":
			_tick_blade(delta)
		"scythe":
			_tick_scythe(delta)
		"raven":
			_tick_raven(delta)
		"lance":
			_tick_lance(delta)
		"miasma":
			_tick_miasma(delta)
		"comet":
			_tick_comet(delta)
		"zap", "boom":
			if _age >= life:
				queue_free()
	queue_redraw()


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func _blade_damage() -> float:
	return 9.0 * (1.0 + 0.3 * float(weapon_lvl - 1)) * gm.might_mult() * (2.0 if evo else 1.0)


func _seg_dist(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (a + ab * t).distance_to(p)


func _tick_dagger(delta: float) -> void:
	var prev := global_position
	position += vel * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in _enemies():
		var en = e
		if _hit.has(en.get_instance_id()):
			continue
		if _seg_dist(prev, global_position, en.global_position) < 14.0 + float(en.get("body_radius")):
			_hit[en.get_instance_id()] = true
			en.take_damage(damage, global_position, 120.0)
			_hits += 1
			if _hits > pierce:
				queue_free()
				return


func _tick_fireball(delta: float) -> void:
	var prev := global_position
	position += vel * delta
	life -= delta
	var boom := life <= 0.0
	if not boom:
		for e in _enemies():
			var en = e
			if _seg_dist(prev, global_position, en.global_position) < 14.0 + float(en.get("body_radius")):
				boom = true
				break
	if boom and not _exploded:
		_exploded = true
		get_node("/root/AudioMan").play_ranged("explosion", -5.0, 0.9, 1.1)
		get_node("/root/JuiceMan").add_trauma(0.3)
		_explode()


func _explode() -> void:
	for e in _enemies():
		var en = e
		if global_position.distance_to(en.global_position) < aoe + float(en.get("body_radius")):
			en.take_damage(damage, global_position, 220.0)
	if main and main.has_method("spawn_boom"):
		main.spawn_boom(global_position, aoe)
	queue_free()


func _tick_frost(delta: float) -> void:
	ring_t += delta
	ring_radius = ring_max * clampf(ring_t / 0.35, 0.0, 1.0)
	for e in _enemies():
		var en = e
		if _hit.has(en.get_instance_id()):
			continue
		if global_position.distance_to(en.global_position) < ring_radius + float(en.get("body_radius")):
			_hit[en.get_instance_id()] = true
			en.take_damage(damage, global_position, 60.0)
			en.apply_slow(slow_mult, slow_dur)
	if _age >= life:
		queue_free()


func _tick_blade(delta: float) -> void:
	orbit_angle += orbit_speed * delta
	var rad := orbit_radius * (1.45 if evo else 1.0)
	position = Vector2.from_angle(orbit_angle) * rad
	for k in _hit_cd.keys():
		_hit_cd[k] = float(_hit_cd[k]) - delta
	for e in _enemies():
		var en = e
		var id: int = en.get_instance_id()
		if float(_hit_cd.get(id, 0.0)) > 0.0:
			continue
		if global_position.distance_to(en.global_position) < 30.0 + float(en.get("body_radius")):
			_hit_cd[id] = 0.45
			en.take_damage(_blade_damage(), global_position, 90.0)


func _scythe_damage() -> float:
	return 22.0 * (1.0 + 0.35 * float(weapon_lvl - 1)) * gm.might_mult() * (2.2 if evo else 1.0)



func _tick_scythe(delta: float) -> void:
	orbit_angle += scythe_speed * delta
	var rad := scythe_radius * (1.4 if evo else 1.0)
	position = Vector2.from_angle(orbit_angle) * rad
	for k in _hit_cd.keys():
		_hit_cd[k] = float(_hit_cd[k]) - delta
	for e in _enemies():
		var en = e
		var id: int = en.get_instance_id()
		if float(_hit_cd.get(id, 0.0)) > 0.0:
			continue
		if global_position.distance_to(en.global_position) < (64.0 if evo else 44.0) + float(en.get("body_radius")):
			_hit_cd[id] = 0.5


			var pull_from: Vector2 = en.global_position + (en.global_position - main.player.global_position).normalized() * (200.0 if evo else 120.0)
			en.take_damage(_scythe_damage(), pull_from, 220.0 if evo else 150.0)
			get_node("/root/AudioMan").play("scythe_swing", -10.0, randf_range(0.9, 1.1))


func _tick_raven(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if raven_target == null or not is_instance_valid(raven_target) or _hit.has(raven_target.get_instance_id()):
		raven_target = null
		var best = null
		var bd := 700.0
		for e in _enemies():
			var en = e
			if _hit.has(en.get_instance_id()):
				continue
			var d := global_position.distance_to(en.global_position)
			if d < bd:
				bd = d
				best = en
		raven_target = best
	if raven_target != null:
		var spd := 700.0 if evo else 520.0
		var want: Vector2 = (raven_target.global_position - global_position).normalized() * spd
		vel = vel.lerp(want, clampf(6.0 * delta, 0.0, 1.0))
	else:
		vel = vel.move_toward(Vector2.ZERO, 300.0 * delta)
	position += vel * delta
	for e in _enemies():
		var en = e
		if _hit.has(en.get_instance_id()):
			continue
		if global_position.distance_to(en.global_position) < 20.0 + float(en.get("body_radius")):
			_hit[en.get_instance_id()] = true
			en.take_damage(damage, global_position, 60.0)
			raven_target = null
			_hits += 1
			if _hits >= pierce:
				queue_free()
				return



func _tick_lance(delta: float) -> void:
	var prev := global_position
	position += vel * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in _enemies():
		var en = e
		if _hit.has(en.get_instance_id()):
			continue
		if _seg_dist(prev, global_position, en.global_position) < 20.0 + float(en.get("body_radius")):
			_hit[en.get_instance_id()] = true
			en.take_damage(damage, global_position, 260.0)
			_hits += 1
			if _hits > pierce:
				queue_free()
				return




func _tick_bulwark(delta: float) -> void:
	if not _exploded:
		_exploded = true
		get_node("/root/AudioMan").play("explosion", -8.0, 0.6)
		get_node("/root/JuiceMan").add_trauma(0.3)
		var base_ang := facing.angle()
		for e in _enemies():
			var en = e
			var off: Vector2 = en.global_position - global_position
			if off.length() > bulwark_radius + float(en.get("body_radius")):
				continue
			var ang_diff := absf(wrapf(off.angle() - base_ang, -PI, PI))
			if ang_diff > 1.1:
				continue

			en.take_damage(damage, global_position - facing * 60.0, 520.0)
	life -= delta
	if life <= 0.0:
		queue_free()


var _tick_t := 0.0


func _tick_miasma(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = 0.5
		for e in _enemies():
			var en = e
			if global_position.distance_to(en.global_position) < cloud_radius + float(en.get("body_radius")):
				en.take_damage(damage, global_position, 30.0)
				en.apply_slow(0.65, slow_dur)



func _tick_comet(delta: float) -> void:
	if _age >= life:
		get_node("/root/AudioMan").play_ranged("explosion", -6.0, 0.8, 1.0)
		get_node("/root/JuiceMan").add_trauma(0.25)
		for e in _enemies():
			var en = e
			if global_position.distance_to(en.global_position) < aoe + float(en.get("body_radius")):
				en.take_damage(damage, global_position, 260.0)
		if main and main.has_method("spawn_boom"):
			main.spawn_boom(global_position, aoe)
		queue_free()


func _draw() -> void:
	if evo:

		draw_circle(Vector2.ZERO, 26.0, Color(1.0, 0.8, 0.3, 0.22))
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 32, Color(1.0, 0.85, 0.4, 0.5), 2.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.45, 1.45))
	match mode:
		"dagger":
			_draw_dagger()
		"sdagger":
			_draw_sdagger()
		"bulwark":
			_draw_bulwark()
		"lance":
			_draw_lance()
		"miasma":
			_draw_miasma()
		"comet":
			_draw_comet()
		"fireball":
			_draw_fireball()
		"frost":
			_draw_frost()
		"blade":
			_draw_blade()
		"scythe":
			_draw_scythe()
		"raven":
			_draw_raven()
		"zap":
			_draw_zap()
		"boom":
			_draw_boom()


func _draw_dagger() -> void:
	var ang := vel.angle() if vel.length() > 1.0 else 0.0
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	draw_colored_polygon([
		Vector2(14, 0), Vector2(2, 4), Vector2(-10, 4),
		Vector2(-10, -4), Vector2(2, -4),
	], Color(0.75, 0.78, 0.85))
	draw_line(Vector2(-10, 0), Vector2(-14, 0), Color(0.4, 0.2, 0.1), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sdagger() -> void:

	var ang := vel.angle() if vel.length() > 1.0 else 0.0
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	draw_colored_polygon([
		Vector2(13, 0), Vector2(2, 3), Vector2(-9, 3),
		Vector2(-9, -3), Vector2(2, -3),
	], Color(0.2, 0.28, 0.55))
	draw_colored_polygon([
		Vector2(13, 0), Vector2(4, 1.2), Vector2(4, -1.2),
	], Color(0.65, 0.8, 1.0))
	draw_line(Vector2(-9, 0), Vector2(-12, 0), Color(0.1, 0.12, 0.3), 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bulwark() -> void:

	var frac := clampf(1.0 - life / 0.32, 0.0, 1.0)
	var a := 1.0 - frac
	var base_ang := facing.angle()
	draw_set_transform(Vector2.ZERO, base_ang, Vector2.ONE)
	draw_arc(Vector2.ZERO, bulwark_radius * frac, -1.1, 1.1, 32, Color(0.75, 0.78, 0.85, a * 0.9), 14.0)
	draw_arc(Vector2.ZERO, bulwark_radius * frac * 0.75, -1.0, 1.0, 32, Color(0.9, 0.8, 0.5, a * 0.7), 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_lance() -> void:

	var ang := vel.angle() if vel.length() > 1.0 else 0.0
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	draw_colored_polygon([
		Vector2(26, 0), Vector2(10, 4), Vector2(-22, 4),
		Vector2(-22, -4), Vector2(10, -4),
	], Color(0.85, 0.8, 0.68))
	draw_colored_polygon([
		Vector2(26, 0), Vector2(10, 4), Vector2(10, -4),
	], Color(0.96, 0.92, 0.8))

	draw_colored_polygon([
		Vector2(26, 0), Vector2(17, 7), Vector2(21, 0), Vector2(17, -7),
	], Color(0.7, 0.2, 0.25))

	draw_colored_polygon([
		Vector2(-22, 0), Vector2(-31, 6), Vector2(-26, 0), Vector2(-31, -6),
	], Color(0.45, 0.12, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_miasma() -> void:

	var fade := clampf(_age / 0.4, 0.0, 1.0) * clampf(life / 1.0, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_age * 5.0)
	var r := cloud_radius
	draw_circle(Vector2.ZERO, r, Color(0.25, 0.7, 0.3, (0.12 + 0.06 * pulse) * fade))
	for i in 7:
		var a := TAU * float(i) / 7.0 + _age * 0.7
		var c := Vector2(cos(a), sin(a)) * r * 0.55
		var br := r * (0.3 + 0.12 * sin(_age * 3.0 + float(i) * 1.7))
		draw_circle(c, br, Color(0.3, 0.75, 0.35, 0.16 * fade))
		draw_circle(c, br * 0.55, Color(0.55, 0.9, 0.5, 0.14 * fade))

	draw_circle(Vector2.ZERO, 10.0, Color(0.7, 0.95, 0.6, (0.3 + 0.2 * pulse) * fade))


func _draw_comet() -> void:

	var frac := clampf(_age / maxf(life, 0.01), 0.0, 1.0)
	var blink := 0.5 + 0.5 * sin(_age * 25.0)
	draw_arc(Vector2.ZERO, aoe, 0, TAU, 48, Color(1.0, 0.3, 0.15, 0.35 + 0.35 * blink), 5.0)
	draw_circle(Vector2.ZERO, aoe * frac, Color(1.0, 0.4, 0.15, 0.1))
	draw_line(Vector2(-14, -14), Vector2(14, 14), Color(1.0, 0.35, 0.15, 0.6 + 0.3 * blink), 4.0)
	draw_line(Vector2(-14, 14), Vector2(14, -14), Color(1.0, 0.35, 0.15, 0.6 + 0.3 * blink), 4.0)
	var y := lerpf(-520.0, 0.0, frac)
	draw_line(Vector2(0, y), Vector2(0, y + 70.0), Color(1.0, 0.6, 0.2, 0.8), 8.0)
	draw_circle(Vector2(0, y + 70.0), 13.0, Color(1.0, 0.75, 0.3))


func _draw_fireball() -> void:
	var flick := 1.0 + sin(_age * 30.0) * 0.15
	draw_circle(Vector2.ZERO, 16.0 * flick, Color(1.0, 0.45, 0.1, 0.35))
	draw_circle(Vector2.ZERO, 10.0 * flick, Color(1.0, 0.6, 0.15))
	draw_circle(Vector2.ZERO, 5.5 * flick, Color(1.0, 0.9, 0.5))


func _draw_frost() -> void:
	var a := clampf(1.0 - ring_t / 0.7, 0.0, 1.0)
	draw_arc(Vector2.ZERO, maxf(ring_radius, 1.0), 0, TAU, 64, Color(ring_color, a * 0.9), 12.0)
	draw_arc(Vector2.ZERO, maxf(ring_radius * 0.85, 1.0), 0, TAU, 64, Color(0.85, 0.95, 1.0, a * 0.7), 4.0)


func _draw_blade() -> void:
	var spin := _age * 12.0 + float(orbit_index)
	draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
	var s := 13.0
	draw_colored_polygon([
		Vector2(s, 0), Vector2(0, s * 0.45),
		Vector2(-s, 0), Vector2(0, -s * 0.45),
	], Color(0.7, 0.8, 0.95))
	draw_colored_polygon([
		Vector2(s * 0.5, 0), Vector2(0, s * 0.22),
		Vector2(-s * 0.5, 0), Vector2(0, -s * 0.22),
	], Color(0.95, 0.98, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_scythe() -> void:

	var spin := _age * 3.0
	draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
	draw_arc(Vector2.ZERO, 30.0, -1.2, 1.2, 24, Color(0.6, 0.4, 1.0, 0.35), 10.0)

	var pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(-1.1, 1.1, float(i) / 12.0)
		var r := 34.0 - absf(a) * 10.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color(0.65, 0.5, 1.0, 0.85))

	var edge := PackedVector2Array()
	for i in 13:
		var a := lerpf(-1.1, 1.1, float(i) / 12.0)
		var r := 38.0 - absf(a) * 10.0
		edge.append(Vector2(cos(a), sin(a)) * r)
	for i in range(edge.size() - 1):
		draw_line(edge[i], edge[i + 1], Color(0.95, 0.9, 1.0, 0.9), 3.0)

	draw_line(Vector2(-34, 0), Vector2(34, 0), Color(0.25, 0.15, 0.35), 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_raven() -> void:

	var flap := sin(_age * 18.0)
	var ang := vel.angle() if vel.length() > 5.0 else 0.0
	draw_circle(Vector2.ZERO, 13.0, Color(0.5, 0.2, 0.9, 0.25))
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)

	draw_colored_polygon([
		Vector2(12, 0), Vector2(-6, 5), Vector2(-10, 0), Vector2(-6, -5),
	], Color(0.08, 0.06, 0.12))

	draw_circle(Vector2(9, -2), 5.0, Color(0.08, 0.06, 0.12))
	draw_colored_polygon([
		Vector2(13, -3), Vector2(19, -1), Vector2(13, 1),
	], Color(0.5, 0.35, 0.7))

	draw_circle(Vector2(10, -3), 1.6, Color(0.8, 0.4, 1.0))

	var w := 6.0 + flap * 7.0
	draw_colored_polygon([
		Vector2(2, 0), Vector2(-8, -w - 6), Vector2(-14, -w + 2), Vector2(-4, 2),
	], Color(0.12, 0.09, 0.18))
	draw_colored_polygon([
		Vector2(2, 0), Vector2(-8, w + 6), Vector2(-14, w - 2), Vector2(-4, -2),
	], Color(0.12, 0.09, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_zap() -> void:
	if zap_points.size() < 2:
		return
	var a := clampf(1.0 - _age / life, 0.0, 1.0)
	var local := PackedVector2Array()
	for p in zap_points:
		local.append(to_local(p))
	for i in range(local.size() - 1):
		draw_line(local[i], local[i + 1], Color(0.4, 0.8, 1.0, a * 0.45), 11.0)
		draw_line(local[i], local[i + 1], Color(0.95, 0.98, 1.0, a), 4.0)


func _draw_boom() -> void:
	var frac := clampf(_age / life, 0.0, 1.0)
	var r := ring_max * (0.3 + 0.7 * frac)
	var a := 1.0 - frac
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.2, a * 0.45))
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1.0, 0.8, 0.4, a), 6.0)
