extends Node




var _phase := 0
var _wait := 0
var _pwait := 0
var _fails := 0
var _main = null
var _gm = null
var _player = null
var _w = null
var _e = null
var _hp0 := 0.0


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		print("FAIL: ", name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(720, 1280)
	await get_tree().process_frame
	await get_tree().process_frame
	_main = get_tree().get_first_node_in_group("main")
	_gm = get_node("/root/GameManager")
	_check(_main != null, "main found")
	_main.start_run()
	set_process(true)


func _physics_process(_delta: float) -> void:
	_pwait += 1


func _process(_delta: float) -> void:
	_wait += 1
	match _phase:
		0:
			if _wait > 5:
				_player = _main.player
				_w = _player.get_node("Weapons")
				_player.set("max_hp", 100000.0)
				_player.set("hp", 100000.0)

				_gm.unlocked = {"rogue": 1}
				_gm.selected_class = "rogue"
				_gm.shards = 0
				_gm.meta = {}
				_gm.weapons = {"dagger": 1}
				_main.start_run()
				_player = _main.player
				_w = _player.get_node("Weapons")
				var rogue_hp: float = _player.max_hp
				_player.set("max_hp", 100000.0)
				_player.set("hp", 100000.0)

				var cls: Array = _gm.CHAR_CLASSES
				_check(cls.size() == 13, "13 classes defined")
				var want := [
					["rogue", 0, 100.0, 1.0, 1.0, 1.0, 1.0, "dagger"],
					["shadow", 100, 80.0, 0.85, 1.25, 1.0, 1.1, "sdagger"],
					["pyro", 200, 75.0, 1.35, 0.95, 1.0, 1.0, "ember"],
					["warden", 300, 160.0, 1.0, 0.85, 1.2, 0.95, "bulwark"],
				]
				for i in cls.size():
					var c: Dictionary = cls[i]
					var w: Array = want[i]
					_check(str(c["id"]) == w[0], "class id " + str(w[0]))
					_check(int(c["cost"]) == w[1], "class %s cost %d" % [w[0], w[1]])
					_check(absf(float(c["hp"]) - w[2]) < 0.01, "class %s hp" % w[0])
					_check(absf(float(c["dmg"]) - w[3]) < 0.01, "class %s dmg" % w[0])
					_check(absf(float(c["speed"]) - w[4]) < 0.01, "class %s speed" % w[0])
					_check(absf(float(c["magnet"]) - w[5]) < 0.01, "class %s magnet" % w[0])
					_check(absf(float(c["xp"]) - w[6]) < 0.01, "class %s xp" % w[0])
					_check(str(c["weapon"]) == w[7], "class %s weapon %s" % [w[0], w[7]])
					_check(_gm.WEAPONS.has(str(c["weapon"])), "class weapon in WEAPONS: " + str(c["weapon"]))
					_check(int(_gm.WEAPONS[str(c["weapon"])]["max"]) == 5, "class weapon max 5: " + str(c["weapon"]))
					_check(_gm.EVOLUTIONS.has(str(c["weapon"])), "class weapon has evolution: " + str(c["weapon"]))
					_check((c["palette"] as Dictionary).has("cloak"), "class %s has palette" % w[0])

				_check(_gm.is_class_unlocked("rogue"), "rogue unlocked by default")
				_check(not _gm.is_class_unlocked("shadow"), "shadow locked by default")

				var seen := {}
				for i in 60:
					for ch in _gm.roll_upgrades(3):
						seen[ch["id"]] = true
				for id in ["sdagger", "ember", "bulwark"]:
					_check(seen.has(id), "roll_upgrades offers " + id)

				_check(str(_player.get("class_id")) == "rogue", "default run class rogue")
				_check(_gm.weapons.keys() == ["dagger"], "default run starts with dagger")
				_check(absf(rogue_hp - 100.0) < 0.01, "rogue max hp 100, got %.1f" % rogue_hp)
				_phase = 1
				_wait = 0
		1:
			if _wait > 3:

				_gm.selected_class = "rogue"
				_check(not _gm.select_class("pyro"), "locked class cannot be selected")
				_check(_gm.selected_class == "rogue", "selection unchanged when locked")

				_gm.shards = 50
				_check(not _gm.unlock_class("pyro"), "unlock fails with 50/200 shards")
				_check(not _gm.is_class_unlocked("pyro"), "pyro still locked")

				_gm.shards = 500
				_check(_gm.unlock_class("shadow"), "shadow unlocks for 100")
				_check(_gm.shards == 400, "shards deducted to 400")
				_check(_gm.is_class_unlocked("shadow"), "shadow unlocked")
				_check(_gm.select_class("shadow"), "unlocked class selects")
				_gm.save_meta()
				_gm.unlocked = {"rogue": 1}
				_gm.selected_class = "rogue"
				_gm.shards = 0
				_gm.load_meta()
				_check(_gm.is_class_unlocked("shadow"), "unlock persists across save/load")
				_check(_gm.shards == 400, "shard balance persists, got %d" % _gm.shards)
				_check(_gm.selected_class == "shadow", "selection persists, got " + str(_gm.selected_class))
				_check(_gm.is_class_unlocked("rogue"), "rogue still unlocked after load")
				_phase = 2
				_wait = 0
		2:
			if _wait > 3:

				_gm.select_class("shadow")
				_main.start_run()
				_player = _main.player
				_w = _player.get_node("Weapons")
				_check(str(_player.get("class_id")) == "shadow", "run uses selected class")
				_check(_gm.weapons.keys() == ["sdagger"], "shadow starts with Shadow Daggers")
				_check(absf(_player.max_hp - 80.0) < 0.01, "shadow max hp 80, got %.1f" % _player.max_hp)
				_check(absf(_gm.might_mult() - 0.85) < 0.01, "shadow dmg mult 0.85")
				_check(absf(_gm.speed_mult() - 1.25) < 0.01, "shadow speed mult 1.25")
				_check(absf(_gm.meta_xp_mult() - 1.1) < 0.01, "shadow xp mult 1.1")
				_check(absf(_gm.magnet_mult() - 1.0) < 0.01, "shadow magnet mult 1.0")
				_check(_player._pal.has("cloak"), "player palette loaded")
				_player.set("max_hp", 100000.0)
				_player.set("hp", 100000.0)

				_gm.unlocked["warden"] = 1
				_gm.select_class("warden")
				_main.start_run()
				_player = _main.player
				_w = _player.get_node("Weapons")
				_check(_gm.weapons.keys() == ["bulwark"], "warden starts with Bulwark Slam")
				_check(absf(_player.max_hp - 160.0) < 0.01, "warden max hp 160")
				_check(absf(_gm.speed_mult() - 0.85) < 0.01, "warden speed mult 0.85")
				_check(absf(_gm.magnet_mult() - 1.2) < 0.01, "warden magnet mult 1.2")

				_gm.unlocked["pyro"] = 1
				_gm.select_class("pyro")
				_main.start_run()
				_player = _main.player
				_w = _player.get_node("Weapons")
				_check(_gm.weapons.keys() == ["ember"], "pyro starts with Ember Volley")
				_check(absf(_player.max_hp - 75.0) < 0.01, "pyro max hp 75")
				_check(absf(_gm.might_mult() - 1.35) < 0.01, "pyro dmg mult 1.35")
				_player.set("max_hp", 100000.0)
				_player.set("hp", 100000.0)
				_phase = 3
				_wait = 0
				_pwait = 0
		3:
			if _wait > 3:

				_gm.weapons = {}
				_gm.weapons_changed.emit()

				_e = _main._spawn_enemy("skeleton", _player.global_position + Vector2(300, 0))
				_hp0 = _e.hp
				_w._fire_sdagger(3)
				_phase = 4
				_wait = 0
				_pwait = 0
		4:
			if _pwait > 20:
				_check(not is_instance_valid(_e) or _e.hp < _hp0, "sdagger damaged enemy")

				_e = _main._spawn_enemy("skeleton", _player.global_position + Vector2(300, 60))
				_e.set("speed", 0.0)
				_hp0 = _e.hp
				_w._fire_ember(3)
				_phase = 5
				_wait = 0
				_pwait = 0
		5:
			if _pwait > 40:
				_check(not is_instance_valid(_e) or _e.hp < _hp0, "ember blasted enemy")

				_w.set("facing", Vector2.RIGHT)
				_e = _main._spawn_enemy("skeleton", _player.global_position + Vector2(120, 0))
				_e.set("speed", 0.0)
				_hp0 = _e.hp
				_w._fire_bulwark(3)
				_phase = 6
				_wait = 0
				_pwait = 0
		6:
			if _pwait > 15:
				_check(not is_instance_valid(_e) or _e.hp < _hp0, "bulwark slammed enemy")

				_w.set("facing", Vector2.RIGHT)
				var back = _main._spawn_enemy("skeleton", _player.global_position + Vector2(-150, 0))
				back.set("speed", 0.0)
				var back_hp: float = back.hp
				_w._fire_bulwark(3)
				_phase = 61
				_wait = 0
				_pwait = 0
				_e = back
				_hp0 = back_hp
		61:
			if _pwait > 15:
				_check(is_instance_valid(_e) and _e.hp >= _hp0, "bulwark misses enemies behind")

				for id in ["sdagger", "ember", "bulwark"]:
					_check(_w._cooldown(id) > 0.0, "cooldown defined: " + id)
				_gm.weapons = {"sdagger": 5}
				_gm.weapons_changed.emit()
				_check(int(_gm.weapons["sdagger"]) == 5, "sdagger reaches lvl 5")
				_gm.weapons = {"dagger": 1}
				_gm.weapons_changed.emit()
				_phase = 7
				_wait = 0
		7:
			if _wait > 5:

				var CSScript = load("res://src/char_select.gd")
				var cs = CSScript.new()
				get_tree().root.add_child(cs)
				await get_tree().process_frame
				await get_tree().process_frame
				cs.show_screen()
				await get_tree().process_frame
				_check(cs.visible, "char select visible")
				_check(cs.cards.size() == 4, "4 class cards")
				var fits := true
				for id in cs.cards:
					var p: PanelContainer = cs.cards[id]["panel"]
					var r := p.get_global_rect()
					if r.position.x < -1.0 or r.end.x > 721.0 or r.end.y > 1281.0:
						fits = false
				_check(fits, "all cards fit 720x1280")

				_gm.unlocked.erase("pyro")
				_gm.select_class("rogue")
				_gm.shards = 400
				cs.refresh()
				cs._on_action("pyro")
				_check(_gm.is_class_unlocked("pyro"), "UI unlock button unlocked pyro")
				_check(_gm.shards == 200, "UI unlock deducted 200, got %d" % _gm.shards)
				_check(_gm.selected_class == "pyro", "UI unlock selected pyro")
				_check(str(cs.cards["pyro"]["action"].text) == "ACTIVE", "pyro card shows ACTIVE")
				cs.queue_free()
				print("CHARS TEST DONE fails=", _fails)
				get_tree().quit(1 if _fails > 0 else 0)
