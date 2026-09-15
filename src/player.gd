extends CharacterBody2D


signal died
signal hp_changed(hp: float, max_hp: float)

const WeaponsScript := preload("res://src/weapons.gd")

const BASE_SPEED := 270.0
const BASE_MAGNET := 95.0
const BASE_MAX_HP := 100.0
const ARENA := 1500.0

var max_hp := BASE_MAX_HP
var hp := BASE_MAX_HP
var alive := true
var move_vec := Vector2.ZERO
var touch_mode := false
var joy_ui = null
var weapons_node = null

var class_id := "rogue"
var _pal := {}


func class_palette() -> Dictionary:
	var gm = get_node("/root/GameManager")
	var c: Dictionary = gm.class_by_id(class_id)
	return c["palette"]

var _touch_id := -1
var _touch_origin := Vector2.ZERO
var _touch_cur := Vector2.ZERO
var _touch_last_msec := 0


const STALE_TOUCH_MSEC := 2500
# Class walk sheets built by tools/build_sprites.gd. A class missing here, or
# whose sheet fails to load, keeps the procedural hooded figure below.
const WALK_SHEETS := {
	"rogue": 6, "shadow": 6, "pyro": 6, "warden": 6, "flame": 6, "rime": 6,
	"dancer": 6, "storm": 6, "reaper": 6, "ravenmark": 6, "bonewright": 6,
	"plague": 6, "starcaller": 6,
}
# How far the class palette pulls the sprite's colour. tools/build_sprites.gd
# desaturates the player sheets, so this tint is what gives each survivor its
# colour -- the pack has ten body/weapon combinations for thirteen classes and
# dresses them all the same.
const TINT_STRENGTH := 0.9
const WALK_FPS := 11.0

var _spr: Sprite2D = null
var _tint := Color(1, 1, 1)
var _spr_facing := 0.0
var _anim_t := 0.0

var _hurt_flash := 0.0
var _invuln := 0.0


func _ready() -> void:
	add_to_group("player")
	touch_mode = DisplayServer.is_touchscreen_available()
	var gm = get_node("/root/GameManager")
	class_id = str(gm.selected_class)
	_pal = class_palette()
	_make_sprite()
	max_hp = gm.class_hp() + gm.meta_hp_bonus()
	hp = max_hp
	weapons_node = WeaponsScript.new()
	weapons_node.name = "Weapons"
	add_child(weapons_node)

	var lm = get_node_or_null("/root/LightingMan")
	if lm:
		lm.attach_aura(self, Color(1.0, 0.7, 0.4), 4.2, 1.15, true)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.add_to_group("shake_camera")
	add_child(cam)
	cam.make_current()
	hp_changed.emit(hp, max_hp)


func _class_tint() -> Color:
	var c: Color = _pal.get("tunic", Color(1, 1, 1))
	var m := maxf(c.r, maxf(c.g, c.b))
	if m < 0.01:
		return Color(1, 1, 1)
	# Normalise first so a dark palette colours the sprite instead of just
	# dimming it, then pull back toward white so the art stays readable.
	var norm := Color(c.r / m, c.g / m, c.b / m)
	return Color(1, 1, 1).lerp(norm, TINT_STRENGTH)


func _make_sprite() -> void:
	if not WALK_SHEETS.has(class_id):
		return
	var tex: Texture2D = load("res://assets/sprites/player_%s_walk.png" % class_id)
	if tex == null:
		return
	_spr = Sprite2D.new()
	_spr.texture = tex
	_spr.hframes = int(WALK_SHEETS[class_id])
	# Behind the node's own _draw(), so the shadow and health bar stay on top.
	_spr.show_behind_parent = true
	_tint = _class_tint()
	_spr.modulate = _tint
	add_child(_spr)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		touch_mode = true
		if t.pressed:
			var now := Time.get_ticks_msec()
			if _touch_id == -1 or t.index == _touch_id or now - _touch_last_msec > STALE_TOUCH_MSEC:



				_touch_id = t.index
				_touch_origin = t.position
				_touch_cur = t.position
				_touch_last_msec = now
		elif t.index == _touch_id:
			_touch_id = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_id:
			_touch_cur = d.position
			_touch_last_msec = Time.get_ticks_msec()


func _notification(what: int) -> void:

	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_joystick()






