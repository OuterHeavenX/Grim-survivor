extends CharacterBody2D



signal died

const TYPES := {
	"skeleton": {"hp": 22.0, "dmg": 9.0, "speed": 125.0, "xp": 1, "radius": 16.0},
	"husk": {"hp": 70.0, "dmg": 14.0, "speed": 62.0, "xp": 3, "radius": 24.0},
	"wisp": {"hp": 14.0, "dmg": 7.0, "speed": 150.0, "xp": 2, "radius": 13.0},
	"bogling": {"hp": 16.0, "dmg": 8.0, "speed": 175.0, "xp": 2, "radius": 13.0},
	"mire": {"hp": 130.0, "dmg": 17.0, "speed": 50.0, "xp": 5, "radius": 28.0},
	"imp": {"hp": 12.0, "dmg": 10.0, "speed": 205.0, "xp": 2, "radius": 12.0},
	"titan": {"hp": 220.0, "dmg": 24.0, "speed": 44.0, "xp": 8, "radius": 34.0},
	"herald": {"hp": 1600.0, "dmg": 26.0, "speed": 88.0, "xp": 60, "radius": 44.0},
	"maw": {"hp": 2800.0, "dmg": 32.0, "speed": 78.0, "xp": 120, "radius": 50.0},
	"cinderking": {"hp": 4500.0, "dmg": 40.0, "speed": 90.0, "xp": 250, "radius": 56.0},
}

var etype := "skeleton"
var is_elite := false
var max_hp := 20.0
var hp := 20.0
var dmg := 9.0
var speed := 120.0
var xp_value := 1
var body_radius := 16.0
var slow_mult := 1.0
var slow_t := 0.0
var dead := false

var main = null
var player = null
var am = null
var jm = null

var _flash := 0.0
var _tick := 0.0
var _kb := Vector2.ZERO
var _anim := 0.0
var _dash_t := 1.0
var _dash_phase := 0
var _wisp_dir := Vector2.ZERO
var _summon_t := 9.0

# Walk-cycle sheets built by tools/build_sprites.gd from assets/packs/. Frame
# counts must match what that tool reports; an entry missing here (or a sheet
# that fails to load) just falls back to the procedural _draw_* body below.
const WALK_SHEETS := {
	"skeleton": 9, "husk": 9, "wisp": 9, "bogling": 9, "mire": 9,
	"imp": 9, "titan": 9, "herald": 8, "maw": 8, "cinderking": 8,
}
const WALK_FPS := 10.0

var _spr: Sprite2D = null
var _spr_facing := 0.0



func is_boss() -> bool:
	return etype == "herald" or etype == "maw" or etype == "cinderking"



func _dashes() -> bool:
	return etype == "wisp" or etype == "bogling" or etype == "imp"


func setup(p_type: String, pos: Vector2, hp_m: float, dmg_m: float) -> void:
	etype = p_type
	var d: Dictionary = TYPES[p_type]
	max_hp = float(d["hp"]) * hp_m
	hp = max_hp
	dmg = float(d["dmg"]) * dmg_m
	speed = float(d["speed"])
	xp_value = int(d["xp"])
	body_radius = float(d["radius"])
	_make_sprite()
	position = pos
	_dash_t = randf_range(0.5, 1.5)
	_tick = randf_range(0.0, 0.4)



func _make_sprite() -> void:
	if not WALK_SHEETS.has(etype):
		return
	var tex: Texture2D = load("res://assets/sprites/%s_walk.png" % etype)
	if tex == null:
		return
	_spr = Sprite2D.new()
	_spr.texture = tex
	_spr.hframes = int(WALK_SHEETS[etype])
	# Draw under the node's own _draw(), so the shadow, elite aura and hit
	# flash still land on top of the body.
	_spr.show_behind_parent = true
	add_child(_spr)


