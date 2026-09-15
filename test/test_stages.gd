extends Node


var _phase := 0
var _wait := 0
var _fails := 0
var _aged_gem = null
var _main = null
var _gm = null
var _player = null
var _w = null


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		print("FAIL: ", name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_main = get_tree().get_first_node_in_group("main")
	_gm = get_node("/root/GameManager")
	# A run is now as many stages as the chosen length allows, so ask for a long
	# one: these phases walk through several stages before expecting a victory.
	_gm.selected_minutes = 30
	_check(_main != null, "main found")
	_main.start_run()
	set_process(true)


func _process(_delta: float) -> void:
	_wait += 1
	match _phase:
		0:
			if _wait > 5:
				_player = _main.player
				_w = _player.get_node("Weapons")
				_check(_gm.EVOLUTIONS.size() == 13, "13 evolutions defined")
				for id in _gm.WEAPONS:
					_check(_gm.EVOLUTIONS.has(id), "evolution for " + id)
					var req: String = str(_gm.EVOLUTIONS[id]["passive"])
					_check(_gm.PASSIVES.has(req), "evo passive valid: " + req)
				_check(_gm.STAGES.size() == 8, "8 stages defined")

				# Relic unlocks: every class has its own weapon, and the pair
				# hidden in a stage unlocks whoever wields it.
				var ws := {}
				for c in _gm.CHAR_CLASSES:
					ws[str(c["weapon"])] = true
				_check(ws.size() == _gm.CHAR_CLASSES.size(), "every class has a unique weapon")
				_check(_gm.CHAR_CLASSES.size() == _gm.WEAPONS.size(),
					"one class per weapon")

				# --- campaign mode ---------------------------------------
				# These mutate saved progress, and every suite shares the same
				# user:// config, so the original state is snapshotted here and
				# put back before the phase ends. Without that, running the
				# suite twice would have the second run start from whatever
				# this phase happened to unlock.
				var snap_unlocked: Dictionary = _gm.unlocked.duplicate()
				var snap_shards: int = _gm.shards
				var snap_unlocked_n: int = _gm.campaign_unlocked
				var snap_mode: bool = _gm.campaign

				_gm.campaign = false
				var all_open := true
				for i in _gm.STAGES.size():
					if not _gm.campaign_stage_open(i):
						all_open = false
				_check(all_open, "free play leaves every stage open")
				_check(_gm.clear_campaign_stage(0).is_empty(),
					"free play does not bank campaign progress")

				_gm.campaign = true
				_gm.campaign_unlocked = 1
				_gm.unlocked = {"rogue": 1}
				_check(_gm.campaign_stage_open(0), "campaign opens at stage 1")
				_check(not _gm.campaign_stage_open(1), "campaign gates stage 2")
				_check(not _gm.campaign_stage_open(7), "campaign gates the last stage")

				# Clearing a stage opens the next one and hands over the
				# characters whose weapons are that stage's relics.
				var got: Array = _gm.clear_campaign_stage(0)
				_check(_gm.campaign_unlocked == 2, "clearing stage 1 opens stage 2")
				_check(_gm.campaign_stage_open(1), "stage 2 is now open")
				var want0: Array = []
				for c in _gm.chars_for_stage(0):
					want0.append(str(c["name"]))
				_check(got.size() == want0.size() and got.size() > 0,
					"stage 1 unlocked %d character(s)" % got.size())
				for c in _gm.chars_for_stage(0):
					_check(_gm.is_class_unlocked(str(c["id"])),
						"campaign unlocked " + str(c["id"]))
				_check(_gm.shards > snap_shards, "clearing a stage pays shards")

				# Re-clearing an already-cleared stage must not push the
				# frontier forward again.
				var before_n: int = _gm.campaign_unlocked
				var again: Array = _gm.clear_campaign_stage(0)
				_check(_gm.campaign_unlocked == before_n,
					"re-clearing stage 1 does not advance the frontier")
				_check(again.is_empty(),
					"re-clearing announces nothing already owned")

				# Clearing out of order cannot move the frontier backwards.
				# campaign_unlocked counts open stages, so clearing index 4
				# (the fifth stage) opens index 5 and leaves six open.
				_gm.clear_campaign_stage(4)
				_check(_gm.campaign_unlocked == 6, "clearing stage 5 opens stage 6")
				_gm.clear_campaign_stage(0)
				_check(_gm.campaign_unlocked == 6, "frontier never moves backwards")

				# The campaign is a complete path to every character: stages
				# 1-6 between them cover all twelve non-starter classes, so
				# nothing is left depending on relic luck.
				_gm.unlocked = {"rogue": 1}
				_gm.campaign_unlocked = 1
				for i in _gm.STAGES.size():
					_gm.clear_campaign_stage(i)
				var missing: Array = []
				for c in _gm.CHAR_CLASSES:
					if not _gm.is_class_unlocked(str(c["id"])):
						missing.append(str(c["id"]))
				_check(missing.is_empty(),
					"finishing the campaign unlocks every class, missing %s" % str(missing))
				_check(_gm.campaign_unlocked == _gm.STAGES.size(),
					"campaign frontier stops at the last stage")

				# Progress survives a save/load round trip.
				_gm.campaign_unlocked = 4
				_gm.save_meta()
				_gm.campaign_unlocked = 1
				_gm.load_meta()
				_check(_gm.campaign_unlocked == 4, "campaign progress persists")

				_gm.unlocked = snap_unlocked
				_gm.shards = snap_shards
				_gm.campaign_unlocked = snap_unlocked_n
				_gm.campaign = snap_mode
				_gm.save_meta()
				_check(not _gm.campaign, "campaign state restored for later suites")

				_gm.unlocked = {"rogue": 1}
				_gm.begin_stage_relics(1)
				_check(_gm.relic_weapon == "sdagger", "stage 2 hides shadow dagger relics")
				_check(_gm.collect_relic() == "", "one relic is not enough")
				_check(_gm.collect_relic() == "shadow", "the pair unlocks the Shadowblade")
				_check(_gm.is_class_unlocked("shadow"), "the unlock sticks")
				_gm.begin_stage_relics(1)
				_check(_gm.relic_weapon == "miasma",
					"a stage moves on once its first relic class is unlocked")
				_check(not _gm.unlock_class("flame"), "relic classes cannot be bought")

				# Pickups must not accumulate for the whole run: uncollected
				# gems used to live forever, so a long session piled up
				# thousands, each still running physics and redrawing.
				var GemS := load("res://src/gem.gd")
				_check(GemS.LIFETIME > 0.0, "gems have a lifetime")
				var before := get_tree().get_nodes_in_group("gems").size()
				for i in _main.MAX_PICKUPS + 25:
					_main.spawn_gem(Vector2(9000, 9000), 1)
				_check(get_tree().get_nodes_in_group("gems").size() <= _main.MAX_PICKUPS + 1,
					"gem count is capped, got %d" % get_tree().get_nodes_in_group("gems").size())

				# ...and one past its life frees itself rather than lingering.
				var g = GemS.new()
				g.position = Vector2(9000, -9000)
				g.value = 1
				_main.run.add_child(g)
				g.set("_age", GemS.LIFETIME + 1.0)
				_aged_gem = g
				for sd in _gm.STAGES:
					var pool: Array = sd["pool"]
					_check(pool.size() == 3, "stage pool x3: " + str(sd["name"]))
					_check(str(sd["boss_name"]).length() > 5, "boss name: " + str(sd["boss_name"]))
					_check(sd["boss_aura"] is Color, "boss aura color")
				_phase = 1
				_wait = 0
		1:
			if _wait > 3:

				_gm.weapons = {"dagger": 5}
				_gm.passives = {}
				var ch = _gm.roll_upgrades(3)
				var has_evo := false
				for c in ch:
					if str(c["kind"]) == "evolve":
						has_evo = true
				_check(not has_evo, "no evolve without paired passive")
				_gm.passives = {"might": 1}
				ch = _gm.roll_upgrades(3)
				var evo_ch = null
				for c in ch:
					if str(c["kind"]) == "evolve" and str(c["id"]) == "dagger":
						evo_ch = c
				_check(evo_ch != null, "evolve dagger offered with might")
				_check(str(_gm.EVOLUTIONS["dagger"]["name"]) == "Fang Barrage", "evo name")
				_gm.apply_upgrade(evo_ch)
				_check(_gm.is_evolved("dagger"), "dagger evolved after apply")
				ch = _gm.roll_upgrades(3)
				has_evo = false
				for c in ch:
					if str(c["kind"]) == "evolve" and str(c["id"]) == "dagger":
						has_evo = true
				_check(not has_evo, "no double evolve offer")
				_phase = 2
				_wait = 0
		2:
			if _wait > 3:

				_gm.weapons = {"dagger": 5}
				_gm.evolved = {"dagger": true}
				_gm.weapons_changed.emit()
				_w.timers["dagger"] = 999.0
				var foe = _main._spawn_enemy("skeleton", _player.global_position + Vector2(300, 0))
				_w._fire_dagger(5)
				var fangs := 0
				var evo_flag := false
				for p in _main.run.get_children():
					if p is Node2D and str(p.get("mode")) == "dagger":
						fangs += 1
						evo_flag = evo_flag or bool(p.get("evo"))
				_check(fangs == 5, "evolved dagger fires 5 fangs, got %d" % fangs)
				_check(evo_flag, "evo flag set on projectiles")


				_gm.weapons["blades"] = 5
				_gm.weapons_changed.emit()
				var blades0 = _player.get_node("Blades").get_child_count()
				_gm.evolved["blades"] = true
				_gm.weapons_changed.emit()
				var blades1 = _player.get_node("Blades").get_child_count()
				_check(blades1 == blades0 + 3, "evolved blades +3 orbiters")
				foe.queue_free()
				_phase = 3
				_wait = 0
		3:
			if _wait > 3:

				_gm.stage = 1
				_gm.boss_spawned = false
				_main._apply_stage_theme()
				_check(str(_gm.stage_data()["boss"]) == "maw", "stage 2 boss is maw")
				var tbase: Color = _main.ground.get("theme")["base"]
				_check(tbase.g > 0.04, "marsh theme applied to ground")
				_main._spawn_boss()
				_check(_main.boss != null and str(_main.boss.get("etype")) == "maw", "maw spawned")
				_check(_gm.boss_alive, "boss_alive set")
				# Hold the maw alive: the next phases drive its attack pattern.
				_phase = 4
				_wait = 0
		4:
			if _wait > 3:
				# Bosses used to just walk at the player and summon skeletons.
				# Each one now telegraphs a signature move, so check the maw
				# paints its charge lane before committing to it.
				var b = _main.boss
				b.set("_cast_phase", 0)
				b.set("_cast_t", 0.0)
				_phase = 5
				_wait = 0
		5:
			if _wait > 4:
				var b = _main.boss
				var lanes := 0
				for h in get_tree().get_nodes_in_group("hazards"):
					if str(h.get("mode")) == "lane":
						lanes += 1
				_check(lanes >= 1, "maw telegraphs its charge lane, got %d" % lanes)
				_check(int(b.get("_cast_phase")) == 1, "maw is in wind-up")

				# Commit: the lunge rides _kb, which must survive the frame it
				# starts on rather than being damped away like a knockback.
				b.set("_cast_t", 0.0)
				b.set("_kb", Vector2.ZERO)
				b._commit()
				_check(b.get("_kb").length() > 500.0, "maw charge carries real speed")

				# The herald fires a ring, not a single shot.
				var herald = _main._spawn_enemy("herald", Vector2(700, 0))
				herald._commit()
				var bolts := 0
				for h in get_tree().get_nodes_in_group("hazards"):
					if str(h.get("mode")) == "bolt":
						bolts += 1
				_check(bolts >= 9, "herald volley fires a ring, got %d" % bolts)

				# An eruption must warn before it bites, or it is a coin flip.
				var erupt = _main.spawn_hazard("eruption", _player.global_position, 25.0, Color.RED)
				erupt.telegraph = 0.75
				var hp_before: float = _player.hp
				erupt._step_eruption()
				_check(absf(_player.hp - hp_before) < 0.01, "eruption is harmless while warning")
				erupt.set("_age", 1.0)
				erupt._step_eruption()
				_check(_player.hp < hp_before, "eruption hurts once the warning ends")

				# Hazards are capped like pickups: unbounded spawning is what
				# caused the long-run crash in the first place.
				for i in _main.MAX_HAZARDS + 30:
					_main.spawn_hazard("bolt", Vector2(i, 0), 1.0, Color.RED)
				var live := get_tree().get_nodes_in_group("hazards").size()
				_check(live <= _main.MAX_HAZARDS + 1,
					"hazards capped at %d, got %d" % [_main.MAX_HAZARDS, live])

				herald.queue_free()
				_player.set("hp", _player.get("max_hp"))
				_main.boss.take_damage(99999999.0, _player.global_position, 0.0)
				_phase = 6
				_wait = 0
		6:
			if _wait > 3:
				_check(_aged_gem == null or not is_instance_valid(_aged_gem),
					"a gem past its lifetime frees itself")
				_check(_gm.stage == 2, "advanced to stage 3, got %d" % _gm.stage)
				_check(get_tree().get_nodes_in_group("hazards").size() == 0,
					"stage change clears leftover hazards")
				_check(_gm.run_time < 2.0, "stage timer reset")
				_check(not _gm.boss_alive, "boss flag cleared")
				_check(_player.hp >= _player.get("max_hp") - 1.0, "healed between stages")

				# Victory now comes from clearing the chosen number of stages
				# rather than reaching the end of the list.
				_gm.stages_cleared = _gm.stages_in_run() - 1
				_main._spawn_boss()
				_check(str(_main.boss.get("etype")) == "cinderking", "cinder king spawned")
				_main.boss.take_damage(99999999.0, _player.global_position, 0.0)
				_phase = 7
				_wait = 0
		7:
			if _wait > 3:
				_check(_gm.state == _gm.State.VICTORY, "final boss -> victory")
				print("STAGES TEST DONE fails=", _fails)
				get_tree().quit(1 if _fails > 0 else 0)
