extends Node
# The eight new enemy roles: each behaviour's rule, its drop rule, its
# fallback body and its cap.

var _fails := 0
var _gm = null
var _main = null
var _p = null


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		print("FAIL: ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_gm = get_node("/root/GameManager")
	_main = get_tree().get_first_node_in_group("main")
	_gm.selected_stage = 4
	_main.start_run()
	await _frames(3)
	_main.intermission = 99999.0
	_p = _main.player
	_p.max_hp = 1000000.0
	_p.hp = _p.max_hp
	# Disarm the player: these checks watch enemy health, and an auto-firing
	# dagger would race them.
	_gm.weapons = {}
	_gm.weapons_changed.emit()
	await _roles()
	_main.show_title()
	print("ENEMIES TEST DONE fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _spawn(et: String, off: Vector2):
	return _main._spawn_enemy(et, _p.global_position + off)


func _clear() -> void:
	for e in get_tree().get_nodes_in_group("hostiles"):
		e.queue_free()
	for h in get_tree().get_nodes_in_group("hazards"):
		h.queue_free()
	for g in get_tree().get_nodes_in_group("gems"):
		g.queue_free()


func _roles() -> void:
	# Fallback bodies: none of the roles has a sprite sheet, all draw.
	for et in ["cultist_healer", "necromancer", "shield_bearer", "ranged_cultist", "burrower",
			"banner_carrier", "xp_leech", "mimic"]:
		var e = _spawn(et, Vector2(600, 600))
		_check(e.behavior != null, "%s: behaviour attached" % et)
		var own_draw: bool = e.behavior.get_script().get_script_method_list().any(func(m): return m["name"] == "draw_body")
		_check(e._spr == null and own_draw, "%s: procedural fallback body" % et)
		_check(e.data.drop_profile != "", "%s: has a drop rule" % et)
		e.queue_free()
	await _frames(1)

	# Healer: heals the most wounded ally; a big hit breaks the beam.
	var ally = _spawn("husk", Vector2(400, 0))
	ally.hp = ally.max_hp * 0.3
	var healer = _spawn("cultist_healer", Vector2(550, 0))
	await _frames(40)
	_check(ally.hp > ally.max_hp * 0.3, "healer: channels health into a wounded ally")
	_check(healer.behavior.channeling(), "healer: beam visible while channelling")
	healer.take_damage(healer.max_hp * 0.2, healer.global_position, 0.0, "dagger")
	_check(not healer.behavior.channeling(), "healer: a heavy hit interrupts the beam")
	var h0: float = ally.hp
	await _frames(20)
	_check(ally.hp <= h0, "healer: stays interrupted for its recovery")
	_clear()
	await _frames(1)

	# Shield bearer: front blocked, flank open.
	var sb = _spawn("shield_bearer", Vector2(300, 0))
	for i in 60:
		sb.behavior.step(0.05, (_p.global_position - sb.global_position).normalized())
	var hp0: float = sb.hp
	sb.take_damage(50.0, _p.global_position, 0.0, "dagger")
	var front: float = hp0 - sb.hp
	hp0 = sb.hp
	sb.take_damage(50.0, sb.global_position * 2.0 - _p.global_position, 0.0, "dagger")
	var back: float = hp0 - sb.hp
	_check(front < back * 0.5, "shield: frontal hits are blocked, flanks are not")
	_clear()
	await _frames(1)

	# Ranged cultist: telegraphs its line before it hurts.
	var rc = _spawn("ranged_cultist", Vector2(380, 0))
	rc.behavior._fire = 0.0
	rc.behavior.step(0.016, Vector2.LEFT)
	var line: TimedHazard = null
	for h in get_tree().get_nodes_in_group("enemy_hazards"):
		line = h
	_check(line != null and String(line.shape["kind"]) == "line", "ranged: paints a line")
	_check(line.warn_time >= 0.65 and not line.is_damaging(), "ranged: the line warns first")
	_check(rc.behavior.step(0.016, Vector2.LEFT) == Vector2.ZERO, "ranged: plants its feet while aiming")
	for i in 20:
		rc.behavior._fire = 0.0
		rc.behavior._aim = 0.0
		rc.behavior.step(0.016, Vector2.LEFT)
	_check(get_tree().get_nodes_in_group("enemy_hazards").size() <= 10, "ranged: shots are capped")
	_clear()
	await _frames(1)

	# Burrower: untargetable underground, exit marked, lead capped.
	var bw = _spawn("burrower", Vector2(250, 0))
	_p.velocity = Vector2(1000, 0)
	bw.behavior._timer = 0.0
	bw.behavior.step(0.016, Vector2.LEFT)
	_check(bw.behavior.underground and not bw.is_in_group("enemies"), "burrower: dives out of reach")
	_check(bw.behavior._exit.distance_to(_p.global_position) <= 1000.0 * 0.6 + 1.0, "burrower: lead capped at 0.6s")
	var bh: float = bw.hp
	bw.take_damage(50.0, bw.global_position, 0.0, "dagger")
	_check(is_equal_approx(bw.hp, bh), "burrower: cannot be hit underground")
	_check(not bw.behavior.can_contact(), "burrower: cannot touch you underground")
	for i in 200:
		bw.behavior.step(0.02, Vector2.LEFT)
		if not bw.behavior.underground:
			break
	_check(bw.behavior._marked, "burrower: exit marked before emerging")
	_check(not bw.behavior.underground and bw.is_in_group("enemies"), "burrower: resurfaces")
	_p.velocity = Vector2.ZERO
	_clear()
	await _frames(1)

	# Banner carrier: bounded rally; the fallen banner can be torn.
	var bc = _spawn("banner_carrier", Vector2(600, 0))
	var troop: Array = []
	for i in 12:
		troop.append(_spawn("skeleton", Vector2(600 + (i % 4) * 20, 40 + (i / 4) * 20)))
	await _frames(1)
	bc.behavior._pulse = 0.0
	bc.behavior.step(0.016, Vector2.LEFT)
	var rallied := troop.filter(func(e): return e.rallied()).size()
	_check(rallied > 0 and rallied <= 8, "banner: rallies a bounded group (%d)" % rallied)
	bc.take_damage(999999.0, bc.global_position, 0.0, "dagger")
	await _frames(1)
	var fallen := get_tree().get_nodes_in_group("fallen_banners")
	_check(fallen.size() == 1, "banner: drops its banner on death")
	_p.global_position = fallen[0].global_position
	await _frames(2)
	_check(get_tree().get_nodes_in_group("fallen_banners").filter(func(f): return not f.is_queued_for_deletion()).is_empty(),
		"banner: walking over it tears it")
	_clear()
	await _frames(1)

	# Leech: swallows gems, returns them on death.
	var lc = _spawn("xp_leech", Vector2(300, 300))
	_main.spawn_gem(lc.global_position + Vector2(10, 0), 5)
	_main.spawn_gem(lc.global_position + Vector2(-10, 0), 7)
	await _frames(1)
	for g in get_tree().get_nodes_in_group("gems"):
		g.vel = Vector2.ZERO
		lc.behavior.swallow(g)
	_check(lc.behavior.stored == 12, "leech: swallows loose gems")
	lc.take_damage(999999.0, lc.global_position, 0.0, "dagger")
	await _frames(1)
	var total := 0
	for g in get_tree().get_nodes_in_group("gems"):
		total += int(g.value)
	_check(total >= 12, "leech: gives back what it stole (+its own)")
	_clear()
	await _frames(1)

	# Mimic: dormant tell, wakes in range, never in the chest group.
	var mm = _spawn("mimic", Vector2(400, 0))
	_check(not mm.is_in_group("chests"), "mimic: never counts as a reward chest")
	_check(not mm.behavior.awake and not mm.behavior.can_contact(), "mimic: harmless while dormant")
	_p.global_position = mm.global_position + Vector2(100, 0)
	mm.behavior.step(0.016, Vector2.LEFT)
	_check(mm.behavior.awake, "mimic: wakes when approached")
	_check(not mm.behavior.can_contact(), "mimic: hesitates before biting")
	var sh0 := get_tree().get_nodes_in_group("shards").size()
	mm.take_damage(999999.0, mm.global_position, 0.0, "dagger")
	await _frames(1)
	_check(get_tree().get_nodes_in_group("shards").size() >= sh0 + 6, "mimic: pays shards")
	_clear()
	await _frames(1)

	# Necromancer: raises from a corpse; raised dead give nothing; capped.
	var nc = _spawn("necromancer", Vector2(300, 0))
	var victim = _spawn("skeleton", Vector2(320, 0))
	victim.take_damage(99999.0, victim.global_position, 0.0, "dagger")
	await _frames(1)
	var kills0: int = _gm.kills
	for i in 200:
		nc.behavior.step(0.05, Vector2.LEFT)
		if nc.behavior._state == "cooldown":
			break
		nc.global_position = nc.global_position.move_toward(victim.global_position if is_instance_valid(victim) else nc.global_position, 30.0)
	var raised := get_tree().get_nodes_in_group("enemies").filter(func(e): return e.revived)
	_check(raised.size() >= 1, "necromancer: raises the dead")
	for e in raised:
		_check(e.no_credit, "necromancer: raised dead carry no credit")
	var g0 := get_tree().get_nodes_in_group("gems").size()
	for e in raised:
		e.take_damage(99999.0, e.global_position, 0.0, "dagger")
	await _frames(1)
	_check(_gm.kills == kills0 and get_tree().get_nodes_in_group("gems").size() == g0,
		"necromancer: killing the raised pays nothing")
	_check(_main.claim_corpse(victim.global_position if is_instance_valid(victim) else Vector2.ZERO, 50.0) == null,
		"necromancer: a corpse is raised only once")
	var nb = load("res://src/enemies/behaviors/necromancer.gd")
	for i in 14:
		var r = _spawn("skeleton", Vector2(-500, i * 10))
		r.revived = true
	_check(nb.revived_alive(get_tree()) >= 10, "necromancer: revived count tracked")
	nc.behavior._source = {"pos": nc.global_position, "t": 0.0, "used": false}
	var before: int = nb.revived_alive(get_tree())
	nc.behavior._raise()
	_check(nb.revived_alive(get_tree()) == before, "necromancer: global revive cap holds")
	_clear()
	await _frames(1)

	# Special spawns respect their caps.
	_gm.selected_stage = 2
	_main.start_run()
	await _frames(3)
	var d = _main.director
	for i in 60:
		_gm.run_time = 40.0 + i * 31.0 if 40.0 + i * 31.0 < 295.0 else 294.0
		d._special_spawns(_gm.run_time)
	_check(_main.count_alive("shield_bearer") <= 3, "spawns: shield bearers capped")
	_check(_main.count_alive("banner_carrier") <= 1, "spawns: banner carriers capped")
