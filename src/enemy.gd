extends CharacterBody2D



signal died

# Kept as the legacy stat view for code and tests that read enemy.gd's table;
# the authored source is data/enemies/*.tres (EnemyData).
static var TYPES: Dictionary = _load_types()


static func _load_types() -> Dictionary:
	var c: GameContentData = load("res://data/game_content.tres")
	return c.enemy_dictionary() if c else {}


var etype := "skeleton"
var data: EnemyData = null
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

# Composition hooks. behavior is the role component from EnemyData;
# controller is set on data-driven bosses (src/boss/boss_controller.gd).
var behavior: EnemyBehavior = null
var controller = null
# Burrowed, submerged or otherwise out of reach: weapons skip it and it
# cannot be hurt or touch the player.
var untargetable := false
# Raised dead and summoned props: no XP, shards or kill credit.
var no_credit := false
var revived := false
# Boss-owned props (armour plates, anchors) cleaned up with their boss.
var is_boss_object := false
var summoner = null
# Environment hooks a stage rule sets each frame: a speed factor (marsh
# water) and a push (currents, wind) that composes with walking.
var env_speed := 1.0
var push := Vector2.ZERO
# Statuses by name -> seconds left (burning, frozen, marked).
var status := {}
var _rally_t := 0.0
var _rally_speed := 1.0
var _rally_dmg := 1.0
var tint := Color(1, 1, 1)

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

# Boss patterns. Each boss has one signature move on a cooldown; _cast_phase
# runs 0 wind-up -> 1 commit, so the telegraph and the hit cannot drift apart.
# Data-driven bosses keep this clock and let their BossController choose
# what each wind-up and commit actually is.
var _cast_t := 5.0
var _cast_phase := 0
var _cast_dir := Vector2.ZERO
var _enraged := false

# Elite affix. Elites used to be one flavour -- eight times the health, same
# behaviour -- which made every one of them the same slow slog.
var affix := ""
var _affix_t := 0.0
var _shielded := false

const WALK_FPS := 10.0

var _spr: Sprite2D = null
var _spr_facing := 0.0



func is_boss() -> bool:
	if data != null:
		return data.is_boss
	return etype == "herald" or etype == "maw" or etype == "cinderking"


func has_tag(t: String) -> bool:
	return data != null and data.tags.has(t)


func set_targetable(on: bool) -> void:
	# Weapons find targets through the "enemies" group, so leaving it is what
	# makes a burrowed or submerged foe genuinely unhittable. "hostiles" is
	# kept either way so stage cleanup still finds it.
	untargetable = not on
	if on:
		add_to_group("enemies")
	elif is_in_group("enemies"):
		remove_from_group("enemies")


func _dashes() -> bool:
	return etype == "wisp" or etype == "bogling" or etype == "imp"


func setup(p_type: String, pos: Vector2, hp_m: float, dmg_m: float) -> void:
	etype = p_type
	var gm = Engine.get_main_loop().root.get_node_or_null("GameManager") if Engine.get_main_loop() else null
	if gm:
		data = gm.CONTENT.enemy(p_type)
	var d: Dictionary = TYPES[p_type]
	max_hp = float(d["hp"]) * hp_m
	hp = max_hp
	dmg = float(d["dmg"]) * dmg_m
	speed = float(d["speed"])
	xp_value = int(d["xp"])
	body_radius = float(d["radius"])
	if data:
		tint = data.tint
		is_boss_object = data.has_tag("summon")
		if data.behavior:
			behavior = data.behavior.new()
			behavior.attach(self, data.behavior_params)
			add_child(behavior)
	_make_sprite()
	position = pos
	_dash_t = randf_range(0.5, 1.5)
	_tick = randf_range(0.0, 0.4)



func _make_sprite() -> void:
	var frames := data.walk_frames if data else 0
	if frames <= 0:
		return
	var tex: Texture2D = load("res://assets/sprites/%s_walk.png" % etype)
	if tex == null:
		return
	_spr = Sprite2D.new()
	_spr.texture = tex
	_spr.hframes = frames
	# Draw under the node's own _draw(), so the shadow, elite aura and hit
	# flash still land on top of the body.
	_spr.show_behind_parent = true
	add_child(_spr)


