extends Node
# Cross-weapon interactions and relics: each one fires, attributes its
# damage, respects its rate limit, and never triggers itself.

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
	await _interactions()
	await _relics()
	_main.show_title()
	print("INTERACTIONS TEST DONE fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _foe(off: Vector2, hp := 100000.0):
	var e = _main._spawn_enemy("husk", _p.global_position + off)
	e.max_hp = hp
	e.hp = hp
	return e


func _reset_rates() -> void:
	_main.combat._next.clear()


func _procs(kind: String) -> int:
	return int(_gm.run_stats.interaction_procs.get(kind, 0))


func _interactions() -> void:
	var c: CombatRules = _main.combat
	# 1. Fire ignites miasma, once per cloud, capped.
	var cloud = load("res://src/projectile.gd").new()
	cloud.setup("miasma", 9.0, _p.global_position + Vector2(400, 0))
	cloud.set("cloud_radius", 120.0)
	cloud.set("life", 5.0)
	_main.run.add_child(cloud)
	var inside = _foe(Vector2(400, 0))
	await _frames(1)
	var hp0: float = inside.hp
	_reset_rates()
	c.on_explosion(cloud.global_position, 60.0, "fireball")
	_check(bool(cloud.ignited), "ignite: fire ignites miasma")
	var dealt: float = hp0 - inside.hp
	_check(dealt > 0.0 and dealt <= CombatRules.IGNITE_CAP * _gm.might_mult() * 1.5, "ignite: explosion is capped")
	_check(_gm.run_stats.damage_by_source.has("interaction:ignite"), "ignite: damage attributed")
	var before := _procs("ignite")
	_reset_rates()
	c.on_explosion(cloud.global_position, 60.0, "fireball")
	_check(_procs("ignite") == before, "ignite: a cloud ignites only once")
	c.on_explosion(cloud.global_position, 60.0, "interaction:ignite")
	_check(_procs("ignite") == before, "ignite: an ignition cannot ignite")
	inside.queue_free()
	# 2. Heavy impact shatters frozen foes.
	var fz = _foe(Vector2(0, 300))
	var nb = _foe(Vector2(40, 300))
	fz.take_damage(1.0, fz.global_position, 0.0, "frost")
	_check(fz.has_status("frozen"), "shatter: frost freezes")
	_reset_rates()
	var h1: float = fz.hp
	var nb0: float = nb.hp
	fz.take_damage(100.0, fz.global_position, 0.0, "lance")
	await _frames(1)
	_check(not fz.has_status("frozen"), "shatter: frozen status consumed")
	_check(h1 - fz.hp >= 100.0 + 100.0 * CombatRules.SHATTER_BONUS - 1.0, "shatter: bonus damage")
	_check(nb.hp < nb0, "shatter: shards hit a neighbour")
	var sh := _procs("shatter")
	fz.set_status("frozen", 2.0)
	_reset_rates()
	fz.take_damage(50.0, fz.global_position, 0.0, "interaction:shatter")
	_check(_procs("shatter") == sh, "shatter: shatter damage cannot shatter")
	# 3. Scythe harvests become ravens, capped.
	var harvest0 := _procs("harvest")
	for i in 8:
		_reset_rates()
		var v = _foe(Vector2(-300, 0), 1.0)
		v.take_damage(10.0, v.global_position, 0.0, "scythe")
	await _frames(1)
	_check(_procs("harvest") > harvest0, "harvest: scythe kills raise ravens")
	_check(get_tree().get_nodes_in_group("harvest_ravens").size() <= CombatRules.MAX_HARVEST_RAVENS, "harvest: raven cap")
	var hv := _procs("harvest")
	_reset_rates()
	var v2 = _foe(Vector2(-300, 40), 1.0)
	v2.take_damage(10.0, v2.global_position, 0.0, "interaction:harvest")
	_check(_procs("harvest") == hv, "harvest: a raven's kill raises no raven")
	# 4. Blades conduct lightning, rate limited.
	_gm.weapons["lightning"] = 1
	var a = _foe(Vector2(0, -300))
	var b = _foe(Vector2(60, -300))
	var b0: float = b.hp
	_reset_rates()
	a.take_damage(10.0, a.global_position, 0.0, "blades")
	await _frames(1)
	_check(b.hp < b0, "conduct: blade hit arcs to a neighbour")
	var cd := _procs("conduct")
	a.take_damage(10.0, a.global_position, 0.0, "blades")
	_check(_procs("conduct") == cd, "conduct: rate limited")
	_gm.weapons.erase("lightning")
	# 5. Burning foes draw comets.
	var cold = _foe(Vector2(300, 300))
	var hot = _foe(Vector2(-300, 300))
	hot.take_damage(1.0, hot.global_position, 0.0, "ember")
	_check(hot.has_status("burning"), "kindling: fire sets foes burning")
	_check(c.comet_weight(hot) > c.comet_weight(cold), "kindling: burning foes weigh more for comets")
	var picks := 0
	for i in 400:
		if c.pick_comet_target([cold, hot]) == hot:
			picks += 1
	_check(picks > 240, "kindling: comets favour burning foes (%d/400)" % picks)
	# 6. Lance marks; the next thrown hit cashes it in once.
	var m = _foe(Vector2(200, -200))
	m.take_damage(10.0, m.global_position, 0.0, "lance")
	_check(m.has_status("marked"), "mark: lance marks")
	var m0: float = m.hp
	m.take_damage(100.0, m.global_position, 0.0, "dagger")
	_check(m0 - m.hp >= 100.0 * (1.0 + CombatRules.MARK_BONUS) - 0.5, "mark: follow-up hit deals bonus")
	_check(not m.has_status("marked"), "mark: consumed by the follow-up")
	m0 = m.hp
	m.take_damage(100.0, m.global_position, 0.0, "dagger")
	_check(is_equal_approx(m0 - m.hp, 100.0), "mark: bonus applies once")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(1)


func _relics() -> void:
	var r: RelicManager = _main.relics
	# Rolling respects discovery, ownership and weapon requirements.
	_gm.weapons = {"dagger": 1}
	var offered := {}
	for i in 60:
		for rd in _gm.roll_relics(PackedStringArray(["fire"]), 3):
			offered[String(rd.id)] = true
	_check(not offered.has("sovereign_seal") or _gm.is_relic_discovered("sovereign_seal"), "relics: undiscovered relics withheld")
	_check(not offered.has("plague_censer"), "relics: weapon-locked relics withheld")
	_check(offered.size() >= 5, "relics: a varied pool is offered")
	# Stat relic.
	var dmg0: float = _gm.might_mult()
	_check(r.add("kings_brand"), "relics: King's Brand taken")
	_check(is_equal_approx(_gm.might_mult(), dmg0 * 1.35), "relics: +35% damage")
	_check(_p.max_hp <= 1000000.0 * 0.75 + 1.0, "relics: -25% max HP applied")
	_check(not r.add("kings_brand"), "relics: no duplicates")
	_p.max_hp = 1000000.0
	_p.hp = _p.max_hp
	# Cinder Mantle: retaliation with a cooldown.
	r.add("cinder_mantle")
	var near = _foe(Vector2(60, 0))
	var n0: float = near.hp
	_p.take_damage(5.0, "test")
	_check(near.hp < n0, "relics: Cinder Mantle retaliates")
	n0 = near.hp
	_p.take_damage(5.0, "test")
	_check(is_equal_approx(near.hp, n0), "relics: Cinder Mantle respects its cooldown")
	# Grave Pact: every 15th kill, and its own kills do not count.
	r.add("grave_pact")
	var gp = null
	for fx in r.effects:
		if fx.id == "grave_pact":
			gp = fx
	for i in 14:
		var k = _foe(Vector2(-200, 200), 1.0)
		k.take_damage(5.0, k.global_position, 0.0, "dagger")
	_check(gp.kills == 14, "relics: Grave Pact counts kills")
	var k2 = _foe(Vector2(-200, 240), 1.0)
	k2.take_damage(5.0, k2.global_position, 0.0, "relic:grave_pact")
	_check(gp.kills == 14, "relics: Grave Pact ignores its own kills")
	var gp0 := int(_gm.run_stats.interaction_procs.get("relic:grave_pact", 0))
	var k3 = _foe(Vector2(-200, 280), 1.0)
	k3.take_damage(5.0, k3.global_position, 0.0, "dagger")
	_check(int(_gm.run_stats.interaction_procs.get("relic:grave_pact", 0)) == gp0 + 1, "relics: Grave Pact bursts on the 15th")
	# Ossuary Lens crits only on weapon hits.
	r.add("ossuary_lens")
	_check(_gm.mods.add("crit_chance") > 0.1, "relics: Ossuary Lens adds crit chance")
	# Smoldering Crown burns; burning ticks never stack the status.
	_gm.weapons["ember"] = 1
	r.add("smoldering_crown")
	var bt = _foe(Vector2(300, -300))
	bt.take_damage(1.0, bt.global_position, 0.0, "ember")
	var bt0: float = bt.hp
	r.tick(0.6)
	_check(bt.hp < bt0, "relics: Smoldering Crown burns")
	_check(float(bt.status["burning"]) <= 3.0, "relics: burn refreshes, never stacks")
	# Pearl of Ruin: gems become shards.
	r.add("pearl_of_ruin")
	var s0: int = _gm.run_shards
	for i in 30:
		r.on_gem(1)
	_check(_gm.run_shards == s0 + 1, "relics: Pearl of Ruin converts 30 gems")
	# Plague Censer: one generation of offspring clouds, capped.
	_gm.weapons["miasma"] = 1
	r.add("plague_censer")
	var cloud = load("res://src/projectile.gd").new()
	cloud.setup("miasma", 9.0, _p.global_position + Vector2(-400, -400))
	cloud.set("cloud_radius", 150.0)
	cloud.set("life", 5.0)
	_main.run.add_child(cloud)
	await _frames(1)
	for i in 6:
		var d = _foe(Vector2(-400, -400) + Vector2(i * 5, 0), 1.0)
		d.take_damage(5.0, d.global_position, 0.0, "miasma")
	await _frames(1)
	_check(get_tree().get_nodes_in_group("censer_clouds").size() == 3, "relics: censer clouds capped at 3")
	# Rime Coffer widens shatter reach.
	r.add("rime_coffer")
	_check(r.shatter_reach(90.0) >= 180.0, "relics: Rime Coffer widens shatters")
	# Iron Greaves: swift only while healthy.
	r.add("iron_greaves")
	r.tick(0.016)
	_check(is_equal_approx(_gm.mods.get_mod("relic:iron_greaves:swift", "speed"), 1.1), "relics: greaves swift when healthy")
	_p.hp = _p.max_hp * 0.5
	r.tick(0.016)
	_check(is_equal_approx(_gm.mods.get_mod("relic:iron_greaves:swift", "speed"), 1.0), "relics: greaves slow when hurt")
	_p.hp = _p.max_hp
	# Relics persist across a stage change but not into the next run. The
	# altar only appears for a stage actually cleared.
	_gm.stages_cleared = 1
	_main._advance_stage()
	await _frames(2)
	_check(_gm.has_relic("kings_brand") and r.effects.size() >= 5, "relics: kept between stages")
	_check(get_tree().get_nodes_in_group("relic_altars").size() == 1, "relics: a stage clear leaves one altar")
	_main.start_run()
	await _frames(2)
	_check(_gm.run_relics.is_empty() and not _gm.mods.has_source("relic:kings_brand"), "relics: cleared for a new run")
	# The altar: walking in opens a relic choice; choosing applies it.
	_gm.stages_cleared = 1
	_main._spawn_relic_altar()
	var alt = get_tree().get_nodes_in_group("relic_altars")[0]
	_main.player.global_position = alt.global_position
	await _frames(3)
	_check(_gm.state == _gm.State.CHEST and _main.loot_ui.visible, "altar: opens a choice")
	_check(_main.loot_ui.title.text == "RELIC ALTAR", "altar: titled as a relic altar")
	_check(_main.loot_ui.panel.get_child_count() == 3, "altar: three relics offered")
	var focus = get_viewport().gui_get_focus_owner()
	_check(focus is Button, "altar: choice is controller-focusable")
	(_main.loot_ui.panel.get_child(0) as Button).pressed.emit()
	await _frames(2)
	_check(_gm.state == _gm.State.RUNNING and _gm.run_relics.size() == 1, "altar: a chosen relic is held")
	_check(_gm.run_stats.relics.size() == 1, "altar: the run report lists it")