func release_joystick() -> void:
	_touch_id = -1
	_touch_cur = _touch_origin
	move_vec = Vector2.ZERO
	velocity = Vector2.ZERO
	if joy_ui:
		joy_ui.set_joy(false, _touch_origin, _touch_origin)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _invuln > 0.0:
		_invuln -= delta
		modulate.a = 0.45 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 18.0)
		if _invuln <= 0.0:
			modulate.a = 1.0
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		if _hurt_flash <= 0.0 and _invuln <= 0.0:
			modulate = Color.WHITE
	var kv := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kv.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		kv.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		kv.y += 1.0
	var jv := Vector2.ZERO
	if _touch_id != -1:
		var drag := _touch_cur - _touch_origin
		if drag.length() > 14.0:
			jv = drag.limit_length(90.0) / 90.0
	move_vec = kv + jv
	if move_vec.length() > 1.0:
		move_vec = move_vec.normalized()
	var gm = get_node("/root/GameManager")
	velocity = move_vec * BASE_SPEED * gm.speed_mult()
	move_and_slide()
	position.x = clampf(position.x, -ARENA, ARENA)
	position.y = clampf(position.y, -ARENA, ARENA)
	if joy_ui:
		joy_ui.set_joy(_touch_id != -1, _touch_origin, _touch_cur)
	if _spr != null:
		# Only step the walk cycle while actually moving, so standing still
		# does not moonwalk on the spot.
		if velocity.length_squared() > 1.0:
			_anim_t += delta
			_spr_facing = velocity.angle() - PI * 0.5
		_spr.frame = int(_anim_t * WALK_FPS) % _spr.hframes
		_spr.rotation = _spr_facing - rotation
		var f := clampf(_hurt_flash / 0.12, 0.0, 1.0)
		_spr.modulate = _tint.lerp(Color(2.4, 1.6, 1.6), f)
	queue_redraw()


func magnet_radius() -> float:
	var gm = get_node("/root/GameManager")
	return BASE_MAGNET * gm.magnet_mult()


func take_damage(amount: float) -> void:
	if not alive or _invuln > 0.0:
		return
	var gm = get_node("/root/GameManager")
	hp -= maxf(1.0, amount - gm.armor_block())
	_hurt_flash = 0.12
	modulate = Color(1.7, 0.45, 0.45)
	hp_changed.emit(hp, max_hp)
	get_node("/root/AudioMan").play_ranged("player_hurt", -6.0, 0.9, 1.1)
	get_node("/root/JuiceMan").add_trauma(0.25)
	if hp <= 0.0 and gm.consume_revive():
		_revive()
		return
	if hp <= 0.0:
		hp = 0.0
		alive = false
		hp_changed.emit(hp, max_hp)
		died.emit()



func _revive() -> void:
	var gm = get_node("/root/GameManager")
	hp = max_hp * 0.5
	_invuln = 2.5
	_hurt_flash = 0.0
	hp_changed.emit(hp, max_hp)
	get_node("/root/AudioMan").play("explosion", -8.0, 1.2)
	get_node("/root/AudioMan").play("levelup_chime", -6.0)
	get_node("/root/JuiceMan").add_trauma(0.45)
	var main = get_tree().get_first_node_in_group("main")
	if main:
		main.spawn_boom(global_position, 280.0)
		if main.get("hud"):
			(main.get("hud") as CanvasLayer).show_warning("SECOND WIND!")
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = e.global_position - global_position
		if d.length() < 300.0:
			e.take_damage(80.0 * gm.meta_damage_mult(), global_position, 520.0)


func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func on_vitality() -> void:
	max_hp += 20.0
	heal(20.0)


func _draw() -> void:
	if _spr != null:
		var h := _spr.texture.get_height() * 0.5
		draw_set_transform(Vector2(0, h * 0.84), 0.0, Vector2(1.0, 0.40))
		draw_circle(Vector2.ZERO, 19.0, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_health_bar(Vector2.ZERO)
		return

	var bob := sin(Time.get_ticks_msec() / 1000.0 * 6.0) * 2.0

	draw_set_transform(Vector2(0, 30), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var o := Vector2(0, bob)
	var cloak: Color = _pal.get("cloak", Color(0.07, 0.08, 0.15))
	var tunic: Color = _pal.get("tunic", Color(0.32, 0.18, 0.48))
	var lining: Color = _pal.get("lining", Color(0.55, 0.08, 0.14))
	var eyes: Color = _pal.get("eyes", Color(1.0, 0.25, 0.25))

	draw_colored_polygon([
		o + Vector2(-20, -8), o + Vector2(20, -8),
		o + Vector2(27, 30), o + Vector2(-27, 30),
	], cloak)

	draw_colored_polygon([
		o + Vector2(-13, -2), o + Vector2(13, -2),
		o + Vector2(15, 24), o + Vector2(-15, 24),
	], tunic)

	draw_rect(Rect2(o + Vector2(-14, 8), Vector2(28, 5)), Color(0.12, 0.08, 0.05))

	draw_circle(o + Vector2(0, -15), 14.0, lining)
	draw_circle(o + Vector2(0, -18), 12.0, cloak.darkened(0.55))

	draw_circle(o + Vector2(0, -14), 7.0, Color(0.015, 0.015, 0.025))
	draw_circle(o + Vector2(-3.2, -15), 1.6, eyes)
	draw_circle(o + Vector2(3.2, -15), 1.6, eyes)

	_draw_health_bar(o)


func _draw_health_bar(o: Vector2) -> void:
	var w := 64.0
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	var bar_pos := o + Vector2(-w / 2.0, -48)
	draw_rect(Rect2(bar_pos, Vector2(w, 8)), Color(0.02, 0.02, 0.04, 0.85))
	var hcol := Color(0.25, 0.9, 0.35).lerp(Color(0.95, 0.2, 0.2), 1.0 - frac)
	draw_rect(Rect2(bar_pos, Vector2(w * frac, 8)), hcol)
	draw_rect(Rect2(bar_pos, Vector2(w, 8)), Color(0, 0, 0, 0.6), false, 1.0)
