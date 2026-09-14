extends Node



var _phase := 0
var _wait := 0
var _pwait := 0
var _fails := 0
var _main = null
var _gm = null
var _player = null
var _w = null
var _e1 = null
var _e2 = null
var _e3 = null
var _hp0 := 0.0
var _php0 := 0.0


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
				_check(_player != null and _w != null, "player + weapons node")
				_player.set("max_hp", 100000.0)
				_player.set("hp", 100000.0)
				_check(_gm.WEAPONS.size() == 13, "13 weapons defined, got %d" % _gm.WEAPONS.size())
				_check(_gm.PASSIVES.size() == 7, "7 passives defined, got %d" % _gm.PASSIVES.size())
				for id in ["lance", "miasma", "comet"]:
					_check(_gm.WEAPONS.has(id) and int(_gm.WEAPONS[id]["max"]) == 5, "weapon %s max 5" % id)
				for id in ["siphon", "armor"]:
					_check(_gm.PASSIVES.has(id) and int(_gm.PASSIVES[id]["max"]) == 5, "passive %s max 5" % id)

				var seen := {}
				for i in 40:
					for ch in _gm.roll_upgrades(3):
						seen[ch["id"]] = true
				for id in ["lance", "miasma", "comet", "siphon", "armor"]:
					_check(seen.has(id), "roll_upgrades offers %s" % id)

				_e1 = _main._spawn_enemy("skeleton", _player.global_position + Vector2(300, 0))
				_hp0 = _e1.hp
				_w._fire_lance(3)
				_phase = 1
				_wait = 0
				_pwait = 0
		1:

			if _pwait > 20:
				var lance_hit: bool = (not is_instance_valid(_e1)) or _e1.hp < _hp0
				_check(lance_hit, "lance damaged/killed enemy")

				_e2 = _main._spawn_enemy("skeleton", _player.global_position + Vector2(200, 0))
				_e3 = _main._spawn_enemy("skeleton", _player.global_position + Vector2(230, 30))
				_hp0 = _e2.hp
				_w._fire_miasma(2)
				_phase = 2
				_wait = 0
		2:
			if _wait > 8:
				var clouds := 0
				for n in _main.run.get_children():
					if n is Node2D and str(n.get("mode")) == "miasma":
						clouds += 1
				_check(clouds >= 1, "miasma cloud spawned by _fire_miasma")

				_e2 = _main._spawn_enemy("skeleton", _player.global_position + Vector2(250, 0))
				_e2.set("speed", 0.0)
				_hp0 = _e2.hp
				var p = _w.ProjectileScript.new()
				p.setup("miasma", 50.0, _e2.global_position)
				p.set("cloud_radius", 160.0)
				p.set("life", 6.0)
				_main.run.add_child(p)
				_phase = 21
				_wait = 0
		21:
			if _wait > 40:
				_check((not is_instance_valid(_e2)) or _e2.hp < _hp0, "miasma ticked damage")

				_e3 = _main._spawn_enemy("skeleton", _player.global_position + Vector2(300, 100))
				_hp0 = _e3.hp
				_w._fire_comet(4)
				_phase = 3
				_wait = 0
		3:
			if _wait > 70:
				_check(not is_instance_valid(_e3) or _e3.hp < _hp0, "comet blasted enemy")

				_gm.passives["armor"] = 2
				_php0 = _player.hp
				_player.take_damage(10.0)
				_check(absf(_player.hp - (_php0 - 6.0)) < 0.01, "armor blocked 4 of 10")

				_gm.passives["siphon"] = 3
				_player.set("hp", 50000.0)
				_player.set("_invuln", 999.0)
				_php0 = 50000.0
				var e = _main._spawn_enemy("skeleton", _player.global_position + Vector2(400, 0))
				e.take_damage(999999.0, _player.global_position, 0.0)
				_phase = 4
				_wait = 0
		4:
			if _wait > 5:


				_check(_player.hp >= _php0 + 6.0, "siphon healed 6 on kill")


				_gm.weapons = {"dagger": 5, "fireball": 5, "frost": 5}
				var opt = _main._loot_weapon_option()
				var oid: String = str(opt["id"]) if opt != null else "null"
				_check(_gm.WEAPONS.has(oid), "chest offers a valid weapon, got " + oid)
				print("GEAR TEST DONE fails=", _fails)
				get_tree().quit(1 if _fails > 0 else 0)
