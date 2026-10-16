extends Node2D


const PlayerScript := preload("res://src/player.gd")
const EnemyScript := preload("res://src/enemy.gd")
const GemScript := preload("res://src/gem.gd")
const ShardScript := preload("res://src/shard.gd")
const RelicScript := preload("res://src/relic.gd")
const ChestScript := preload("res://src/chest.gd")
const LootScript := preload("res://src/loot_ui.gd")
const HudScript := preload("res://src/hud.gd")
const LevelUpScript := preload("res://src/levelup_ui.gd")
const TitleScript := preload("res://src/title_screen.gd")
const CharSelectScript := preload("res://src/char_select.gd")
const EndScript := preload("res://src/end_screen.gd")
const PauseScript := preload("res://src/pause_menu.gd")
const UpgradesScript := preload("res://src/upgrades_ui.gd")
const WeaponsScript := preload("res://src/weapons_ui.gd")
const BgScript := preload("res://src/bg.gd")
const GroundScript := preload("res://src/ground.gd")
const FogScript := preload("res://src/fog.gd")
const HazardScript := preload("res://src/hazard.gd")
const DirectorScript := preload("res://src/stage/stage_director.gd")
const CombatScript := preload("res://src/combat/combat_rules.gd")
const RelicsScript := preload("res://src/relics/relic_manager.gd")
const ControllerScript := preload("res://src/boss/boss_controller.gd")
const AltarScript := preload("res://src/relics/relic_altar.gd")
const SettingsScript := preload("res://src/settings_ui.gd")

const MAX_ENEMIES := 70
# A hard ceiling for drifted-away pickups, in case a kill storm outruns the
# lifetime fade. Oldest go first.
const MAX_PICKUPS := 140
# Boss patterns and venom trails both spawn hazards, and an enraged boss in a
# late stage spawns a lot of them. Same reasoning as the pickup cap.
const MAX_HAZARDS := 90
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
var weapons_ui = null
var fog_a: Node2D
var fog_b: Node2D
var ground: Node2D
var settings_ui = null
# Per-run systems, children of `run` so they die with it.
var combat: CombatRules = null
var relics: RelicManager = null
# Per-stage: freed and rebuilt on every stage transition.
var director: StageDirector = null
# Recent deaths a necromancer may raise, oldest first: {pos, t, used}.
var _corpses: Array = []
const MAX_CORPSES := 16

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
	title_screen.weapons_pressed.connect(_on_weapons_open)

	char_select = CharSelectScript.new()
	add_child(char_select)
	char_select.run_pressed.connect(start_run)
	char_select.back_pressed.connect(show_title)

	upgrades_ui = UpgradesScript.new()
	add_child(upgrades_ui)
	upgrades_ui.closed.connect(_on_upgrades_closed)

	weapons_ui = WeaponsScript.new()
	add_child(weapons_ui)
	weapons_ui.closed.connect(_on_weapons_closed)

	settings_ui = SettingsScript.new()
	add_child(settings_ui)
	settings_ui.closed.connect(_on_settings_closed)
	pause_menu.settings_pressed.connect(_on_settings_open)
	title_screen.settings_pressed.connect(_on_settings_open)
	_apply_effect_settings()

	hud.pause_pressed.connect(_on_pause_button)
	hud.set_run_visible(false)

	gm.level_changed.connect(_on_level_changed)
	gm.run_ended.connect(_on_run_ended)


func player_joy_wire() -> void:

	pass


func _teardown_run() -> void:
	# Every exit from a run (restart, title, a new run after death or victory)
	# goes through here, so stage and boss cleanup cannot be skipped.
	if boss and is_instance_valid(boss) and boss.controller:
		boss.controller.cleanup()
	if director and is_instance_valid(director):
		director.cleanup()
	director = null
	combat = null
	relics = null
	_corpses.clear()
	gm.mods.clear_all()
	if run:
		run.queue_free()
		run = null


func start_run() -> void:
	am.play("ui_click", -8.0)
	_teardown_run()
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
	combat = CombatScript.new()
	combat.setup(self)
	run.add_child(combat)
	relics = RelicsScript.new()
	relics.setup(self)
	run.add_child(relics)
	combat.relics = relics
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
	_spawn_relics()
	hud.reset()
	hud.set_run_visible(true)
	hud.hide_boss()
	_begin_stage_director()
	am.set_intense(false)


