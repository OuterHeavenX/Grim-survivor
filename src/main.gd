extends Node2D


const PlayerScript := preload("res://src/player.gd")
const EnemyScript := preload("res://src/enemy.gd")
const GemScript := preload("res://src/gem.gd")
const ShardScript := preload("res://src/shard.gd")
const ChestScript := preload("res://src/chest.gd")
const LootScript := preload("res://src/loot_ui.gd")
const HudScript := preload("res://src/hud.gd")
const LevelUpScript := preload("res://src/levelup_ui.gd")
const TitleScript := preload("res://src/title_screen.gd")
const CharSelectScript := preload("res://src/char_select.gd")
const EndScript := preload("res://src/end_screen.gd")
const PauseScript := preload("res://src/pause_menu.gd")
const UpgradesScript := preload("res://src/upgrades_ui.gd")
const BgScript := preload("res://src/bg.gd")
const GroundScript := preload("res://src/ground.gd")
const FogScript := preload("res://src/fog.gd")

const MAX_ENEMIES := 70
const ARENA := 1500.0
const ELITE_TIMES := [60.0, 105.0, 150.0, 195.0, 240.0, 270.0]
const MAX_LIVE_ELITES := 3

var gm = null
var am = null
var jm = null
var lm = null
var run: Node2D
var player = null
var boss = null
var hud = null
var levelup_ui = null
var loot_ui = null
var title_screen = null
var char_select = null
var end_screen = null
var pause_menu = null
var upgrades_ui = null
var fog_a: Node2D
var fog_b: Node2D
var ground: Node2D

var intermission := 0.0
var _ash: CPUParticles2D


func _recenter_ash() -> void:
	if _ash:
		_ash.position = get_viewport_rect().size * 0.5
		_ash.emission_rect_extents = get_viewport_rect().size * 0.5 + Vector2(40, 40)

var spawn_timer := 0.0
var warned := false
var _elite_idx := 0


func _ready() -> void:
	add_to_group("main")
	gm = get_node("/root/GameManager")
	am = get_node("/root/AudioMan")
	jm = get_node("/root/JuiceMan")
	lm = get_node("/root/LightingMan")

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	bg_layer.add_child(BgScript.new())
	add_child(bg_layer)

	ground = GroundScript.new()
	add_child(ground)

	fog_a = FogScript.new()
	fog_b = FogScript.new()
	fog_b.fog_radius = 700.0
	fog_b.fog_color = Color(0.35, 0.45, 0.65, 0.05)
	fog_b.wind = Vector2(-10.0, 4.0)
	add_child(fog_a)
	add_child(fog_b)


	var ash_layer := CanvasLayer.new()
	ash_layer.layer = 4
	add_child(ash_layer)
	var ash := CPUParticles2D.new()
	ash.amount = 60
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(400, 700)
	ash.direction = Vector2(0.25, 1.0)
	ash.spread = 30.0
	ash.initial_velocity_min = 14.0
	ash.initial_velocity_max = 42.0
	ash.gravity = Vector2.ZERO
	ash.scale_amount_min = 1.5
	ash.scale_amount_max = 3.5
	ash.color = Color(0.75, 0.78, 0.86, 0.3)
	ash_layer.add_child(ash)
	_ash = ash
	_recenter_ash()
	get_tree().root.size_changed.connect(_recenter_ash)

	hud = HudScript.new()
	add_child(hud)
	player_joy_wire()

	levelup_ui = LevelUpScript.new()
	add_child(levelup_ui)
	levelup_ui.choice_made.connect(_on_upgrade_chosen)

	loot_ui = LootScript.new()
	add_child(loot_ui)
	loot_ui.loot_chosen.connect(_on_loot_chosen)

	pause_menu = PauseScript.new()
	add_child(pause_menu)
	pause_menu.resume_pressed.connect(_on_resume)
	pause_menu.restart_pressed.connect(start_run)
	pause_menu.title_pressed.connect(show_title)

	end_screen = EndScript.new()
	add_child(end_screen)
	end_screen.restart_pressed.connect(start_run)
	end_screen.title_pressed.connect(show_title)

	title_screen = TitleScript.new()
	add_child(title_screen)
	title_screen.start_pressed.connect(_on_start)
	title_screen.upgrades_pressed.connect(_on_upgrades_open)

	char_select = CharSelectScript.new()
	add_child(char_select)
	char_select.run_pressed.connect(start_run)
	char_select.back_pressed.connect(show_title)

	upgrades_ui = UpgradesScript.new()
	add_child(upgrades_ui)
	upgrades_ui.closed.connect(_on_upgrades_closed)

	hud.pause_pressed.connect(_on_pause_button)
	hud.set_run_visible(false)

	gm.level_changed.connect(_on_level_changed)
	gm.run_ended.connect(_on_run_ended)


