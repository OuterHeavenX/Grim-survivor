extends Node


var _phase := 0
var _wait := 0
var _fails := 0
var _main = null
var _gm = null
var _player = null
var _elite = null


func _kill_boss() -> void:
	var b = _main.boss
	b.set("hp", 1.0)
	b.take_damage(99999.0, b.global_position + Vector2(10, 0), 0.0)


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


func _chests() -> Array:
	return get_tree().get_nodes_in_group("chests")


func _process(_delta: float) -> void:
	_wait += 1
	match _phase:
		0:
			if _wait > 5:
				_player = _main.player
				_check(_player != null, "player spawned")

				_player.set("max_hp", 100000.0)
				_player.set("hp", 100000.0)

				_elite = _main._spawn_enemy("skeleton", Vector2(300, 0))
				var hp0: float = _elite.max_hp
				var dmg0: float = _elite.dmg
				var spd0: float = _elite.speed
				# Elites roll an affix now, and several of them trade health for
				# their gimmick, so this pins the affix rather than assuming the
				# old flat x8. Left unforced it would pass only when the roll
				# happened to come up vampiric.
				_elite.make_elite("vampiric")
				_check(_elite.get("is_elite"), "elite flagged")
				_check(str(_elite.get("affix")) == "vampiric", "elite affix forced")
				_check(absf(_elite.max_hp - hp0 * 8.0) < 0.01, "vampiric elite hp x8")
				_check(absf(_elite.dmg - dmg0 * 1.5) < 0.01, "elite dmg x1.5")
				_check(absf(_elite.speed - spd0 * 1.15) < 0.01, "elite speed x1.15")
				_check(absf(_elite.scale.x - 1.35) < 0.01, "elite scale 1.35")

				# Every affix must be reachable and must actually differ from
				# the others, or "five affixes" is just one affix with labels.
				# These probes free() immediately rather than queue_free(): a
				# deferred free would leave them in the enemies group for the
				# rest of the frame and contaminate the counts below.
				var seen_hp := {}
				for a in _elite.AFFIXES:
					var probe = _main._spawn_enemy("skeleton", Vector2(900, 900))
					var base_hp: float = probe.max_hp
					var base_spd: float = probe.speed
					probe.make_elite(a)
					_check(str(probe.get("affix")) == a, "affix %s applies" % a)
					_check(probe.max_hp > base_hp, "affix %s raises hp" % a)
					seen_hp[snappedf(probe.max_hp / base_hp, 0.01)] = true
					if a == "swift":
						_check(probe.speed > base_spd * 1.7, "swift elite is fast")
					probe.free()
				_check(seen_hp.size() >= 3, "affixes differ in bulk, got %d tiers" % seen_hp.size())

				# A swift elite must not also get the generic speed bump on top
				# of its own, or it outruns the player outright.
				var sw = _main._spawn_enemy("skeleton", Vector2(950, 950))
				var sw_base: float = sw.speed
				sw.make_elite("swift")
				_check(absf(sw.speed - sw_base * 1.75) < 0.01, "swift speed not double-applied")
				sw.free()

				# The ward absorbs a hit whole rather than chipping down.
				var wd = _main._spawn_enemy("skeleton", Vector2(980, 980))
				wd.make_elite("warded")
				wd.set("_shielded", true)
				var wd_hp: float = wd.hp
				wd.take_damage(50.0, wd.global_position + Vector2(10, 0), 0.0)
				_check(absf(wd.hp - wd_hp) < 0.01, "ward absorbs a full hit")
				_check(not bool(wd.get("_shielded")), "ward drops after absorbing")
				wd.take_damage(50.0, wd.global_position + Vector2(10, 0), 0.0)
				_check(wd.hp < wd_hp, "damage lands once the ward is down")
				wd.free()

				# A splitting elite leaves two weaker copies. Identify them by
				# diffing against the enemies already present -- the parent is
				# queue_free()d, so it is still in the group and cannot simply
				# be counted out.
				var before := {}
				for e in get_tree().get_nodes_in_group("enemies"):
					before[e.get_instance_id()] = true
				var chests_before := _chests().size()
				var sp = _main._spawn_enemy("skeleton", Vector2(-900, -900))
				before[sp.get_instance_id()] = true
				sp.make_elite("splitting")
				var sp_hp: float = sp.max_hp
				sp.set("hp", 1.0)
				sp.take_damage(9999.0, sp.global_position + Vector2(10, 0), 0.0)
				var kids := []
				for e in get_tree().get_nodes_in_group("enemies"):
					if not before.has(e.get_instance_id()):
						kids.append(e)
				_check(kids.size() == 2, "splitting elite leaves 2, got %d" % kids.size())
				var kids_plain := true
				var kids_weak := true
				for k in kids:
					if bool(k.get("is_elite")):
						kids_plain = false
					if k.max_hp >= sp_hp * 0.5:
						kids_weak = false
				_check(kids_plain, "split offspring are not themselves elite")
				_check(kids_weak, "split offspring are weaker than the parent")
				# Clear up after this side-quest so the chest and raven phases
				# below still see the arena they expect.
				for k in kids:
					k.free()
				for c in _chests():
					if chests_before == 0:
						c.free()

				_phase = 1
				_wait = 0
		1:
			if _wait > 3:

				_elite.take_damage(1.0, _elite.global_position + Vector2(50, 0), 500.0)
				_check(_elite.get("_kb").length() < 0.01, "elite knockback immune")

				var k0: int = _gm.kills
				_elite.set("hp", 1.0)
				_elite.take_damage(50.0, _elite.global_position + Vector2(10, 0), 100.0)
				_phase = 2
				_wait = 0
		2:
			if _wait > 5:
				_check(_chests().size() == 1, "elite dropped a chest")
				_check(get_tree().get_nodes_in_group("shards").size() >= 5, "elite dropped 5 shards")

				_player.position = (_chests()[0] as Node2D).global_position
				_phase = 3
				_wait = 0
		3:
			if _wait > 8:
				_check(_gm.state == _gm.State.CHEST, "chest opened: state CHEST")
				_check(get_tree().paused, "chest opened: tree paused")
				_check(_main.loot_ui.visible, "loot UI visible")
				_check(_main.loot_ui.panel.get_child_count() == 3, "loot UI has 3 options")
				var kinds := {}
				for o in _main.roll_loot():
					kinds[o["kind"]] = true
				_check(kinds.size() == 3, "loot options are 3 distinct kinds")
				_phase = 4
				_wait = 0
		4:
			if _wait > 3:

				_gm.weapons = {"dagger": 1}
				var wopt = _main._loot_weapon_option()
				_main._apply_loot({"kind": "weapon", "id": wopt["id"], "to": wopt["to"]})
				_check(int(_gm.weapons[wopt["id"]]) == int(wopt["to"]), "loot: weapon upgrade applies")
				_player.set("hp", 20.0)
				_main._apply_loot({"kind": "heal"})
				var want_hp: float = minf(100000.0, 20.0 + 100000.0 * 0.6)
				_check(absf(float(_player.get("hp")) - want_hp) < 0.01, "loot: heal restores 60% max HP")
				var s0: int = _gm.run_shards
				_main._apply_loot({"kind": "shards"})
				_check(_gm.run_shards == s0 + 25, "loot: +25 shards")
				_gm.state = _gm.State.RUNNING
				var x0: int = _gm.xp
				_main._apply_loot({"kind": "xp"})
				_check(_gm.xp > x0, "loot: xp surge grants XP")
				if _gm.state == _gm.State.LEVELUP:
					_gm.pending_levelups = 0
					_main._on_upgrade_chosen()
				_check(_gm.state == _gm.State.CHEST or _gm.state == _gm.State.RUNNING, "xp surge level chain resolves")
				_gm.state = _gm.State.CHEST
				for i in 6:
					_main.spawn_gem(_player.global_position + Vector2(300, i * 40.0), 1)
				_phase = 5
				_wait = 0
		5:
			if _wait > 5:
				var g0 := get_tree().get_nodes_in_group("gems").size()
				_check(g0 >= 6, "test gems spawned")
				_main._apply_loot({"kind": "magnet_burst"})
				_phase = 6
				_wait = 0
		6:
			if _wait > 8:
				_check(get_tree().get_nodes_in_group("gems").size() == 0, "loot: magnet burst vacuums all gems")
				var r0: int = _gm.revives_left
				_main._apply_loot({"kind": "revive"})
				_check(_gm.revives_left == r0 + 1, "loot: revive charge +1")

				_main._on_loot_chosen({"kind": "shards"})
				_phase = 7
				_wait = 0
		7:
			if _wait > 5:
				_check(not get_tree().paused, "loot choice: tree unpaused")
				_check(_gm.state == _gm.State.RUNNING, "loot choice: state RUNNING")
				_check(not _main.loot_ui.visible, "loot choice: UI hidden")

				_gm.weapons["scythe"] = 1
				_gm.weapons_changed.emit()
				_phase = 8
				_wait = 0
		8:
			if _wait > 5:
				var sc: int = _player.weapons_node.scythe_root.get_child_count()
				_check(sc == 1, "scythe orbital created")
				var foe = _main._spawn_enemy("skeleton", _player.global_position + Vector2(150, 0))
				foe.set("max_hp", 5000.0)
				foe.set("hp", 5000.0)
				_elite = foe
				_phase = 9
				_wait = 0
		9:
			if _wait > 90:
				_check(not is_instance_valid(_elite) or float(_elite.get("hp")) < 5000.0, "scythe damages enemies")

				_gm.weapons["raven"] = 1
				_gm.weapons_changed.emit()
				var foe2 = _main._spawn_enemy("husk", _player.global_position + Vector2(400, 0))
				foe2.set("max_hp", 5000.0)
				foe2.set("hp", 5000.0)
				_elite = foe2
				_player.weapons_node._fire("raven", 1)
				_phase = 10
				_wait = 0
		10:
			if _wait > 120:
				_check(not is_instance_valid(_elite) or float(_elite.get("hp")) < 5000.0, "ravens seek and damage enemies")

				_gm.pending_levelups = 1
				_gm.level_changed.emit()
				_phase = 11
				_wait = 0
		11:
			if _wait > 8:
				_check(get_tree().paused and _main.levelup_ui.visible, "regression: level-up pauses")
				_gm.pending_levelups = 0
				_main._on_upgrade_chosen()
				_phase = 12
				_wait = 0
		12:
			if _wait > 8:
				_check(not get_tree().paused and _gm.state == _gm.State.RUNNING, "regression: level-up resumes")

				_gm.run_time = 299.95
				_phase = 13
				_wait = 0
		13:
			if _wait > 15:
				_check(bool(_gm.boss_spawned), "regression: boss spawns at 5:00")
				_check(_gm.stage == 0, "boss 1 is the first stage's boss")
				_kill_boss()
				_phase = 131
				_wait = 0
		131:
			# Only the final stage's boss wins the run; the earlier two advance.
			if _wait > 15:
				_check(_gm.stage == 1 and _gm.state == _gm.State.RUNNING,
					"regression: stage 1 boss advances rather than winning")
				# Victory is now about clearing the chosen number of stages, not
				# about reaching the last one in the list, so stand one short.
				_gm.stages_cleared = _gm.stages_in_run() - 1
				_gm.stage = _gm.STAGES.size() - 1
				_gm.run_time = 299.95
				_phase = 132
				_wait = 0
		132:
			if _wait > 15:
				_check(bool(_gm.boss_spawned), "final boss spawns at 5:00")
				_kill_boss()
				_phase = 14
				_wait = 0
		14:
			if _wait > 10:
				_check(_main.end_screen.visible and _gm.state == _gm.State.VICTORY, "regression: victory screen")
				_main.start_run()
				_phase = 15
				_wait = 0
		15:
			if _wait > 8:
				_player = _main.player
				_player.take_damage(999999.0)
				_phase = 16
				_wait = 0
		16:
			if _wait > 10:
				_check(_main.end_screen.visible and _gm.state == _gm.State.GAMEOVER, "regression: game-over screen")
				print("RESULT: ", "ALL PASS" if _fails == 0 else str(_fails) + " FAILURES")
				get_tree().quit(1 if _fails > 0 else 0)
