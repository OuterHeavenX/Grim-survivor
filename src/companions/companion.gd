class_name Companion
extends Node2D
# A summoned ally that fights for a few seconds and fades. It cannot be hurt,
# never touches the player's weapons or stats, and is cleaned up with the stage
# like any stage object.
#
#   hound  - fast melee: chains bites from foe to foe.
#   archer - hangs back near the player and looses piercing arrows.
#   wisp   - orbits the player, burning everything close in pulses.
#   knight - slow tank: lures nearby foes onto itself and cleaves them.
#
# Damage scales with GameManager.companion_damage_mult(), so a companion keeps
# pace with the run. Sprites come from assets/sprites/companion_<kind>_*.png
# when present; otherwise (and always for the wisp) it is drawn.

const ArrowScript := preload("res://src/companions/companion_arrow.gd")
const WALK_FPS := 11.0

const STATS := {
	"hound": {"speed": 470.0, "dmg": 22.0, "rate": 0.36, "reach": 44.0, "kb": 240.0},
	"archer": {"speed": 330.0, "dmg": 15.0, "rate": 0.48, "reach": 620.0, "kb": 120.0},
	"wisp": {"speed": 0.0, "dmg": 10.0, "rate": 0.5, "reach": 140.0, "kb": 160.0},
	"knight": {"speed": 240.0, "dmg": 34.0, "rate": 0.85, "reach": 125.0, "kb": 320.0},
}
const LEASH := 640.0

var kind := "hound"
var life := 8.0
var max_life := 8.0
var color := Color(0.5, 1.0, 0.7)
var dmg_mult := 1.0
var orbit_phase := 0.0

var main = null
var gm = null
var jm = null
var player: Node2D = null
var target: Node2D = null
var _atk := 0.0
var _retarget := 0.0
var _t := 0.0
var _spr: Sprite2D = null
var _facing := 0.0
var _swing := 0.0
var _lured: Array = []


func setup(p_main, p_kind: String, duration: float, p_color: Color, p_mult: float) -> void:
	main = p_main
	kind = p_kind
	life = duration
	max_life = duration
	color = p_color
	dmg_mult = p_mult


func _ready() -> void:
	add_to_group("companions")
	add_to_group("stage_objects")
	gm = get_node("/root/GameManager")
	jm = get_node_or_null("/root/JuiceMan")
	player = get_tree().get_first_node_in_group("player")
	_make_sprite()
	var lm = get_node_or_null("/root/LightingMan")
	if lm:
		lm.attach_aura(self, color, 2.4, 0.9)
	modulate.a = 0.0
	if jm:
		jm.shockwave(global_position, color, 150.0)
	if kind == "knight":
		scale = Vector2(1.15, 1.15)


func _make_sprite() -> void:
	if kind == "wisp":
		return
	var path := "res://assets/sprites/companion_%s_walk.png" % kind
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	_spr = Sprite2D.new()
	_spr.texture = tex
	_spr.hframes = maxi(1, int(round(float(tex.get_width()) / float(tex.get_height()))))
	_spr.show_behind_parent = true
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/fx/outline.gdshader")
	mat.set_shader_parameter("outline_color", Color(color, 0.95))
	mat.set_shader_parameter("width", 2.0)
	_spr.material = mat
	add_child(_spr)


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	# Fade in fast, out over the last second.
	modulate.a = clampf(minf(_t * 4.0, life), 0.0, 1.0)
	if life <= 0.0:
		dismiss()
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	_atk -= delta
	_retarget -= delta
	_swing = maxf(0.0, _swing - delta * 4.0)
	if _retarget <= 0.0 or target == null or not _valid(target):
		_retarget = 0.25
		target = _nearest(player.global_position, LEASH if kind != "archer" else float(STATS["archer"]["reach"]))
	match kind:
		"hound":
			_step_melee(delta)
		"knight":
			_step_melee(delta)
			_taunt()
		"archer":
			_step_archer(delta)
		"wisp":
			_step_wisp(delta)
	if main and main.director and is_instance_valid(main.director) and main.director.has_obstacles():
		position = main.director.resolve(position, 14.0)
	position = main.clamp_arena(position, 10.0) if main else position
	_animate(delta)
	queue_redraw()


func _valid(e) -> bool:
	return e != null and is_instance_valid(e) and not e.is_queued_for_deletion() and not bool(e.get("dead")) and not bool(e.get("untargetable"))


func _nearest(around: Vector2, within: float) -> Node2D:
	var best: Node2D = null
	var bd := within * within
	for e in get_tree().get_nodes_in_group("enemies"):
		if not _valid(e):
			continue
		var d: float = around.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _move_toward(goal: Vector2, spd: float, delta: float) -> void:
	var to := goal - global_position
	if to.length() > 2.0:
		var step := to.normalized() * minf(spd * delta, to.length())
		position += step
		_facing = step.angle() - PI * 0.5


func _follow_player(delta: float, spd: float) -> void:
	var side := Vector2(70, 40) if kind != "knight" else Vector2(-80, 30)
	var goal: Vector2 = player.global_position + side
	if global_position.distance_to(goal) > 30.0:
		_move_toward(goal, spd, delta)


func _leashed() -> bool:
	return global_position.distance_to(player.global_position) > LEASH + 120.0


func _step_melee(delta: float) -> void:
	var st: Dictionary = STATS[kind]
	var spd: float = st["speed"]
	if _leashed():
		_move_toward(player.global_position, spd * 1.6, delta)
		return
	if target == null:
		_follow_player(delta, spd)
		return
	var reach: float = st["reach"]
	var d := global_position.distance_to(target.global_position)
	if d > reach * 0.8:
		_move_toward(target.global_position, spd, delta)
	if d <= reach and _atk <= 0.0:
		_atk = st["rate"]
		_swing = 1.0
		if kind == "hound":
			_hit(target, st)
			# Chain: the next bite goes to whoever is nearest now.
			_retarget = 0.0
		else:
			for e in get_tree().get_nodes_in_group("enemies"):
				if _valid(e) and global_position.distance_to(e.global_position) <= reach + float(e.get("body_radius")):
					_hit(e, st)
			if jm:
				jm.shockwave(global_position, color, reach * 1.4)