func show_title() -> void:
	am.play("ui_click", -8.0)
	_teardown_run()
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
	settings_ui.hide_screen()
	title_screen.show_screen()



func _on_start() -> void:
	am.play("ui_click", -8.0)
	title_screen.hide_screen()
	char_select.show_screen()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE or k == KEY_P:
			if settings_ui.visible:
				_on_settings_closed()
			elif gm.state == gm.State.RUNNING:
				_on_pause_button()
			elif gm.state == gm.State.PAUSED:
				_on_resume()
		elif OS.is_debug_build() and gm.state == gm.State.RUNNING:
			_debug_key(k)
	elif event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_START:
			if gm.state == gm.State.RUNNING:
				_on_pause_button()
			elif gm.state == gm.State.PAUSED and not settings_ui.visible:
				_on_resume()


func _debug_key(k: int) -> void:
	# Debug-build hooks for exercising stage content without playing to it.
	#   F5 +30 s   F6 next event   F7 summon boss   F8 next boss phase
	#   F9 clear stage hazards     F10 print director/boss state
	match k:
		KEY_F5:
			if director:
				director.debug_advance(30.0)
		KEY_F6:
			if director:
				director.debug_trigger_event()
		KEY_F7:
			if not gm.boss_spawned:
				gm.run_time = gm.RUN_DURATION - 0.05
		KEY_F8:
			if boss and is_instance_valid(boss) and boss.controller:
				boss.controller.debug_set_phase(boss.controller.phase_idx + 1)
		KEY_F9:
			if director and director.rule:
				director.rule.clear_stage_hazards()
		KEY_F10:
			print(debug_state())


func debug_state() -> Dictionary:
	var d := {"seed": gm.run_seed, "stage": gm.stage, "time": gm.run_time,
		"hazards": get_tree().get_nodes_in_group("hazards").size(),
		"enemies": _enemy_count()}
	if director:
		d["director"] = director.debug_state()
	if boss and is_instance_valid(boss) and boss.controller:
		d["boss"] = boss.controller.debug_state()
	return d


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
	am.set_intense(false)
	if boss and is_instance_valid(boss) and boss.controller:
		boss.controller.cleanup()
	if director:
		director.cleanup()
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


func open_relic_altar(altar) -> void:
	if gm.state != gm.State.RUNNING:
		return
	var tags: PackedStringArray = altar.tags
	var opts: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = gm.stage_rule_seed(gm.stage) + 77
	for r in gm.roll_relics(tags, 3, rng):
		var rd := r as RelicData
		opts.append({"kind": "relic", "id": String(rd.id),
			"name": "%s  [%s]" % [rd.display_name, rd.rarity.to_upper()],
			"desc": rd.description})
	if opts.is_empty():
		# Every relic already held: the altar still pays out.
		opts = [{"kind": "heal", "name": "Feast of Souls", "desc": "Restore 60% of max HP."},
			{"kind": "shards", "name": "Shard Cache", "desc": "+25 soul shards, banked after the run."}]
	gm.state = gm.State.CHEST
	if player:
		player.release_joystick()
	get_tree().paused = true
	am.duck(true)
	am.play("chest_open", -4.0)
	if gm.run_stats:
		gm.run_stats.add_pickup("altars")
	loot_ui.show_screen(opts, "RELIC ALTAR", "a relic for the road")
	altar.queue_free()


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
		"relic":
			if relics:
				relics.add(str(choice["id"]))
				hud.show_warning(str(choice["name"]).get_slice("  [", 0).to_upper())



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
	end_screen.show_screen(victory, gm.run_time, gm.kills, gm.level, gm.last_banked, gm.run_stats)


func _on_settings_open() -> void:
	am.play("ui_click", -8.0)
	settings_ui.show_screen()


func _on_settings_closed() -> void:
	am.play("ui_click", -8.0)
	settings_ui.hide_screen()
	_apply_effect_settings()
	if gm.state == gm.State.PAUSED:
		pause_menu.show_screen()


func _apply_effect_settings() -> void:
	if _ash:
		_ash.emitting = not bool(gm.setting("reduced_effects"))
		_ash.visible = _ash.emitting


func _on_upgrades_open() -> void:
	am.play("ui_click", -8.0)
	am.duck(true)
	title_screen.hide_screen()
	upgrades_ui.show_screen()


func _on_weapons_open() -> void:
	am.play("ui_click", -8.0)
	title_screen.hide_screen()
	weapons_ui.show_screen()