func make_elite() -> void:
	is_elite = true
	max_hp *= 8.0
	hp = max_hp
	dmg *= 1.5
	speed *= 1.15
	body_radius *= 1.35
	scale = Vector2(1.35, 1.35)
	var lm = get_node_or_null("/root/LightingMan")
	if lm:
		lm.attach_aura(self, Color(1.0, 0.32, 0.16), 2.4, 0.9)


func _ready() -> void:
	add_to_group("enemies")
	main = get_tree().get_first_node_in_group("main")
	am = get_node("/root/AudioMan")
	jm = get_node("/root/JuiceMan")


func _physics_process(delta: float) -> void:
	if dead:
		return
	_anim += delta
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			queue_redraw()
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_mult = 1.0
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var to_p: Vector2 = player.global_position - global_position
	var dist := to_p.length()
	var dir := to_p / dist if dist > 1.0 else Vector2.ZERO
	var spd := speed * slow_mult
	if _dashes():
		_dash_t -= delta
		if _dash_phase == 0:
			spd *= 0.45
			if _dash_t <= 0.0:
				_dash_phase = 1
				_dash_t = 0.45
				_wisp_dir = dir
		else:
			spd *= 3.1
			dir = _wisp_dir
			if _dash_t <= 0.0:
				_dash_phase = 0
				_dash_t = randf_range(0.8, 1.4)
	velocity = dir * spd + _kb
	_kb = _kb.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	if _spr != null:
		_spr.frame = int(_anim * WALK_FPS) % _spr.hframes
		# The art is drawn facing north, so a heading of -Y needs no rotation.
		if velocity.length_squared() > 1.0:
			_spr_facing = velocity.angle() + PI * 0.5
		_spr.rotation = _spr_facing - rotation
		var f := clampf(_flash / 0.12, 0.0, 1.0)
		_spr.modulate = Color(1.0, 1.0, 1.0).lerp(Color(2.4, 2.0, 2.0), f)
	_tick -= delta
	if _tick <= 0.0 and dist < body_radius + 22.0 and bool(player.get("alive")):
		player.take_damage(dmg)
		if is_boss():
			jm.hit_stop(0.06)
			jm.add_trauma(0.35)
		_tick = 0.7
	if is_boss():
		_summon_t -= delta
		if _summon_t <= 0.0:
			_summon_t = 9.0
			if main and main.has_method("summon_minions"):
				main.summon_minions(global_position)
	queue_redraw()


func take_damage(amount: float, from_pos: Vector2, knockback: float) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.12
	var away: Vector2 = global_position - from_pos
	var dir := away.normalized() if away.length() > 1.0 else Vector2.ZERO
	var kbm := 1.0
	if is_boss():
		kbm = 0.12
	if is_elite:
		kbm = 0.0
	_kb += dir * knockback * kbm
	if main and main.has_method("spawn_damage_number"):
		main.spawn_damage_number(global_position, amount, Color(1.0, 0.85, 0.4))
	if hp <= 0.0:
		dead = true
		died.emit()
		am.play_ranged("enemy_die", -8.0, 0.9, 1.15)
		jm.death_fx(global_position, is_boss())
		if main and main.has_method("spawn_gem"):
			main.spawn_gem(global_position, xp_value)
		if main and main.has_method("spawn_shard"):
			_roll_shard_drop()
		queue_free()
	else:
		am.play_ranged("hit_flesh", -16.0, 0.85, 1.2)
		queue_redraw()


func apply_slow(mult: float, dur: float) -> void:
	if slow_t > 0.0:
		slow_mult = minf(slow_mult, mult)
	else:
		slow_mult = mult
	slow_t = maxf(slow_t, dur)



func _roll_shard_drop() -> void:
	if is_boss():
		return
	var gm = get_node("/root/GameManager")
	var late := float(gm.get("run_time")) >= 180.0
	var chance := 0.25 if late else 0.15
	if randf() < chance:
		var n := randi_range(1, 2) if late else 1
		for i in n:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(6.0, 26.0)
			main.spawn_shard(global_position + off, 1)


