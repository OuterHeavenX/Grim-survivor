extends Node
# Companions, stage layouts, missions, surges and the deeper meta tracks.
# Restores the save file afterwards.

const SAVE := "user://grim_survivors.cfg"

var _fails := 0
var _gm = null
var _main = null
var _p = null
var _save_backup := ""


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		print("FAIL: ", name)


func _frames(n: int) -> void:
	# Kills earn XP and a level-up pauses the run; these checks are about
	# missions and companions, so any level-up is waved through.
	for i in n:
		if _gm.state == _gm.State.LEVELUP:
			_main.levelup_ui.hide_screen()
			_gm.pending_levelups = 0
			get_tree().paused = false
			_gm.state = _gm.State.RUNNING
		await get_tree().physics_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_gm = get_node("/root/GameManager")
	_main = get_tree().get_first_node_in_group("main")
	if FileAccess.file_exists(SAVE):
		_save_backup = FileAccess.get_file_as_string(SAVE)
	await _meta()
	await _layouts()
	await _companions()
	await _missions()
	_main.show_title()
	_check(get_tree().get_nodes_in_group("companions").is_empty(), "title: no companions left")
	_check(_gm.mods.sources().is_empty(), "title: meta modifiers cleared with the run")
	if _save_backup != "":
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_string(_save_backup)
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("PACTS TEST DONE fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _start(stage: int) -> void:
	_gm.selected_stage = stage
	_gm.daily = false
	_main.start_run()
	await _frames(3)
	_main.intermission = 99999.0
	_p = _main.player
	_p.max_hp = 1000000.0
	_p.hp = _p.max_hp


func _clear() -> void:
	for e in get_tree().get_nodes_in_group("hostiles"):
		e.queue_free()
	await _frames(1)


# --- meta progression ----------------------------------------------------------

func _meta() -> void:
	_check(_gm.track_max("edge") == 10 and _gm.track_max("wind") == 5, "meta: ascended tracks reach 10, revives stay at 5")
	_check(_gm.META_TRACKS.size() == 14, "meta: fourteen tracks")
	var saved_meta: Dictionary = _gm.meta.duplicate()
	var saved_shards: int = _gm.shards
	_gm.shards = 100000
	for i in 10:
		_gm.buy_track("edge")
	_check(_gm.meta_rank("edge") == 10 and _gm.track_cost("edge") < 0, "meta: edge buys to rank 10 then stops")
	_check(is_equal_approx(_gm.meta_damage_mult(), 1.6 * _gm.class_damage_mult()), "meta: rank 10 edge is +60% damage")
	_gm.meta["bulwark"] = 4
	_gm.meta["haste"] = 2
	_gm.meta["renewal"] = 3
	_gm.meta["fate"] = 2
	_gm.meta["tithe"] = 5
	await _start(0)
	_check(is_equal_approx(_gm.mods.mult("damage_taken"), 0.88), "meta: bulwark cuts damage taken at run start")
	_check(is_equal_approx(_gm.mods.mult("cooldown"), 0.94), "meta: quickened hands shortens cooldowns")
	_check(is_equal_approx(_gm.mods.add("regen"), 0.9), "meta: renewal regenerates")
	_check(_gm.rerolls_left == 2, "meta: fate's thread grants rerolls")
	_gm.run_shards = 20
	var before: int = _gm.shards
	_gm.bank_run_shards()
	_check(_gm.shards - before == 30, "meta: soul tithe adds 50% at rank 5")
	_check(_gm.track_bonus_text("renewal").contains("0.9"), "meta: fractional bonus text formats")
	# Reroll on the level-up screen.
	_gm.pending_levelups = 1
	_main._on_level_changed()
	await _frames(1)
	_check(_main.levelup_ui.reroll_btn.visible, "levelup: reroll offered")
	_main.levelup_ui._on_reroll()
	_check(_gm.rerolls_left == 1 and _main.levelup_ui.buttons.size() == 3, "levelup: reroll spends one and redeals")
	_main.levelup_ui._on_pick({"kind": "pact", "id": "pact", "to": 1})
	await _frames(1)
	_check(_gm.pact_level == 1, "levelup: a pact card raises the pact")
	_gm.meta = saved_meta
	_gm.shards = saved_shards
	# New achievements and sigils read new lifetime counters.
	var ach_ids: Array = _gm.ACHIEVEMENTS.map(func(a): return str(a["id"]))
	for id in ["pactbound", "oathkeeper", "thief_taker", "surge_breaker", "ascendant", "legion"]:
		_check(ach_ids.has(id), "achievements: %s exists" % id)
	var m0: int = _gm.lifetime_missions
	_gm.lifetime_missions = 10
	_check(_gm.achievement_value("missions") == 10, "achievements: missions counted")
	_gm.lifetime_missions = m0
	_main.show_title()


# --- layouts --------------------------------------------------------------------

func _layouts() -> void:
	for i in _gm.STAGES.size():
		await _start(i)
		var sd: StageData = _gm.stage_def()
		var spec: Dictionary = StageLayout.spec(String(sd.id))
		var half: Vector2 = spec["half"]
		var key := String(sd.id)
		_check(_gm.arena_half == half, "%s: arena takes the layout's bounds" % key)
		_check(not _main.director.blocked(Vector2.ZERO, 120.0), "%s: the start is clear" % key)
		var inside := true
		for o in _main.director.static_obstacles:
			for pt in [o["pos"], o.get("to", o["pos"])]:
				if absf(pt.x) > half.x or absf(pt.y) > half.y:
					inside = false
		_check(inside, "%s: every ruin stands inside the arena" % key)
		_p.global_position = half * 3.0
		await _frames(2)
		_check(absf(_p.global_position.x) <= half.x + 0.5 and absf(_p.global_position.y) <= half.y + 0.5, "%s: the player is held inside" % key)
		_p.global_position = Vector2.ZERO
	# A wall pushes bodies out and enemies slide along it.
	await _start(0)
	var d = _main.director
	var probe := Vector2(-300, -560)
	_check(d.blocked(probe, 16.0), "keep: the north wall blocks")
	var e = _main._spawn_enemy("skeleton", Vector2(-300, -620))
	_p.global_position = Vector2(-300, -300)
	await _frames(40)
	_check(is_instance_valid(e) and e.global_position.distance_to(Vector2(-300, -620)) > 60.0, "keep: a blocked enemy slides along the wall")
	_main.show_title()


# --- companions -----------------------------------------------------------------

func _companions() -> void:
	_check(_gm.is_companion_unlocked("hound"), "companions: the hound is free")
	var saved_ach: Dictionary = _gm.achievements.duplicate()
	var saved_owned: Dictionary = _gm.companions_unlocked.duplicate()
	var saved_shards: int = _gm.shards
	_gm.achievements.erase("oathkeeper")
	_gm.companions_unlocked = {"hound": true}
	_check(not _gm.is_companion_unlocked("archer"), "companions: archer starts locked")
	_gm.shards = 10
	_check(not _gm.unlock_companion("archer"), "companions: archer needs its price")
	_gm.shards = 500
	_check(_gm.unlock_companion("archer") and _gm.shards == 350, "companions: archer bought for 150")
	_check(not _gm.unlock_companion("wisp"), "companions: wisp cannot be bought")
	_gm.achievements["oathkeeper"] = true
	_check(_gm.is_companion_unlocked("wisp"), "companions: wisp opens with OATHKEEPER")
	_check(not _gm.select_companion("missing"), "companions: unknown id rejected")

	for kind in ["hound", "archer", "wisp", "knight"]:
		_gm.achievements["first_victory"] = true
		_gm.select_companion(kind)
		await _start(0)
		_gm.weapons = {}
		_gm.weapons_changed.emit()
		var ab = _main.summon
		_check(ab != null and not ab.is_ready(), "%s: summon starts on a short cooldown" % kind)
		ab.cooldown_left = 0.0
		var s0: int = _gm.lifetime_summons
		_check(ab.try_summon(), "%s: summon answers when ready" % kind)
		_check(get_tree().get_nodes_in_group("companions").size() == 1 and _gm.lifetime_summons == s0 + 1, "%s: one companion, counted" % kind)
		_check(not ab.try_summon(), "%s: cannot summon again on cooldown" % kind)
		var foe = _main._spawn_enemy("titan", _p.global_position + Vector2(90, 0))
		foe.max_hp = 100000.0
		foe.hp = foe.max_hp
		foe.speed = 0.0
		await _frames(150)
		_check(is_instance_valid(foe) and foe.hp < foe.max_hp, "%s: the companion deals damage" % kind)
		if kind == "knight":
			_check(is_instance_valid(foe) and foe.lure != null, "knight: lures nearby foes")
		var comp = get_tree().get_nodes_in_group("companions")[0]
		comp.life = 0.01
		await _frames(3)
		_check(get_tree().get_nodes_in_group("companions").is_empty(), "%s: the companion leaves when its time runs out" % kind)
		if kind == "knight":
			_check(not is_instance_valid(foe) or foe.lure == null, "knight: the lure is released on leaving")
		await _clear()
	# Full pact: two answer.
	_gm.pact_level = _gm.PACT_MAX
	_main.summon.cooldown_left = 0.0
	_main.summon.try_summon()
	_check(get_tree().get_nodes_in_group("companions").size() == 2, "pact: full pact summons two")
	_check(_gm.companion_duration() > _gm.BASE_COMPANION_DURATION and _gm.companion_cooldown() < _gm.BASE_COMPANION_COOLDOWN, "pact: longer and quicker")
	_gm.achievements = saved_ach
	_gm.companions_unlocked = saved_owned
	_gm.shards = saved_shards
	_gm.select_companion("hound")
	_main.show_title()


# --- missions and surges -----------------------------------------------------

func _missions() -> void:
	await _start(1)
	var md = _main.director.missions
	_check(md != null, "missions: every stage has a mission director")
	_gm.run_time = 31.0
	md.tick(0.016, 31.0)
	_check(not md.current.is_empty(), "missions: one is offered after 30 s")
	md._finish(md.current.get("obj"), false)

	# Cull: kills fill it.
	var m: Dictionary = md.start("cull")
	var obj = m["obj"]
	await _frames(1)
	var goal := int(obj.goal)
	var k0: int = _gm.lifetime_missions
	for i in goal:
		md.on_enemy_died(null)
	await _frames(2)
	_check(md.current.is_empty() and _gm.lifetime_missions == k0 + 1, "cull: enough kills complete it")
	await _clear()

	# Thief: killing it pays and counts; escaping fails.
	m = md.start("thief")
	var thief = m["target"]
	_check(thief != null and thief.etype == "soul_thief", "thief: a soul thief appears")
	var th0: int = _gm.lifetime_thieves
	var p0: Vector2 = _p.global_position
	await _frames(30)
	_check(thief.global_position.distance_to(p0) > 380.0, "thief: it runs from the player")
	thief.take_damage(99999.0, thief.global_position, 0.0, "dagger")
	await _frames(3)
	_check(_gm.lifetime_thieves == th0 + 1 and md.current.is_empty(), "thief: caught, counted and closed")
	_check(not get_tree().get_nodes_in_group("chests").is_empty(), "thief: drops a chest")
	m = md.start("thief")
	m["obj"].elapsed = m["obj"].time_limit
	await _frames(3)
	_check(md.current.is_empty() and not is_instance_valid(m["target"]), "thief: escapes when time runs out")
	await _clear()

	# Marked: only the marked one counts.
	m = md.start("marked")
	var mk = m["target"]
	_check(mk != null and mk.is_elite and mk.has_meta("marked"), "marked: an elite carries the mark")
	var other = _main._spawn_enemy("skeleton", _p.global_position + Vector2(300, 0))
	other.take_damage(99999.0, other.global_position, 0.0, "dagger")
	await _frames(2)
	_check(not md.current.is_empty(), "marked: other kills do not count")
	# A warded elite's shield eats the first blow whole.
	for i in 3:
		if is_instance_valid(mk) and not mk.dead:
			mk.take_damage(999999.0, mk.global_position, 0.0, "dagger")
	await _frames(3)
	_check(md.current.is_empty(), "marked: killing the mark completes it")
	await _clear()

	# Totems: cleanse three.
	m = md.start("totems")
	await _frames(1)
	var totems := get_tree().get_nodes_in_group("mission_totems")
	_check(totems.size() == 3, "totems: three stand")
	for t in totems:
		_p.global_position = t.global_position
		await _frames(int(ceil(t.CHANNEL * 60.0)) + 6)
	await _frames(2)
	_check(md.current.is_empty() and get_tree().get_nodes_in_group("mission_totems").is_empty(), "totems: cleansing all three completes it")
	await _clear()

	# Hold: standing in the zone fills it; time limits fail it.
	m = md.start("hold")
	obj = m["obj"]
	_p.global_position = obj.global_position
	await _frames(int(obj.goal * 60.0) + 30)
	_check(md.current.is_empty(), "hold: holding the shrine completes it")
	m = md.start("hold")
	_p.global_position = m["obj"].global_position + Vector2(900, 0)
	m["obj"].elapsed = m["obj"].time_limit - 0.02
	await _frames(4)
	_check(md.current.is_empty() and md.failed >= 1, "hold: the time limit fails it")
	await _clear()

	# Boss: missions stop.
	md.start("cull")
	md.on_boss()
	_check(md.current.is_empty() and not md.enabled, "missions: the boss ends and stops them")

	# Surges.
	await _start(0)
	md = _main.director.missions
	var n0: int = _main._enemy_count()
	md.start_surge(80.0)
	await _frames(1)
	_check(md.is_surging() and _main._enemy_count() > n0 + 10, "surge: a ring of foes arrives")
	var s0: int = _gm.lifetime_surges
	md.surge_left = 0.01
	md.tick(0.05, 81.0)
	_check(not md.is_surging() and _gm.lifetime_surges == s0 + 1, "surge: outlasting it counts")
	_check(_main._enemy_count() <= _main.MAX_ENEMIES, "surge: respects the enemy cap")