func make_elite(forced := "") -> void:
	is_elite = true
	add_to_group("elites")
	affix = forced if forced != "" else AFFIXES[randi() % AFFIXES.size()]
	# A splitting elite dies twice over, so it does not also need the full
	# health bar, and a swift one trades bulk for the speed.
	var hp_mult := 8.0
	match affix:
		"swift":
			hp_mult = 5.0
			speed *= 1.75
		"splitting":
			hp_mult = 5.5
		"warded":
			hp_mult = 6.5
			_affix_t = 0.0
		"venomous":
			hp_mult = 7.0
			_affix_t = 0.8
	max_hp *= hp_mult
	hp = max_hp
	dmg *= 1.5
	if affix != "swift":
		speed *= 1.15
	body_radius *= 1.35
	scale = Vector2(1.35, 1.35)
	var lm = get_node_or_null("/root/LightingMan")
	if lm:
		lm.attach_aura(self, AFFIX_COLORS.get(affix, Color(1.0, 0.32, 0.16)), 2.4, 0.9)


func _ready() -> void:
	add_to_group("enemies")
	# Never left: stage cleanup sweeps "hostiles" so a burrowed or otherwise
	# special enemy cannot survive a transition.
	add_to_group("hostiles")
	main = get_tree().get_first_node_in_group("main")
	am = get_node("/root/AudioMan")
	jm = get_node("/root/JuiceMan")


func apply_rally(spd: float, dmg_mult: float, dur: float) -> void:
	_rally_t = maxf(_rally_t, dur)
	_rally_speed = maxf(_rally_speed, spd) if _rally_t > 0.0 else spd
	_rally_dmg = maxf(_rally_dmg, dmg_mult) if _rally_t > 0.0 else dmg_mult


func rallied() -> bool:
	return _rally_t > 0.0


func set_status(s: String, dur: float) -> void:
	status[s] = maxf(float(status.get(s, 0.0)), dur)


func has_status(s: String) -> bool:
	return float(status.get(s, 0.0)) > 0.0


func clear_status(s: String) -> void:
	status.erase(s)


func _tick_status(delta: float) -> void:
	if status.is_empty():
		return
	for k in status.keys():
		var v: float = float(status[k]) - delta
		if v <= 0.0:
			status.erase(k)
		else:
			status[k] = v


func _physics_process(delta: float) -> void:
	if dead:
		return
	_anim += delta
	_tick_status(delta)
	if _rally_t > 0.0:
		_rally_t -= delta
		if _rally_t <= 0.0:
			_rally_speed = 1.0
			_rally_dmg = 1.0
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
	var spd := speed * slow_mult * env_speed * _rally_speed
	if controller:
		spd *= controller.speed_scale()
	if behavior:
		dir = behavior.step(delta, dir)
	elif _dashes():
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
	velocity = dir * spd + _kb + push
	push = Vector2.ZERO
	# A charging boss is carried by _kb, so it must not be damped like a
	# knockback or the lunge dies a frame after it starts.
	var damp := 380.0 if (is_boss() and _cast_phase == 0 and _kb.length() > 300.0) else 900.0
	_kb = _kb.move_toward(Vector2.ZERO, damp * delta)
	move_and_slide()
	if main and main.director and is_instance_valid(main.director) and not main.director.obstacles.is_empty():
		position = main.director.resolve(position, body_radius * 0.8)
	if _spr != null:
		_spr.frame = int(_anim * WALK_FPS) % _spr.hframes
		# The art is drawn facing south: heads, snouts and outstretched hands all
		# point towards +Y, so a heading of +Y needs no rotation.
		if velocity.length_squared() > 1.0:
			_spr_facing = velocity.angle() - PI * 0.5
		_spr.rotation = _spr_facing - rotation
		var f := clampf(_flash / 0.12, 0.0, 1.0)
		_spr.modulate = tint.lerp(Color(2.4, 2.0, 2.0), f)
	_tick -= delta
	if _tick <= 0.0 and dist < body_radius + 22.0 and _can_contact():
		var hit := dmg * _rally_dmg
		if main and main.combat:
			hit = main.combat.contact_damage(self, hit)
		player.take_damage(hit, "enemy:" + etype)
		if is_elite and affix == "vampiric":
			# Feeds on what it hits, so ignoring it is not a strategy.
			hp = minf(max_hp, hp + dmg * 2.5)
			if main and main.has_method("spawn_damage_number"):
				main.spawn_damage_number(global_position, dmg * 2.5,
					AFFIX_COLORS["vampiric"])
			queue_redraw()
		if is_boss():
			jm.hit_stop(0.06)
			jm.add_trauma(0.35)
		_tick = 0.9
	if is_boss():
		_step_boss(delta, dir)
	elif is_elite:
		_step_elite(delta)
	queue_redraw()