func _draw() -> void:
	if _spr != null:
		# Body comes from the sprite child; just ground it with a shadow that
		# sits below the feet rather than across them.
		var h := _spr.texture.get_height() * 0.5
		draw_set_transform(Vector2(0, h * 0.86), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, body_radius * 0.85, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if is_elite:
			_draw_elite_aura()
		if _flash > 0.0:
			draw_circle(Vector2.ZERO, body_radius + 2.0, Color(1, 1, 1, 0.35))
		return

	match etype:
		"skeleton":
			_draw_skeleton()
		"husk":
			_draw_husk()
		"wisp":
			_draw_wisp()
		"bogling":
			_draw_bogling()
		"mire":
			_draw_mire()
		"imp":
			_draw_imp()
		"titan":
			_draw_titan()
		"herald":
			_draw_herald()
		"maw":
			_draw_maw()
		"cinderking":
			_draw_cinderking()
	if is_elite:
		_draw_elite_aura()
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, body_radius + 2.0, Color(1, 1, 1, 0.55))


func _draw_elite_aura() -> void:
	var pulse := 0.5 + 0.5 * sin(_anim * 6.0)

	draw_arc(Vector2.ZERO, body_radius + 9.0, 0, TAU, 40,
		Color(1.0, 0.38 + 0.22 * pulse, 0.12, 0.85), 5.0)
	draw_arc(Vector2.ZERO, body_radius + 16.0, 0, TAU, 40,
		Color(1.0, 0.6, 0.15, 0.25 + 0.25 * pulse), 3.0)

	draw_string(ThemeDB.fallback_font, Vector2(-50, -body_radius - 14.0), "ELITE",
		HORIZONTAL_ALIGNMENT_CENTER, 100, 22, Color(1.0, 0.72, 0.2))


func _shadow(r: float) -> void:
	draw_set_transform(Vector2(0, body_radius * 0.95), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_skeleton() -> void:
	_shadow(15.0)
	var sway := sin(_anim * 7.0) * 2.0

	draw_colored_polygon([
		Vector2(-9, -6 + sway), Vector2(9, -6 - sway),
		Vector2(11, 16), Vector2(-11, 16),
	], Color(0.42, 0.44, 0.5))

	draw_circle(Vector2(sway * 0.5, -16), 11.0, Color(0.78, 0.78, 0.72))

	draw_circle(Vector2(-4 + sway * 0.5, -17), 2.4, Color(0.9, 0.1, 0.1))
	draw_circle(Vector2(4 + sway * 0.5, -17), 2.4, Color(0.9, 0.1, 0.1))

	var bx := 14.0 + sway
	draw_line(Vector2(bx, -2), Vector2(bx + 4, 18), Color(0.5, 0.5, 0.55), 3.0)


func _draw_husk() -> void:
	_shadow(23.0)
	var squash := 1.0 + sin(_anim * 4.0) * 0.05
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, 23.0, Color(0.25, 0.3, 0.2))
	draw_circle(Vector2(-8, -6), 14.0, Color(0.3, 0.36, 0.24))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_line(Vector2(-10, -14), Vector2(2, 2), Color(0.12, 0.14, 0.1), 2.0)
	draw_line(Vector2(8, -10), Vector2(-2, 10), Color(0.12, 0.14, 0.1), 2.0)

	draw_circle(Vector2(-7, -4), 3.0, Color(0.75, 0.7, 0.3))
	draw_circle(Vector2(7, -4), 3.0, Color(0.75, 0.7, 0.3))


func _draw_wisp() -> void:
	var flick := 1.0 + sin(_anim * 14.0) * 0.12

	draw_circle(Vector2.ZERO, 20.0 * flick, Color(0.3, 0.7, 1.0, 0.18))

	var h := 16.0 * flick
	draw_colored_polygon([
		Vector2(0, -h - 6), Vector2(9, 2),
		Vector2(0, 12), Vector2(-9, 2),
	], Color(0.35, 0.75, 1.0, 0.9))
	draw_circle(Vector2(0, 2), 6.0, Color(0.85, 0.95, 1.0))
	if _dash_phase == 1:
		draw_arc(Vector2.ZERO, 24.0, 0, TAU, 24, Color(0.5, 0.85, 1.0, 0.5), 2.0)