func _on_weapons_closed() -> void:
	am.play("ui_click", -8.0)
	weapons_ui.hide_screen()
	title_screen.show_screen()


func _on_upgrades_closed() -> void:
	am.play("ui_click", -8.0)
	am.duck(false)
	upgrades_ui.hide_screen()
	title_screen.show_screen()



func _apply_stage_theme() -> void:
	var sd: Dictionary = gm.stage_data()
	if ground and ground.has_method("set_theme"):
		ground.call("set_theme", str(sd["theme"]))
	var stage_def: StageData = gm.stage_def()
	var fog_tint: Color = stage_def.fog_tint if stage_def else Color(0.35, 0.45, 0.65)
	if fog_a:
		fog_a.set("fog_color", Color(fog_tint, 0.05))
	if fog_b:
		fog_b.set("fog_color", Color(fog_tint, 0.05))
	hud.set_stage(gm.stage, str(sd["name"]))



func _advance_stage() -> void:
	# Stages can be entered at any point, so walk forward through the list and
	# wrap rather than running off the end.
	gm.stage = (gm.stage + 1) % gm.STAGES.size()
	gm.run_time = 0.0
	gm.boss_spawned = false
	gm.boss_alive = false
	boss = null
	warned = false
	_elite_idx = 0
	intermission = 5.0
	hud.hide_boss()
	if director and is_instance_valid(director):
		director.cleanup()
		director.queue_free()
	director = null
	_corpses.clear()
	for e in get_tree().get_nodes_in_group("hostiles"):
		if e.is_in_group("enemies"):
			jm.gold_burst(e.global_position)
		e.queue_free()
	for group in ["gems", "shards", "relics", "hazards", "stage_objects", "boss_objects",
			"pillars", "relic_altars", "fallen_banners", "objectives"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()
	if player:
		player.heal(99999.0)
		player.set("push", Vector2.ZERO)
	_apply_stage_theme()
	_spawn_relics()
	var sd: Dictionary = gm.stage_data()
	hud.show_warning("STAGE %d — %s" % [gm.stage + 1, str(sd["name"])])
	am.play("victory_sting", -6.0)
	_begin_stage_director()
	_spawn_relic_altar()


func _begin_stage_director() -> void:
	director = DirectorScript.new()
	run.add_child(director)
	director.setup(self, gm.stage)
	var sd: StageData = gm.stage_def()
	if gm.run_stats:
		gm.run_stats.begin_stage(gm.stage, sd.display_name if sd else "")
	hud.show_card(sd.display_name if sd else "", director.intro_text())


func _spawn_relic_altar() -> void:
	# The reward for the boss just beaten waits at the start of the next
	# stage: walking to it is the choice, so the run never stalls on a menu.
	if player == null or gm.stages_cleared <= 0:
		return
	var prev: StageData = gm.CONTENT.stage_at((gm.stage - 1 + gm.STAGES.size()) % gm.STAGES.size())
	var a = AltarScript.new()
	a.position = clamp_arena(player.global_position + Vector2(0, -200))
	a.tags = prev.relic_tags if prev else PackedStringArray()
	run.add_child(a)


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
	if director and is_instance_valid(director):
		director.tick(delta)
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


func count_alive(etype: String) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("hostiles"):
		if String(e.etype) == etype and not e.dead:
			n += 1
	return n


func clamp_arena(v: Vector2, margin := 0.0) -> Vector2:
	var a := ARENA - margin
	return Vector2(clampf(v.x, -a, a), clampf(v.y, -a, a))


func add_hazard_node(h: Node2D) -> Node2D:
	# Every TimedHazard enters the world here, under the shared cap.
	_cap_group("hazards", MAX_HAZARDS)
	run.add_child(h)
	return h


func claim_corpse(pos: Vector2, reach: float) -> Variant:
	# Hands a necromancer the nearest unused recent corpse, once.
	var now: float = gm.run_time
	var best: Variant = null
	var bd := reach
	for c in _corpses:
		if c["used"] or now - float(c["t"]) > 8.0:
			continue
		var d := pos.distance_to(c["pos"])
		if d < bd:
			bd = d
			best = c
	if best != null:
		best["used"] = true
	return best



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
	hud.show_warning("%s ELITE APPROACHES" % e.AFFIX_NAMES.get(e.affix, ""))
	am.play("elite_horn", -4.0)
	jm.add_trauma(0.25)
	jm.gold_burst(e.global_position)


func _spawn_enemy(etype: String, pos: Vector2):
	var t: float = gm.run_time
	# Per-stage scaling was tuned for three stages; across eight the old 0.8 per
	# stage reached 6.6x health by the last, which is unplayable as an opening
	# stage now that any of them can be picked from the title screen.
	var hp_m: float = gm.enemy_hp_mult(gm.stage, t)
	var dmg_m: float = gm.enemy_dmg_mult(gm.stage, t)
	var e = EnemyScript.new()
	e.setup(etype, pos, hp_m, dmg_m)
	e.died.connect(_on_enemy_died.bind(e))
	run.add_child(e)
	return e


func spawn_hazard(mode: String, pos: Vector2, dmg: float, col: Color) -> Node2D:
	_cap_group("hazards", MAX_HAZARDS)
	var h = HazardScript.new()
	h.setup(mode, pos, dmg, col)
	run.add_child(h)
	return h


func spawn_split(etype: String, pos: Vector2, hp_val: float, dmg_val: float):
	# A splitting elite's offspring: fixed stats taken from the parent rather
	# than the run's scaling curve, so a late-stage split does not come back
	# stronger than the elite that died to make it.
	if _enemy_count() >= MAX_ENEMIES:
		return null
	var p := Vector2(clampf(pos.x, -ARENA, ARENA), clampf(pos.y, -ARENA, ARENA))
	var e = EnemyScript.new()
	e.setup(etype, p, 1.0, 1.0)
	e.max_hp = maxf(1.0, hp_val)
	e.hp = e.max_hp
	e.dmg = dmg_val * 0.6
	e.scale = Vector2(0.85, 0.85)
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
	var bd: BossData = gm.stage_def().boss_data() if gm.stage_def() else null
	var e = _spawn_enemy(str(sd["boss"]), _ring_pos())
	boss = e
	if bd != null:
		e.max_hp *= bd.hp_mult
		e.hp = e.max_hp
		e.tint = bd.tint
		if not bd.legacy:
			var ctl = ControllerScript.new()
			e.add_child(ctl)
			e.controller = ctl
			ctl.setup(e, bd, self)
			if bd.intro_text != "":
				var t := get_tree().create_timer(2.4)
				t.timeout.connect(func():
					if hud and is_instance_valid(hud) and gm.boss_alive:
						hud.show_warning(bd.intro_text.to_upper()))
	if director and is_instance_valid(director):
		director.on_boss(e)
	if gm.run_stats:
		gm.run_stats.boss_spawned(gm.run_time)
	am.play("boss_warning_horn", -2.0)
	am.play("boss_roar", -4.0, 0.9)
	lm.attach_aura(e, sd["boss_aura"], 3.6, 1.0)
	jm.add_trauma(0.55)
	jm.hit_stop(0.06)
	hud.show_boss(str(sd["boss_name"]))
	hud.update_boss(e.hp, e.max_hp)
	hud.show_warning(str(sd["boss_name"]) + " RISES")
	am.set_intense(true)


func _on_enemy_died(e) -> void:
	if gm.run_stats:
		gm.run_stats.add_kill(str(e.etype), bool(e.get("is_elite")), e.is_boss())
	if director and is_instance_valid(director):
		director.on_enemy_died(e)
	if not e.is_boss() and not bool(e.no_credit):
		_corpses.append({"pos": e.global_position, "t": gm.run_time, "used": false})
		if _corpses.size() > MAX_CORPSES:
			_corpses.remove_at(0)
	# Raised dead and boss props are not kills: no count, no siphon.
	if bool(e.no_credit) or bool(e.revived):
		return
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
		am.set_intense(false)
		var aura_c: Color = gm.stage_data()["boss_aura"]
		jm.add_trauma(0.7)
		jm.hit_stop(0.08)
		jm.shockwave(e.global_position, aura_c, 260.0)
		lm.flash(e.global_position, aura_c, 2.6, 4.5, 0.5)

		var drops: int = 5 + 3 * int(gm.stage)
		for i in drops:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0)
			spawn_shard(e.global_position + off, 5)
		gm.stages_cleared += 1
		if gm.run_stats:
			gm.run_stats.stage_cleared(gm.run_time)
		var bd: BossData = gm.stage_def().boss_data() if gm.stage_def() else null
		if bd and bd.defeat_text != "":
			hud.show_warning(bd.defeat_text)
		var stage_id := String(gm.stage_def().id) if gm.stage_def() else ""
		var found: Array = gm.discover_stage_relics(stage_id)
		for rid in found:
			var rd: RelicData = gm.CONTENT.relic(rid)
			_announce_unlocks(["RELIC: " + rd.display_name])
		if stage_id == "last_bastion":
			_crown_campaign()
		if director and is_instance_valid(director):
			director.cleanup()
		# Campaign progress is banked the moment the stage falls, not at the end
		# of the run: dying in stage 5 should not cost the player stages 1-4.
		var freshly: Array = gm.clear_campaign_stage(gm.stage)
		if not freshly.is_empty():
			_announce_unlocks(freshly)
		if gm.stages_cleared >= gm.stages_in_run():
			gm.end_run(true)
		else:
			_advance_stage()