func player_joy_wire() -> void:

	pass


func start_run() -> void:
	am.play("ui_click", -8.0)
	if run:
		run.queue_free()
		run = null
	boss = null
	get_tree().paused = false
	gm.reset_run()
	title_screen.hide_screen()
	char_select.hide_screen()
	end_screen.hide_screen()
	pause_menu.hide_screen()
	levelup_ui.hide_screen()
	loot_ui.hide_screen()
	run = Node2D.new()
	run.name = "Run"
	add_child(run)
	player = PlayerScript.new()
	player.position = Vector2.ZERO
	player.died.connect(_on_player_died)
	run.add_child(player)
	player.joy_ui = hud.joy
	spawn_timer = 0.8
	warned = false
	_elite_idx = 0
	intermission = 0.0
	_apply_stage_theme()
	hud.reset()
	hud.set_run_visible(true)
	hud.hide_boss()


func show_title() -> void:
	am.play("ui_click", -8.0)
	if run:
		run.queue_free()
		run = null
	player = null
	boss = null
	get_tree().paused = false
	gm.state = gm.State.TITLE
	hud.set_run_visible(false)
	end_screen.hide_screen()
	pause_menu.hide_screen()
	levelup_ui.hide_screen()
	loot_ui.hide_screen()
	char_select.hide_screen()
	title_screen.show_screen()



func _on_start() -> void:
	am.play("ui_click", -8.0)
	title_screen.hide_screen()
	char_select.show_screen()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE or k == KEY_P:
			if gm.state == gm.State.RUNNING:
				_on_pause_button()
			elif gm.state == gm.State.PAUSED:
				_on_resume()


func _on_pause_button() -> void:
	if gm.state != gm.State.RUNNING:
		return
	am.play("ui_click", -8.0)
	gm.state = gm.State.PAUSED
	if player:
		player.release_joystick()
	get_tree().paused = true
	pause_menu.show_screen()


func _on_resume() -> void:
	if gm.state != gm.State.PAUSED:
		return
	am.play("ui_click", -8.0)
	pause_menu.hide_screen()
	get_tree().paused = false
	gm.state = gm.State.RUNNING


func _on_level_changed() -> void:
	if gm.state == gm.State.RUNNING and gm.pending_levelups > 0:
		gm.state = gm.State.LEVELUP
		jm.hit_stop(0.05)
		am.play("levelup_chime", -4.0)
		am.duck(true)
		if player:
			player.release_joystick()
			jm.pillar(player.global_position)
		get_tree().paused = true
		levelup_ui.show_screen(gm.roll_upgrades())


func _on_upgrade_chosen() -> void:
	am.play("ui_click", -10.0)
	get_tree().paused = false
	if gm.pending_levelups > 0:
		gm.state = gm.State.LEVELUP
		get_tree().paused = true
		levelup_ui.show_screen(gm.roll_upgrades())
	else:
		am.duck(false)
		gm.state = gm.State.RUNNING


func _on_player_died() -> void:
	gm.end_run(false)



func open_chest(chest) -> void:
	if gm.state != gm.State.RUNNING:
		return
	gm.state = gm.State.CHEST
	if player:
		player.release_joystick()
	get_tree().paused = true
	am.duck(true)
	am.play("chest_open", -4.0)
	jm.gold_burst(chest.global_position)
	hud.show_warning("ELITE SPOILS")
	loot_ui.show_screen(roll_loot())
	chest.queue_free()


func roll_loot() -> Array:
	var pool: Array = []
	var wopt = _loot_weapon_option()
	if wopt != null:
		pool.append(wopt)
	pool.append({"kind": "heal", "name": "Feast of Souls",
		"desc": "Restore 60% of max HP."})
	pool.append({"kind": "shards", "name": "Shard Cache",
		"desc": "+25 soul shards, banked after the run."})
	pool.append({"kind": "xp", "name": "Soul Surge",
		"desc": "Gain XP worth 1.5 levels."})
	var pickups := get_tree().get_nodes_in_group("gems").size() \
		+ get_tree().get_nodes_in_group("shards").size()
	if pickups >= 5:
		pool.append({"kind": "magnet_burst", "name": "Greed Nova",
			"desc": "Vacuum every gem and shard on screen."})
	if gm.revives_left < 3:
		pool.append({"kind": "revive", "name": "Cheat Death",
			"desc": "+1 Second Wind charge for this run."})
	pool.shuffle()
	return pool.slice(0, 3)