func _draw_herald() -> void:
	_shadow(42.0)
	var pulse := 1.0 + sin(_anim * 3.0) * 0.04

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, pulse))
	draw_colored_polygon([
		Vector2(-34, -30), Vector2(34, -30),
		Vector2(46, 42), Vector2(-46, 42),
	], Color(0.05, 0.06, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var crown := PackedVector2Array()
	for i in 7:
		var x := -30.0 + i * 10.0
		crown.append(Vector2(x, -34))
		crown.append(Vector2(x + 5, -52 if i % 2 == 0 else -42))
	crown.append(Vector2(40, -34))
	draw_colored_polygon(crown, Color(0.45, 0.75, 0.95))

	draw_circle(Vector2(0, -22), 16.0, Color(0.01, 0.02, 0.04))

	var eg := Color(0.4, 0.95, 1.0)
	draw_circle(Vector2(-7, -24), 3.4, eg)
	draw_circle(Vector2(7, -24), 3.4, eg)
	draw_circle(Vector2(-7, -24), 6.5, Color(0.4, 0.95, 1.0, 0.25))
	draw_circle(Vector2(7, -24), 6.5, Color(0.4, 0.95, 1.0, 0.25))

	draw_circle(Vector2(0, 8), 10.0 * pulse, Color(0.1, 0.3, 0.5))
	draw_arc(Vector2(0, 8), 14.0, 0, TAU, 32, Color(0.3, 0.7, 1.0, 0.5), 3.0)

	var w := 90.0
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	var bp := Vector2(-w / 2.0, -72)
	draw_rect(Rect2(bp, Vector2(w, 9)), Color(0.02, 0.02, 0.05, 0.9))
	draw_rect(Rect2(bp, Vector2(w * frac, 9)), Color(0.7, 0.15, 0.35))



func _draw_bogling() -> void:
	var flick := 1.0 + sin(_anim * 16.0) * 0.14
	draw_circle(Vector2.ZERO, 20.0 * flick, Color(0.35, 0.9, 0.4, 0.18))
	var h := 16.0 * flick
	draw_colored_polygon([
		Vector2(0, -h - 6), Vector2(9, 2),
		Vector2(0, 12), Vector2(-9, 2),
	], Color(0.3, 0.8, 0.3, 0.9))
	draw_circle(Vector2(0, 2), 6.0, Color(0.8, 1.0, 0.7))

	draw_circle(Vector2(-4, 14 + flick * 3.0), 2.0, Color(0.3, 0.8, 0.3, 0.7))
	if _dash_phase == 1:
		draw_arc(Vector2.ZERO, 24.0, 0, TAU, 24, Color(0.4, 1.0, 0.5, 0.5), 2.0)



func _draw_mire() -> void:
	_shadow(27.0)
	var squash := 1.0 + sin(_anim * 3.0) * 0.06
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, 27.0, Color(0.2, 0.32, 0.16))
	draw_circle(Vector2(-9, -8), 16.0, Color(0.26, 0.4, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_circle(Vector2(12, -14), 6.0, Color(0.32, 0.5, 0.22))
	draw_circle(Vector2(-14, 10), 5.0, Color(0.3, 0.46, 0.2))

	draw_circle(Vector2(-8, -4), 3.5, Color(0.85, 0.9, 0.3))
	draw_circle(Vector2(8, -4), 3.5, Color(0.85, 0.9, 0.3))



func _draw_imp() -> void:
	_shadow(11.0)
	var sway := sin(_anim * 11.0) * 2.5
	draw_colored_polygon([
		Vector2(-7, -4 + sway), Vector2(7, -4 - sway),
		Vector2(9, 12), Vector2(-9, 12),
	], Color(0.45, 0.22, 0.12))

	draw_circle(Vector2(sway * 0.5, -12), 8.5, Color(0.9, 0.55, 0.25))
	draw_circle(Vector2(-3 + sway * 0.5, -13), 2.2, Color(1.0, 0.85, 0.3))
	draw_circle(Vector2(3 + sway * 0.5, -13), 2.2, Color(1.0, 0.85, 0.3))

	draw_circle(Vector2(sway, -20), 1.8, Color(1.0, 0.6, 0.2, 0.8))



func _draw_titan() -> void:
	_shadow(33.0)
	var squash := 1.0 + sin(_anim * 3.0) * 0.04
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, 33.0, Color(0.22, 0.14, 0.13))
	draw_circle(Vector2(-11, -9), 20.0, Color(0.28, 0.17, 0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var glow := 0.6 + 0.4 * sin(_anim * 5.0)
	draw_line(Vector2(-14, -20), Vector2(4, 4), Color(1.0, 0.45, 0.12, glow), 2.5)
	draw_line(Vector2(10, -14), Vector2(-4, 14), Color(1.0, 0.45, 0.12, glow), 2.5)

	draw_circle(Vector2(-9, -6), 4.0, Color(1.0, 0.55, 0.15))
	draw_circle(Vector2(9, -6), 4.0, Color(1.0, 0.55, 0.15))



func _draw_maw() -> void:
	_shadow(48.0)
	var pulse := 1.0 + sin(_anim * 2.5) * 0.05
	draw_circle(Vector2.ZERO, 50.0 * pulse, Color(0.25, 0.9, 0.4, 0.12))

	draw_circle(Vector2.ZERO, 48.0, Color(0.16, 0.3, 0.14))
	draw_circle(Vector2.ZERO, 48.0, Color(0.3, 0.55, 0.25, 0.0))

	for i in 14:
		var a := TAU * float(i) / 14.0 + _anim * 0.15
		var tip := Vector2.from_angle(a) * 34.0
		var b1 := Vector2.from_angle(a - 0.1) * 46.0
		var b2 := Vector2.from_angle(a + 0.1) * 46.0
		draw_colored_polygon([tip, b1, b2], Color(0.85, 0.88, 0.7))

	var gape := 1.0 + sin(_anim * 2.5) * 0.08
	draw_circle(Vector2.ZERO, 28.0 * gape, Color(0.02, 0.05, 0.03))

	draw_circle(Vector2.ZERO, 14.0 * gape, Color(0.4, 1.0, 0.45, 0.5))
	draw_circle(Vector2.ZERO, 6.0, Color(0.7, 1.0, 0.7))



func _draw_cinderking() -> void:
	_shadow(54.0)
	var pulse := 1.0 + sin(_anim * 3.0) * 0.04
	var flare := 0.6 + 0.4 * sin(_anim * 6.0)

	draw_circle(Vector2.ZERO, 70.0 * pulse, Color(1.0, 0.4, 0.1, 0.14))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, pulse))
	draw_colored_polygon([
		Vector2(-40, -34), Vector2(40, -34),
		Vector2(54, 52), Vector2(-54, 52),
	], Color(0.12, 0.06, 0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_circle(Vector2(0, 8), 12.0, Color(1.0, 0.5, 0.12, flare))
	draw_circle(Vector2(0, 8), 6.0, Color(1.0, 0.8, 0.3))

	for i in 5:
		var x := -24.0 + float(i) * 12.0
		draw_colored_polygon([
			Vector2(x - 5, -40), Vector2(x + 5, -40), Vector2(x, -58 - flare * 6.0),
		], Color(0.9, 0.5, 0.15))

	draw_circle(Vector2(-12, -22), 4.5, Color(1.0, 0.6, 0.15))
	draw_circle(Vector2(12, -22), 4.5, Color(1.0, 0.6, 0.15))