# Cell must be at least the largest possible sum of two body radii (the Cinder
# King is 56, so 112) for a 3x3 neighbour sweep to catch every overlapping pair.
const SEP_CELL := 128.0
const SEP_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1),
]


func _spawn_relics() -> void:
	gm.begin_stage_relics(gm.stage)
	if gm.relic_weapon == "":
		return
	var w: Dictionary = gm.WEAPONS.get(gm.relic_weapon, {})
	var wname := str(w.get("name", gm.relic_weapon))
	for i in gm.RELICS_PER_STAGE:
		var r = RelicScript.new()
		r.weapon_id = gm.relic_weapon
		r.tint = gm.stage_data()["boss_aura"]
		# Well away from the spawn point: these are meant to be searched for.
		var a := randf() * TAU
		r.position = Vector2.from_angle(a) * randf_range(620.0, 1380.0)
		r.collected.connect(_on_relic_collected)
		run.add_child(r)
	_announce_relics(wname)


func _crown_campaign() -> void:
	# The last throne's reward is recognition, not power: a crown marker on
	# the title screen, a large shard payout, and its legendary relic now in
	# the altar pool (discovered just above).
	if not gm.campaign:
		return
	gm.add_shards(100)
	if not gm.campaign_crowned:
		gm.campaign_crowned = true
		gm.save_meta()
		_announce_unlocks(["THE CAMPAIGN IS WON"])