func _taunt() -> void:
	if int(_t * 10.0) % 5 != 0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if _valid(e) and not e.is_boss() and global_position.distance_to(e.global_position) < 300.0:
			if e.get("lure") != self:
				e.set("lure", self)
				_lured.append(e)


func _step_archer(delta: float) -> void:
	var st: Dictionary = STATS["archer"]
	# Keep a little behind the player, away from the nearest threat.
	var goal: Vector2 = player.global_position + Vector2(-90, 60)
	if target:
		goal = player.global_position + (player.global_position - target.global_position).normalized() * 120.0
	if global_position.distance_to(goal) > 24.0:
		_move_toward(goal, float(st["speed"]) * (1.6 if _leashed() else 1.0), delta)
	if target and _atk <= 0.0:
		_atk = st["rate"]
		_swing = 1.0
		_facing = (target.global_position - global_position).angle() - PI * 0.5
		var a = ArrowScript.new()
		a.setup(global_position, (target.global_position - global_position).normalized(),
			float(st["dmg"]) * dmg_mult, float(st["kb"]), color, "companion:archer")
		get_parent().add_child(a)
		var am = get_node_or_null("/root/AudioMan")
		if am:
			am.play_ranged("dagger_throw", -14.0, 0.7, 0.8)


func _step_wisp(_delta: float) -> void:
	var st: Dictionary = STATS["wisp"]
	var ang := orbit_phase + _t * 2.6
	position = player.global_position + Vector2.from_angle(ang) * 95.0
	if _atk <= 0.0:
		_atk = st["rate"]
		_swing = 1.0
		var reach: float = st["reach"]
		var hit_any := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if _valid(e) and global_position.distance_to(e.global_position) <= reach + float(e.get("body_radius")):
				_hit(e, st)
				hit_any = true
		if hit_any and jm:
			jm.shockwave(global_position, color, reach * 1.3)


func _hit(e, st: Dictionary) -> void:
	e.take_damage(float(st["dmg"]) * dmg_mult, global_position, float(st["kb"]), "companion:" + kind)


func _animate(delta: float) -> void:
	if _spr == null:
		return
	_spr.frame = int(_t * WALK_FPS) % _spr.hframes
	_spr.rotation = lerp_angle(_spr.rotation, _facing, minf(1.0, delta * 12.0))


func dismiss() -> void:
	if is_queued_for_deletion():
		return
	for e in _lured:
		if is_instance_valid(e) and e.get("lure") == self:
			e.set("lure", null)
	_lured.clear()
	if jm:
		jm.shockwave(global_position, color, 90.0)
	queue_free()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	# Spectral ground ring: what marks every companion as yours.
	draw_set_transform(Vector2(0, 18), 0.0, Vector2(1.0, 0.4))
	draw_arc(Vector2.ZERO, 26.0, 0, TAU, 28, Color(color, 0.55 + 0.3 * pulse), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Remaining time as a thin arc.
	draw_arc(Vector2.ZERO, 34.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(life / maxf(max_life, 0.01), 0.0, 1.0), 32, Color(color, 0.45), 2.0)
	if _spr != null:
		return
	match kind:
		"wisp":
			var f := 1.0 + 0.15 * sin(_t * 17.0)
			draw_circle(Vector2.ZERO, 26.0 * f, Color(color, 0.16))
			draw_circle(Vector2.ZERO, 15.0 * f, Color(color, 0.45))
			draw_colored_polygon(PackedVector2Array([Vector2(-9, 4), Vector2(0, -22 * f), Vector2(9, 4), Vector2(0, 10)]), Color(1.0, 0.8, 0.45))
			draw_circle(Vector2(0, 2), 6.0, Color(1.0, 0.97, 0.85))
			if _swing > 0.0:
				draw_arc(Vector2.ZERO, STATS["wisp"]["reach"] * (1.0 - _swing * 0.5), 0, TAU, 40, Color(color, _swing * 0.6), 4.0)
		"hound":
			_draw_ghost_body(Vector2(16, 26), 0.8)
		"archer":
			_draw_ghost_body(Vector2(12, 22), 1.0)
			draw_arc(Vector2(12, -2), 16.0, -1.2, 1.2, 12, Color(color, 0.9), 2.5)
		"knight":
			_draw_ghost_body(Vector2(18, 30), 1.0)
			draw_line(Vector2(16, -16), Vector2(30, 22 - 30.0 * _swing), Color(color.lightened(0.4), 0.95), 4.0)


func _draw_ghost_body(sz: Vector2, head: float) -> void:
	# Fallback silhouette until the companion has a sprite sheet.
	var bob := sin(_t * 9.0) * 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(-sz.x, -4 + bob), Vector2(sz.x, -4 + bob), Vector2(sz.x * 0.7, sz.y), Vector2(-sz.x * 0.7, sz.y)]), Color(0.06, 0.08, 0.1, 0.92))
	draw_circle(Vector2(0, -12 + bob), 10.0 * head, Color(0.05, 0.06, 0.08))
	draw_circle(Vector2(-4, -13 + bob), 2.2, color)
	draw_circle(Vector2(4, -13 + bob), 2.2, color)
	draw_arc(Vector2(0, 6 + bob), sz.x, PI, TAU, 16, Color(color, 0.6), 2.0)
