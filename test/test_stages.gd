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
				_main.boss.take_damage(99999999.0, _player.global_position, 0.0)
				_phase = 4
				_wait = 0
		4:
			if _wait > 3:
				_check(_aged_gem == null or not is_instance_valid(_aged_gem),
					"a gem past its lifetime frees itself")
				_check(_gm.stage == 2, "advanced to stage 3, got %d" % _gm.stage)
				_check(_gm.run_time < 2.0, "stage timer reset")
				_check(not _gm.boss_alive, "boss flag cleared")
				_check(_player.hp >= _player.get("max_hp") - 1.0, "healed between stages")

				# Victory now comes from clearing the chosen number of stages
				# rather than reaching the end of the list.
				_gm.stages_cleared = _gm.stages_in_run() - 1
				_main._spawn_boss()
				_check(str(_main.boss.get("etype")) == "cinderking", "cinder king spawned")
				_main.boss.take_damage(99999999.0, _player.global_position, 0.0)
				_phase = 5
				_wait = 0
		5:
			if _wait > 3:
				_check(_gm.state == _gm.State.VICTORY, "final boss -> victory")
				print("STAGES TEST DONE fails=", _fails)
				get_tree().quit(1 if _fails > 0 else 0)