func _can_contact() -> bool:
	if dmg <= 0.0 or untargetable or not bool(player.get("alive")):
		return false
	if behavior and not behavior.can_contact():
		return false
	if controller and controller.untargetable():
		return false
	return true


# --- boss patterns -------------------------------------------------------
#
# Bosses without a BossData controller (Rotgrove, and bosses spawned directly
# by tests) keep the original signature move per body. Data-driven bosses
# route every wind-up and commit through their controller.

const CAST_GAP := {"herald": 6.5, "maw": 7.5, "cinderking": 6.0}
const WINDUP := {"herald": 0.85, "maw": 1.0, "cinderking": 0.7}


func _aura_color() -> Color:
	if controller:
		return controller.data.aura
	if main and main.gm and main.gm.has_method("stage_data"):
		return main.gm.stage_data().get("boss_aura", Color(1.0, 0.5, 0.2))
	return Color(1.0, 0.5, 0.2)


func _step_boss(delta: float, dir: Vector2) -> void:
	if controller:
		controller.tick(delta, dir)
	else:
		# Enrage once, at 40%. The fight should get louder as it closes out.
		if not _enraged and hp < max_hp * 0.4:
			_enraged = true
			speed *= 1.25
			if jm:
				jm.add_trauma(0.5)
			if main and main.hud and main.hud.has_method("show_warning"):
				main.hud.show_warning("ENRAGED")
		_summon_t -= delta
		if _summon_t <= 0.0:
			_summon_t = 6.0 if _enraged else 9.0
			if main and main.has_method("summon_minions"):
				main.summon_minions(global_position)
	_cast_t -= delta
	if _cast_t > 0.0:
		return
	if _cast_phase == 0:
		# Wind up: paint the telegraph, hold still enough to be read.
		_cast_dir = dir
		if controller:
			var w: float = controller.begin_cast(dir)
			if w < 0.0:
				# Nothing fits the hazard budget yet; look again shortly.
				_cast_t = 0.5
				return
			_cast_phase = 1
			_cast_t = w
		else:
			_cast_phase = 1
			_cast_t = float(WINDUP.get(etype, 0.85))
			_telegraph()
	else:
		_cast_phase = 0
		if controller:
			_cast_t = controller.commit_cast()
		else:
			var gap := float(CAST_GAP.get(etype, 6.5))
			_cast_t = gap * (0.62 if _enraged else 1.0)
			_commit()


func _telegraph() -> void:
	if main == null or not main.has_method("spawn_hazard"):
		return
	var col := _aura_color()
	match etype:
		"maw":
			# Show the lane it is about to charge down.
			var h: Node2D = main.spawn_hazard("lane", global_position, 0.0, col)
			h.lane_to = global_position + _cast_dir * 520.0
			h.radius = body_radius * 1.1
			h.life = float(WINDUP["maw"])
		"cinderking":
			# Mark the ground under and around the player.
			var target: Vector2 = player.global_position if player else global_position
			for i in 4:
				var p := target + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 150.0)
				var e = main.spawn_hazard("eruption", p, dmg * 1.1, col)
				e.radius = 74.0
				e.telegraph = float(WINDUP["cinderking"])
				e.life = e.telegraph + 0.45
		_:
			# Herald gathers light before the volley.
			if lm_node():
				lm_node().flash(global_position, col, 2.0, 3.0, float(WINDUP["herald"]))
	if am:
		am.play_ranged("boss_roar", -12.0, 1.15, 1.3)