func _loot_weapon_option():
	var ups := []
	for id in gm.WEAPONS:
		var lvl := int(gm.weapons.get(id, 0))
		if lvl > 0 and lvl < int(gm.WEAPONS[id]["max"]):
			ups.append(id)
	if not ups.is_empty():
		ups.shuffle()
		var id: String = ups[0]
		var w: Dictionary = gm.WEAPONS[id]
		return {"kind": "weapon", "id": id, "to": int(gm.weapons[id]) + 1,
			"name": "%s  Lv %d" % [str(w["name"]), int(gm.weapons[id]) + 1],
			"desc": str(w["up"])}
	for id in gm.WEAPONS:
		if not gm.weapons.has(id) and gm.weapons.size() < gm.MAX_WEAPONS:
			var w2: Dictionary = gm.WEAPONS[id]
			return {"kind": "weapon", "id": id, "to": 1,
				"name": "NEW!  %s" % str(w2["name"]), "desc": str(w2["desc"])}
	return null


func _on_loot_chosen(choice: Dictionary) -> void:
	am.play("ui_click", -10.0)
	loot_ui.hide_screen()
	get_tree().paused = false
	am.duck(false)
	gm.state = gm.State.RUNNING
	_apply_loot(choice)


func _apply_loot(choice: Dictionary) -> void:
	match String(choice["kind"]):
		"weapon":
			gm.weapons[choice["id"]] = choice["to"]
			gm.weapons_changed.emit()
		"heal":
			if player:
				player.heal(player.max_hp * 0.6)
		"shards":
			gm.add_shards(25)
		"xp":
			gm.add_xp(int(float(gm.xp_needed()) * 1.5))
		"magnet_burst":
			_vacuum_all()
		"revive":
			gm.revives_left += 1



func _vacuum_all() -> void:
	if player == null:
		return
	for g in get_tree().get_nodes_in_group("gems"):
		g.position = player.global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	for s in get_tree().get_nodes_in_group("shards"):
		s.position = player.global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))


func _on_run_ended(victory: bool) -> void:
	if player:
		player.release_joystick()
		if victory:
			jm.pillar(player.global_position)
			lm.flash(player.global_position, Color(0.6, 0.8, 1.0), 2.4, 4.0, 0.6)
	get_tree().paused = true
	am.duck(false)
	if victory:
		am.play("victory_sting", -2.0)
	else:
		am.play("gameover_drone", -2.0)
	end_screen.show_screen(victory, gm.run_time, gm.kills, gm.level, gm.last_banked)


func _on_upgrades_open() -> void:
	am.play("ui_click", -8.0)
	am.duck(true)
	title_screen.hide_screen()
	upgrades_ui.show_screen()


func _on_upgrades_closed() -> void:
	am.play("ui_click", -8.0)
	am.duck(false)
	upgrades_ui.hide_screen()
	title_screen.show_screen()



func _apply_stage_theme() -> void:
	var sd: Dictionary = gm.stage_data()
	if ground and ground.has_method("set_theme"):
		ground.call("set_theme", str(sd["theme"]))
	var fog_tint := Color(0.35, 0.45, 0.65)
	match str(sd["theme"]):
		"marsh":
			fog_tint = Color(0.35, 0.55, 0.4)
		"cinder":
			fog_tint = Color(0.6, 0.35, 0.25)
	if fog_a:
		fog_a.set("fog_color", Color(fog_tint, 0.05))
	if fog_b:
		fog_b.set("fog_color", Color(fog_tint, 0.05))
	hud.set_stage(gm.stage, str(sd["name"]))



func _advance_stage() -> void:
	gm.stage += 1
	gm.run_time = 0.0
	gm.boss_spawned = false
	gm.boss_alive = false
	boss = null
	warned = false
	_elite_idx = 0
	intermission = 5.0
	hud.hide_boss()
	for e in get_tree().get_nodes_in_group("enemies"):
		jm.gold_burst(e.global_position)
		e.queue_free()
	if player:
		player.heal(99999.0)
	_apply_stage_theme()
	var sd: Dictionary = gm.stage_data()
	hud.show_warning("STAGE %d — %s" % [gm.stage + 1, str(sd["name"])])
	am.play("victory_sting", -6.0)