func _announce_unlocks(names: Array) -> void:
	# One banner per character, staggered, so unlocking two at once does not
	# overwrite the first before it has been read.
	var delay := 0.0
	for n in names:
		var t := get_tree().create_timer(delay)
		t.timeout.connect(func():
			if hud and is_instance_valid(hud):
				hud.show_warning("%s UNLOCKED" % str(n).to_upper()))
		delay += 2.2


func _announce_relics(wname: String) -> void:
	# Let the stage banner land first, then say what is hidden here.
	await get_tree().create_timer(2.4).timeout
	if gm.state == gm.State.RUNNING and hud:
		hud.show_warning("%s RELICS HIDDEN HERE" % wname.to_upper())


func _on_relic_collected() -> void:
	am.play("shard_pickup", -2.0)
	jm.add_trauma(0.25)
	var unlocked_id: String = gm.collect_relic()
	if unlocked_id != "":
		am.play("levelup_chime", -4.0)
		jm.hit_stop(0.08)
		hud.show_warning("%s UNLOCKED" % str(gm.class_by_id(unlocked_id)["name"]).to_upper())
	else:
		hud.show_warning("RELIC %d / %d" % [gm.relics_found, gm.RELICS_PER_STAGE])


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


func _cap_group(group: String, limit: int) -> void:
	var list := get_tree().get_nodes_in_group(group)
	var over := list.size() - limit
	var i := 0
	while over > 0 and i < list.size():
		var n = list[i]
		if is_instance_valid(n):
			# queue_free() only takes effect at the end of the frame, so the
			# group would still report the old size and the cap would do
			# nothing during a burst -- which is exactly when it is needed.
			# Leaving the group is immediate.
			n.remove_from_group(group)
			n.queue_free()
			over -= 1
		i += 1


func spawn_gem(pos: Vector2, value: int) -> void:
	_cap_group("gems", MAX_PICKUPS)
	var g = GemScript.new()
	g.value = value
	g.position = pos
	run.add_child(g)


func spawn_shard(pos: Vector2, value: int) -> void:
	_cap_group("shards", MAX_PICKUPS)
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
	if not bool(gm.setting("damage_numbers")):
		return
	if get_tree().get_nodes_in_group("dmgnums").size() > (20 if bool(gm.setting("reduced_effects")) else 40):
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