func _commit() -> void:
	if controller:
		# Tests and debug tools may force a commit directly; it means the same
		# thing as the cast clock reaching it.
		controller.commit_cast()
		return
	if main == null or not main.has_method("spawn_hazard"):
		return
	var col := _aura_color()
	match etype:
		"herald":
			# A ring of slow bolts: dodgeable, but it takes the arena away from
			# you rather than chasing you down.
			var n := 12 if _enraged else 9
			var base := randf() * TAU
			for i in n:
				var a := base + TAU * float(i) / float(n)
				var b = main.spawn_hazard("bolt", global_position, dmg * 0.8, col)
				b.vel = Vector2.from_angle(a) * 210.0
				b.radius = 12.0
				b.life = 3.4
		"maw":
			# Commit to the lane it painted, whatever the player did with it.
			_kb = _cast_dir * 1150.0
			if jm:
				jm.add_trauma(0.4)
		"cinderking":
			# The eruptions land on their own timers; the king just roars.
			if jm:
				jm.hit_stop(0.05)
				jm.add_trauma(0.3)
	if am:
		am.play_ranged("boss_roar", -6.0, 0.85, 0.95)


func lm_node():
	return get_node_or_null("/root/LightingMan")


# --- elite affixes -------------------------------------------------------

const AFFIXES := ["swift", "venomous", "vampiric", "warded", "splitting"]
const AFFIX_COLORS := {
	"swift": Color(0.45, 0.9, 1.0),
	"venomous": Color(0.5, 1.0, 0.35),
	"vampiric": Color(1.0, 0.25, 0.35),
	"warded": Color(1.0, 0.85, 0.35),
	"splitting": Color(0.8, 0.45, 1.0),
}
const AFFIX_NAMES := {
	"swift": "SWIFT", "venomous": "VENOMOUS", "vampiric": "VAMPIRIC",
	"warded": "WARDED", "splitting": "SPLITTING",
}


func _step_elite(delta: float) -> void:
	match affix:
		"venomous":
			# Leaves a trail worth stepping around.
			_affix_t -= delta
			if _affix_t <= 0.0:
				_affix_t = 0.8
				if main and main.has_method("spawn_hazard"):
					var pool = main.spawn_hazard("pool", global_position, dmg * 0.35,
						AFFIX_COLORS["venomous"])
					pool.radius = 58.0
					pool.life = 4.5
		"warded":
			# A ward that comes back if you cannot burst through it.
			_affix_t -= delta
			if _affix_t <= 0.0:
				_affix_t = 6.0
				_shielded = true
				queue_redraw()


func take_damage(amount: float, from_pos: Vector2, knockback: float, source := "") -> void:
	if dead or untargetable:
		return
	if controller and controller.untargetable():
		return
	if _shielded:
		# The ward eats the hit whole, then has to be rebuilt. Burst it or work
		# around it; chipping at it achieves nothing.
		_shielded = false
		_flash = 0.12
		_affix_t = 6.0
		if main and main.has_method("spawn_damage_number"):
			main.spawn_damage_number(global_position, 0.0, AFFIX_COLORS["warded"])
		if jm:
			jm.shockwave(global_position, AFFIX_COLORS["warded"], 70.0)
		queue_redraw()
		return
	if main and main.combat:
		amount = main.combat.modify_hit(self, amount, source, knockback)
	if behavior:
		amount = behavior.modify_damage(amount, from_pos, source)
	if controller:
		amount = controller.modify_damage(amount, from_pos, source)
	if main and main.gm and main.gm.run_stats:
		main.gm.run_stats.add_damage(source, minf(amount, maxf(hp, 0.0)))
	hp -= amount
	_flash = 0.12
	var away: Vector2 = global_position - from_pos
	var dir := away.normalized() if away.length() > 1.0 else Vector2.ZERO
	var kbm := 1.0
	if is_boss():
		kbm = 0.12
	if is_elite or is_boss_object or (data and data.speed <= 0.0):
		kbm = 0.0
	if main and main.gm:
		kbm *= main.gm.mods.mult("knockback")
	_kb += dir * knockback * kbm
	if main and main.has_method("spawn_damage_number"):
		main.spawn_damage_number(global_position, amount, Color(1.0, 0.85, 0.4))
	if hp <= 0.0:
		dead = true
		if behavior:
			behavior.on_death()
		died.emit()
		am.play_ranged("enemy_die", -8.0, 0.9, 1.15)
		jm.death_fx(global_position, is_boss(), etype, _spr_facing)
		_drop_rewards()
		if main and main.combat:
			main.combat.on_kill(self, source)
		if is_elite and affix == "splitting":
			_split()
		if controller:
			controller.cleanup()
		queue_free()
	else:
		am.play_ranged("hit_flesh", -16.0, 0.85, 1.2)
		queue_redraw()