func _physics_process(delta: float) -> void:
	if gm.state != gm.State.RUNNING:
		return
	gm.run_time += delta
	gm.time_changed.emit()
	if intermission > 0.0:
		intermission -= delta
	else:
		_spawner(delta)
		_elite_schedule()
	_separation()
	if player:
		fog_a.position = player.position
		fog_b.position = player.position + Vector2(400, -300)
	if not warned and gm.run_time >= gm.RUN_DURATION - 8.0:
		warned = true
		hud.show_warning("THE " + str(gm.stage_data()["boss_name"]) + " APPROACHES")
	if not gm.boss_spawned and gm.run_time >= gm.RUN_DURATION:
		_spawn_boss()
	if gm.boss_alive and boss and is_instance_valid(boss):
		hud.update_boss(boss.hp, boss.max_hp)


func _spawner(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var t: float = gm.run_time
	spawn_timer = lerpf(1.1, 0.28, clampf(t / 300.0, 0.0, 1.0))
	if _enemy_count() >= MAX_ENEMIES:
		return
	var pool: Array = gm.stage_data()["pool"]
	var etype: String = str(pool[randi() % pool.size()])
	_spawn_enemy(etype, _ring_pos())


func _ring_pos() -> Vector2:
	if player == null:
		return Vector2.ZERO
	var ang := randf() * TAU
	var dist := randf_range(760.0, 950.0)
	var p: Vector2 = player.position + Vector2.from_angle(ang) * dist
	p.x = clampf(p.x, -ARENA, ARENA)
	p.y = clampf(p.y, -ARENA, ARENA)
	return p


func _enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()



func _elite_schedule() -> void:
	if _elite_idx >= ELITE_TIMES.size():
		return
	if gm.run_time < float(ELITE_TIMES[_elite_idx]):
		return
	_elite_idx += 1
	if _live_elites() >= MAX_LIVE_ELITES:
		return
	_spawn_elite()


func _live_elites() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if bool(e.get("is_elite")):
			n += 1
	return n


func _spawn_elite() -> void:
	var epool: Array = gm.stage_data()["pool"]
	var etype: String = str(epool[randi() % epool.size()])
	var e = _spawn_enemy(etype, _ring_pos())
	e.make_elite()
	hud.show_warning("ELITE APPROACHES")
	am.play("elite_horn", -4.0)
	jm.add_trauma(0.25)
	jm.gold_burst(e.global_position)


func _spawn_enemy(etype: String, pos: Vector2):
	var t: float = gm.run_time
	var hp_m := (1.0 + t / 60.0 * 0.35) * (1.0 + float(gm.stage) * 0.8)
	var dmg_m := (1.0 + t / 120.0 * 0.2) * (1.0 + float(gm.stage) * 0.35)
	var e = EnemyScript.new()
	e.setup(etype, pos, hp_m, dmg_m)
	e.died.connect(_on_enemy_died.bind(e))
	run.add_child(e)
	return e


func summon_minions(pos: Vector2) -> void:
	for i in 2:
		if _enemy_count() >= MAX_ENEMIES:
			return
		var p := pos + Vector2.from_angle(randf() * TAU) * randf_range(80.0, 160.0)
		p.x = clampf(p.x, -ARENA, ARENA)
		p.y = clampf(p.y, -ARENA, ARENA)
		_spawn_enemy("skeleton", p)


func _spawn_boss() -> void:
	gm.boss_spawned = true
	gm.boss_alive = true
	var sd: Dictionary = gm.stage_data()
	var e = _spawn_enemy(str(sd["boss"]), _ring_pos())
	boss = e
	am.play("boss_warning_horn", -2.0)
	am.play("boss_roar", -4.0, 0.9)
	lm.attach_aura(e, sd["boss_aura"], 3.6, 1.0)
	jm.add_trauma(0.55)
	jm.hit_stop(0.06)
	hud.show_boss(str(sd["boss_name"]))
	hud.update_boss(e.hp, e.max_hp)
	hud.show_warning(str(sd["boss_name"]) + " RISES")


func _on_enemy_died(e) -> void:
	gm.add_kill()
	var sh: float = gm.siphon_heal()
	if sh > 0.0 and player:
		player.heal(sh)
	if bool(e.get("is_elite")):

		jm.add_trauma(0.5)
		jm.hit_stop(0.06)
		jm.gold_burst(e.global_position)
		jm.shockwave(e.global_position, Color(1.0, 0.75, 0.3), 170.0)
		lm.flash(e.global_position, Color(1.0, 0.6, 0.25), 2.2, 3.4, 0.4)
		am.play("explosion", -4.0, 1.2)
		for i in 5:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(14.0, 44.0)
			spawn_shard(e.global_position + off, 1)
		spawn_chest(e.global_position)
	if e.is_boss():
		gm.boss_alive = false
		boss = null
		hud.hide_boss()
		var aura_c: Color = gm.stage_data()["boss_aura"]
		jm.add_trauma(0.7)
		jm.hit_stop(0.08)
		jm.shockwave(e.global_position, aura_c, 260.0)
		lm.flash(e.global_position, aura_c, 2.6, 4.5, 0.5)

		var drops: int = 5 + 3 * int(gm.stage)
		for i in drops:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0)
			spawn_shard(e.global_position + off, 5)
		if gm.stage >= gm.STAGES.size() - 1:
			gm.end_run(true)
		else:
			_advance_stage()