func _drop_rewards() -> void:
	# Revived dead and boss props give nothing back: raising and killing the
	# same corpses must never be a farm.
	if no_credit or revived or main == null:
		return
	var profile := data.drop_profile if data else "standard"
	if profile == "none":
		return
	if main.has_method("spawn_gem") and xp_value > 0:
		main.spawn_gem(global_position, xp_value)
	if profile == "mimic" and main.has_method("spawn_shard"):
		for i in 6:
			main.spawn_shard(global_position + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 40.0), 1)
		return
	if main.has_method("spawn_shard"):
		_roll_shard_drop()


func apply_slow(mult: float, dur: float) -> void:
	if data and data.status_resist.has("slow"):
		dur *= float(data.status_resist["slow"])
	if slow_t > 0.0:
		slow_mult = minf(slow_mult, mult)
	else:
		slow_mult = mult
	slow_t = maxf(slow_t, dur)


func is_slowed() -> bool:
	return slow_t > 0.0 and slow_mult < 0.99



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
		_draw_status()
		if is_elite:
			_draw_elite_aura()
		if _flash > 0.0:
			draw_circle(Vector2.ZERO, body_radius + 2.0, Color(1, 1, 1, 0.35))
		return

	if behavior == null or not behavior.draw_body(self):
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
			_:
				draw_circle(Vector2.ZERO, body_radius, Color(0.4, 0.3, 0.35))
	_draw_status()
	if is_elite:
		_draw_elite_aura()
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, body_radius + 2.0, Color(1, 1, 1, 0.55))


func _draw_status() -> void:
	# Small, shape-coded status marks: flame tongues for burning, a hex for
	# frozen, a notch ring for the lance's mark.
	if status.is_empty() and not rallied():
		return
	var r := body_radius + 6.0
	if has_status("burning"):
		for i in 3:
			var a := -PI * 0.5 + (float(i) - 1.0) * 0.5
			var b := Vector2.from_angle(a) * r
			draw_colored_polygon(PackedVector2Array([b + Vector2(-4, 0), b + Vector2(4, 0), b + Vector2.from_angle(a) * 10.0]), Color(1, 0.5, 0.15, 0.9))
	if has_status("frozen"):
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2.from_angle(TAU * float(i) / 6.0) * r)
		draw_polyline(pts, Color(0.7, 0.92, 1.0, 0.85), 2.5)
	if has_status("marked"):
		for i in 4:
			var a2 := TAU * float(i) / 4.0 + _anim * 2.0
			draw_arc(Vector2.ZERO, r + 4.0, a2, a2 + 0.6, 6, Color(0.95, 0.9, 0.75, 0.9), 3.0)
	if rallied():
		draw_arc(Vector2(0, -r - 6.0), 5.0, 0.0, TAU, 10, Color(1, 0.8, 0.35, 0.9), 2.0)


func _split() -> void:
	# Two lesser copies, no affix of their own -- a splitting elite that spawned
	# splitting elites would never stop.
	if main == null or not main.has_method("spawn_split"):
		return
	for i in 2:
		var off := Vector2.from_angle(randf() * TAU) * randf_range(26.0, 48.0)
		main.spawn_split(etype, global_position + off, max_hp * 0.16, dmg)


func _draw_elite_aura() -> void:
	var pulse := 0.5 + 0.5 * sin(_anim * 6.0)
	# The ring carries the affix colour and the label names it, so you can tell
	# what you are fighting before it reaches you.
	var c: Color = AFFIX_COLORS.get(affix, Color(1.0, 0.38, 0.12))

	draw_arc(Vector2.ZERO, body_radius + 9.0, 0, TAU, 40,
		Color(c.r, c.g * (0.8 + 0.2 * pulse), c.b, 0.85), 5.0)
	draw_arc(Vector2.ZERO, body_radius + 16.0, 0, TAU, 40,
		Color(c.r, c.g, c.b, 0.25 + 0.25 * pulse), 3.0)
	if _shielded:
		draw_arc(Vector2.ZERO, body_radius + 23.0, 0, TAU, 44,
			Color(1.0, 0.92, 0.55, 0.55 + 0.35 * pulse), 4.0)

	var label: String = AFFIX_NAMES.get(affix, "ELITE")
	draw_string(ThemeDB.fallback_font, Vector2(-70, -body_radius - 14.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, 140, 22, c)


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