# Cell must be at least the largest possible sum of two body radii (the Cinder
# King is 56, so 112) for a 3x3 neighbour sweep to catch every overlapping pair.
const SEP_CELL := 128.0
const SEP_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1),
]


func _separation() -> void:
	var list := get_tree().get_nodes_in_group("enemies")
	var n := list.size()
	if n < 2:
		return

	# Read each enemy once. `position` and `body_radius` on an untyped node are
	# dynamic lookups, and the old pairwise sweep did four of them per pair --
	# at the 70-enemy cap that was 2415 pairs every physics frame.
	var pos := PackedVector2Array()
	var rad := PackedFloat32Array()
	pos.resize(n)
	rad.resize(n)
	var cells := {}
	for i in n:
		var e = list[i]
		var p: Vector2 = e.position
		pos[i] = p
		rad[i] = e.body_radius
		var key := Vector2i(floori(p.x / SEP_CELL), floori(p.y / SEP_CELL))
		if cells.has(key):
			cells[key].append(i)
		else:
			cells[key] = [i]

	# Resolve against the cached positions in place, so pushes still compound
	# within a frame the way the pairwise version's did.
	for key in cells:
		var here: Array = cells[key]
		var c := here.size()
		for ii in c:
			var i: int = here[ii]
			for jj in range(ii + 1, c):
				_push_apart(pos, rad, i, here[jj])
		# Only half the neighbourhood: the other half sees this cell from its
		# own side, so every pair is still visited exactly once.
		for off in SEP_NEIGHBOURS:
			var other = cells.get(key + off)
			if other == null:
				continue
			for i2 in here:
				for j2 in other:
					_push_apart(pos, rad, i2, j2)

	for i in n:
		list[i].position = pos[i]


func _push_apart(pos: PackedVector2Array, rad: PackedFloat32Array, i: int, j: int) -> void:
	var d: Vector2 = pos[j] - pos[i]
	var dist := d.length()
	var min_d: float = rad[i] + rad[j]
	if dist > 0.01 and dist < min_d:
		var push := d / dist * (min_d - dist) * 0.25
		pos[i] -= push
		pos[j] += push


func spawn_gem(pos: Vector2, value: int) -> void:
	var g = GemScript.new()
	g.value = value
	g.position = pos
	run.add_child(g)


func spawn_shard(pos: Vector2, value: int) -> void:
	var s = ShardScript.new()
	s.value = value
	s.position = pos
	run.add_child(s)


func spawn_chest(pos: Vector2) -> void:
	var c = ChestScript.new()
	c.position = pos
	run.add_child(c)


func spawn_boom(pos: Vector2, radius: float) -> void:
	var p = load("res://src/projectile.gd").new()
	p.setup("boom", 0.0, pos)
	p.ring_max = radius
	p.ring_color = Color(1.0, 0.55, 0.2, 0.8)
	p.z_index = 43
	run.add_child(p)
	jm.shockwave(pos, Color(1.0, 0.62, 0.25), radius * 1.6)
	lm.flash(pos, Color(1.0, 0.55, 0.22), 2.4, 3.2, 0.35)


func spawn_damage_number(pos: Vector2, amount: float, color: Color) -> void:
	if get_tree().get_nodes_in_group("dmgnums").size() > 40:
		return
	var lbl := Label.new()
	lbl.text = str(int(amount))
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_to_group("dmgnums")
	lbl.position = pos + Vector2(randf_range(-12.0, 12.0), -34.0)
	lbl.z_index = 50
	run.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 48.0, 0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(lbl.queue_free)
