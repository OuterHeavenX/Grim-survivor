extends Node
# Stage rule lifecycles, scheduled events, hazard timing, safe space and
# cleanup for the seven expansion stages. Natural spawning is frozen (a long
# intermission) so each rule is driven directly and deterministically.

const STAGE := {"ashen": 0, "marsh": 1, "cinder": 2, "desert": 3, "sunken": 5, "drowned": 6, "bastion": 7}

var _fails := 0
var _gm = null
var _main = null


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
	_gm.selected_minutes = 30
	_gm.forced_seed = 4242
	await _ashen()
	await _marsh()
	await _cinder()
	await _desert()
	await _sunken()
	await _drowned()
	await _bastion()
	await _cleanup_paths()
	await _determinism()
	_gm.forced_seed = -1
	print("STAGE RULES TEST DONE fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _enter(key: String) -> StageRule:
	_gm.selected_stage = STAGE[key]
	_main.start_run()
	await _frames(3)
	_main.intermission = 99999.0
	var p = _main.player
	p.max_hp = 1000000.0
	p.hp = p.max_hp
	_check(_main.director != null and _main.director.rule != null, "%s: director runs a rule" % key)
	_check(_main.director.intro_text().length() > 0, "%s: rule has an intro line" % key)
	_check(_main.hud.card_title.text == _gm.stage_def().display_name, "%s: stage card names the stage" % key)
	return _main.director.rule


func _step(h, seconds: float) -> void:
	# Advance one hazard deterministically.
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < seconds and is_instance_valid(h) and h.phase != TimedHazard.Phase.DONE:
		h._physics_process(dt)
		t += dt


func _summon_boss() -> void:
	_gm.run_time = _gm.RUN_DURATION - 0.02
	await _frames(4)


func _safe_ok(min_frac: float, label: String) -> void:
	var shapes := SafeSpace.threat_shapes(get_tree())
	var c: Vector2 = _main.player.global_position
	var f := SafeSpace.fraction(c, 420.0, shapes)
	_check(f >= min_frac, "%s keeps %.0f%% safe (got %.0f%%)" % [label, min_frac * 100.0, f * 100.0])
	_check(SafeSpace.nearest_safe(c, 230.0, shapes) != null, "%s leaves a reachable safe spot" % label)


# --- Phase 1 ---------------------------------------------------------------

func _ashen() -> void:
	var r = await _enter("ashen")
	var p = _main.player
	_gm.run_time = 2.0
	_main.intermission = 0.0
	r.tick(0.016, 2.0)
	_check(get_tree().get_nodes_in_group("ash_scars").is_empty(), "ashen: nothing during the grace period")
	_main.intermission = 99999.0
	_gm.run_time = 30.0
	_check(r.spawn_single() == 1, "ashen: single scar placed")
	var near := INF
	for s in get_tree().get_nodes_in_group("ash_scars"):
		near = minf(near, s.global_position.distance_to(p.global_position))
	_check(near >= 150.0, "ashen: teaching scars land away from the player")
	# Warning harmless, eruption hurts, then cooled ground.
	var s := AshScar.make(r, p.global_position, r.scar_params())
	_check(s.warn_time >= TimedHazard.MIN_WARN, "ashen: scar warning >= 0.65s")
	var hp0: float = p.hp
	_step(s, s.warn_time - 0.05)
	_check(is_equal_approx(p.hp, hp0), "ashen: scar harmless while cracking and glowing")
	var foe = _main._spawn_enemy("husk", p.global_position + Vector2(20, 0))
	foe.max_hp = 99999.0
	foe.hp = 99999.0
	_step(s, 0.1)
	_check(s.is_damaging() or p.hp < hp0, "ashen: scar erupts on time")
	_check(p.hp < hp0, "ashen: eruption damages the player")
	_check(foe.hp < 99999.0, "ashen: eruption damages foes standing on it")
	var hp1: float = p.hp
	_step(s, 0.2)
	_check(is_equal_approx(p.hp, hp1), "ashen: one hit per eruption")
	_step(s, 0.6)
	_check(s.is_cooled(), "ashen: scar cools into ash")
	_check(not s.is_threat(), "ashen: cooled ash is harmless")
	_check(AshScar.on_cooled_ground(get_tree(), p.global_position, 70.0), "ashen: cooled ground detected")
	_check(not r._free_spot(p.global_position), "ashen: no new scar on cooled ground")
	foe.queue_free()
	# Linked and predicted patterns.
	r.intensity = 1
	_check(r.spawn_linked(true) > 0, "ashen: linked pattern placed")
	_safe_ok(r.data.min_safe_fraction, "ashen linked")
	r.clear_stage_hazards()
	r.intensity = 2
	_check(r.spawn_bands() == 5, "ashen: five eruption bands")
	_safe_ok(0.35, "ashen bands")
	var a1: Array = []
	for b in r.band_shapes():
		a1.append(b["pos"])
	_check(a1.size() == 5, "ashen: bands alternate")
	r.clear_stage_hazards()
	# Safety refusal: an arena already full of threats takes no more.
	for i in 12:
		r.spawn_hazard(HazardShape.circle(p.global_position + Vector2.from_angle(i * 0.52) * 120.0, 120.0), 2.0, 0.2, 1.0)
	_check(r.spawn_single() == 0 and r.spawn_bands() == 0, "ashen: refuses patterns that would close every escape")
	r.clear_stage_hazards()
	# Ashfall.
	_check(_main.director.debug_trigger_event("ashfall"), "ashen: ashfall event fires")
	_check(r._ashfall and _main.director.veil.target > 0.2, "ashen: ashfall dims the light")
	_check(r.interval() < float(r.p("interval_1", 2.6)), "ashen: ashfall raises eruption frequency")
	AshScar.make(r, p.global_position + Vector2(300, 0), r.scar_params())
	await _summon_boss()
	_check(_main.boss != null and _main.boss.controller != null, "ashen: Herald of Vorgath has a controller")
	_check(String(_main.boss.controller.data.id) == "herald_of_vorgath", "ashen: correct boss")
	_check(get_tree().get_nodes_in_group("stage_hazards").is_empty(), "ashen: stage scars cleared at the boss")
	_check(_main.director.veil.target == 0.0, "ashen: ashfall lifts for the boss")
	var hz0 := get_tree().get_nodes_in_group("stage_hazards").size()
	r.tick(0.016, 299.0)
	_check(get_tree().get_nodes_in_group("stage_hazards").size() == hz0, "ashen: no new scars during the boss")


# --- Phase 2 ---------------------------------------------------------------

func _marsh() -> void:
	var r = await _enter("marsh")
	var p = _main.player
	_check(r.islands.size() >= 5, "marsh: islands placed")
	_check(r.on_island(Vector2(0, -260)), "marsh: an island near the start")
	r.set_tide("high")
	p.global_position = r.islands[0]["pos"]
	r.apply_water()
	_check(not _gm.mods.has_source("stage:water"), "marsh: islands keep you dry at high water")
	var dry: float = _gm.speed_mult()
	p.global_position = Vector2(1400, 1400) if not r.on_island(Vector2(1400, 1400)) else Vector2(-1400, 1400)
	r.apply_water()
	_check(is_equal_approx(_gm.speed_mult(), dry * float(r.p("player_slow", 0.68))), "marsh: water slows the player")
	_gm.passives["boots"] = 2
	_check(is_equal_approx(_gm.speed_mult(), dry * 1.16 * float(r.p("player_slow", 0.68))),
		"marsh: water slow composes with Swift Boots")
	_gm.passives.erase("boots")
	var bog = _main._spawn_enemy("bogling", p.global_position + Vector2(40, 0))
	var titan = _main._spawn_enemy("titan", p.global_position + Vector2(-40, 0))
	var skel = _main._spawn_enemy("skeleton", p.global_position + Vector2(0, 40))
	_check(is_equal_approx(r.water_factor(bog), 1.0), "marsh: bog creatures ignore water")
	_check(is_equal_approx(r.water_factor(titan), float(r.p("resist_slow", 0.93))), "marsh: heavy foes resist water")
	_check(is_equal_approx(r.water_factor(skel), float(r.p("enemy_slow", 0.82))), "marsh: ordinary foes wade")
	_check(r.water_factor(skel) > float(r.p("player_slow", 0.68)), "marsh: foes slowed less than the player")
	r.set_tide("low")
	r.apply_water()
	_check(not _gm.mods.has_source("stage:water") and is_equal_approx(skel.env_speed, 1.0), "marsh: low water lifts the slow")
	for e in [bog, titan, skel]:
		e.queue_free()
	# First tide on schedule.
	_gm.run_time = 76.0
	await _frames(2)
	_check(_main.director.has_fired("first_tide") and r.tide != "low", "marsh: first tide arrives at 1:15")
	# Blooms: fire detonates one, its blast does not chain.
	var b1 = r.BloomScript.new()
	b1.rule = r
	b1.position = p.global_position + Vector2(200, 0)
	r.add_stage_object(b1)
	var b2 = r.BloomScript.new()
	b2.rule = r
	b2.position = p.global_position + Vector2(300, 0)
	r.add_stage_object(b2)
	await _frames(1)
	_main.director.emit_element("fire", b1.global_position, 20.0, "fireball")
	await _frames(1)
	_check(not is_instance_valid(b1), "marsh: fire detonates a bloom")
	var blast: TimedHazard = null
	for h in get_tree().get_nodes_in_group("timed_hazards"):
		if h.source == "stage:bloom":
			blast = h
	_check(blast != null and blast.warn_time >= 0.65, "marsh: bloom blast is telegraphed")
	_step(blast, 2.0)
	_check(is_instance_valid(b2), "marsh: a bloom blast never detonates its neighbour")
	_main.director.emit_element("frost", b2.global_position, 50.0, "frost")
	_check(is_instance_valid(b2), "marsh: only fire detonates blooms")
	# Fire through the real combat path.
	_main.combat.on_explosion(b2.global_position, 40.0, "ember")
	await _frames(1)
	_check(not is_instance_valid(b2), "marsh: an ember blast reaches the bloom via combat rules")
	_check(_main.director.debug_trigger_event("mire_bloom"), "marsh: mire bloom event")
	_check(r.spawn_blooms(3) > 0, "marsh: blooms rise in the water")
	for b in get_tree().get_nodes_in_group("blooms"):
		_check(not r.on_island(b.global_position), "marsh: blooms never sit on islands")
	await _summon_boss()
	_check(String(_main.boss.controller.data.id) == "maw_of_the_mire", "marsh: Maw of the Mire")
	_check(r.tide == "low" and get_tree().get_nodes_in_group("blooms").is_empty(), "marsh: tide settles for the boss")
	_check(r.island_points().size() >= 3, "marsh: islands remain for the arena")
	# Submerge never picks an invalid spot.
	var SubS = load("res://src/boss/attacks/submerge.gd")
	var ctl = _main.boss.controller
	var probe = SubS.new()
	var ad := BossAttackData.new()
	ad.params = {"candidates": 3, "min_player": 220.0}
	probe.init(ctl, ad)
	for trial in 5:
		for c in probe.candidates():
			_check(SubS.valid_spot(_main, c, p.global_position, 220.0), "marsh: submerge spot valid (trial %d)" % trial)
	_check(not SubS.valid_spot(_main, Vector2(1490, 0), Vector2.ZERO, 220.0), "marsh: edge spots rejected")
	_check(not SubS.valid_spot(_main, p.global_position, p.global_position, 220.0), "marsh: spots on the player rejected")


# --- Phase 3 ---------------------------------------------------------------

func _cinder() -> void:
	var r = await _enter("cinder")
	var p = _main.player
	var lane: TimedHazard = r.fire_furnace(0.0, 0.0, 1.1)
	_check(lane != null and get_tree().get_nodes_in_group("furnaces").size() == 1, "cinder: furnace fires a heat lane")
	_check(lane.warn_time >= 1.1, "cinder: lane warns before burning")
	# Blessing: stacks cap and refresh.
	for i in 5:
		r.grant_boon()
	_check(r.boon_stacks == 3, "cinder: blessing caps at 3 stacks")
	_check(is_equal_approx(_gm.mods.get_mod("stage:furnace_boon", "damage", 1.0), 1.3), "cinder: blessing damage")
	r.boon_left = 1.0
	r.grant_boon()
	_check(is_equal_approx(r.boon_left, float(r.p("boon_time", 6.0))), "cinder: a new stack refreshes the timer")
	r._tick_boon(7.0)
	_check(r.boon_stacks == 0 and not _gm.mods.has_source("stage:furnace_boon"), "cinder: blessing expires")
	# Standing behind an active furnace blesses once per furnace.
	var f = get_tree().get_nodes_in_group("furnaces")[0]
	p.global_position = f.boon_center()
	_step(lane, lane.warn_time + 0.05)
	f._physics_process(0.016)
	f._physics_process(0.016)
	_check(r.boon_stacks == 1, "cinder: behind an active furnace grants one stack")
	r.clear_stage_hazards()
	r._tick_boon(10.0)
	# Royal Decree.
	_check(_main.director.debug_trigger_event("royal_decree"), "cinder: royal decree fires")
	_check(r._decree_steps.size() == 4, "cinder: four decree waves scheduled")
	var safe0: int = r.decree_safe_quadrant()
	_check(r.fire_decree_wave() == 3, "cinder: decree burns three quadrants")
	_check(r.decree_safe_quadrant() == (safe0 + 1) % 4, "cinder: the safe quadrant turns")
	var shapes := SafeSpace.threat_shapes(get_tree())
	var safe_dir := Vector2.from_angle(PI * 0.5 * float(safe0) + PI * 0.25)
	_check(SafeSpace.is_safe(r._decree_center + safe_dir * 150.0, shapes), "cinder: decree leaves its quadrant open")
	_check(SafeSpace.nearest_safe(p.global_position, 230.0, shapes) != null, "cinder: decree escape within reach")
	r.clear_stage_hazards()
	await _summon_boss()
	var ctl = _main.boss.controller
	_check(String(ctl.data.id) == "the_cinder_king", "cinder: the Cinder King")
	_check(r._decree_steps.is_empty(), "cinder: decree stops for the boss")
	var cmd = _force(ctl, "furnace_command")
	_check(cmd != null and get_tree().get_nodes_in_group("boss_hazards").size() >= 1, "cinder: furnaces obey the king")


# --- Phase 4 ---------------------------------------------------------------

func _desert() -> void:
	var r = await _enter("desert")
	var p = _main.player
	_check(r.ribs.size() >= 6 and not _main.director.obstacles.is_empty(), "desert: fossil ribs stand")
	var rib: Dictionary = r.ribs[0]
	var mid: Vector2 = (Vector2(rib["pos"]) + Vector2(rib["to"])) * 0.5
	_check(r.sheltered(mid + r.wind * 120.0), "desert: the lee of a rib is shelter")
	_check(not r.sheltered(mid - r.wind * 120.0), "desert: the windward side is not")
	var pushed: Vector2 = _main.director.resolve(mid, 16.0)
	_check(pushed.distance_to(mid) > 10.0, "desert: ribs block movement")
	# Wind keeps pickups in bounds.
	r.start_storm()
	_check(_main.director.veil.target > 0.3, "desert: storms cut visibility")
	# The desert is wider than it is tall now; test against its real bounds.
	var half: Vector2 = _gm.arena_half
	var g = _main.spawn_gem(half - Vector2(20, 20), 1)
	for i in 120:
		r.apply_wind(0.1)
	for gem in get_tree().get_nodes_in_group("gems"):
		_check(absf(gem.position.x) <= half.x and absf(gem.position.y) <= half.y, "desert: wind never pushes pickups out")
	# Shelter cancels the shove.
	p.global_position = mid + r.wind * 120.0
	p.push = Vector2.ZERO
	r.apply_wind(0.016)
	_check(p.push.length() < 0.01, "desert: sheltered from the storm's push")
	p.global_position = mid - r.wind * 200.0
	r.apply_wind(0.016)
	_check(p.push.length() > 1.0, "desert: exposed to the storm's push")
	p.push = Vector2.ZERO
	r.end_storm()
	# Piles and revived dead.
	var pile = r.piles()[0]
	pile.fragments = 0
	var sk = _main._spawn_enemy("skeleton", pile.global_position + Vector2(30, 0))
	sk.take_damage(99999.0, sk.global_position, 0.0, "dagger")
	await _frames(1)
	_check(pile.fragments == 1, "desert: a skeletal death feeds a nearby pile")
	var gems0 := get_tree().get_nodes_in_group("gems").size()
	var kills0: int = _gm.kills
	var rev = _main._spawn_enemy("skeleton", pile.global_position + Vector2(-30, 0))
	rev.revived = true
	rev.no_credit = true
	rev.take_damage(99999.0, rev.global_position, 0.0, "dagger")
	await _frames(2)
	_check(get_tree().get_nodes_in_group("gems").size() == gems0, "desert: revived dead drop no XP")
	_check(_gm.kills == kills0, "desert: revived dead give no kill credit")
	_check(pile.fragments == 1, "desert: revived dead do not feed piles")
	pile.fragments = 3
	_check(pile.shatter() == 3 * int(r.p("pile_xp", 2)), "desert: shattering a pile pays XP per fragment")
	_check(pile.fragments == 0, "desert: a shattered pile is empty")
	_check(_main.director.debug_trigger_event("ossuary_storm"), "desert: ossuary storm fires")
	_check(r.pile_multiplier() == 2 and r.storm, "desert: ossuary storm doubles piles and holds the storm")
	pile.fragments = 2
	_check(r.take_pile_spots(pile.global_position, 2).size() == 2, "desert: piles feed the Pale Herald")
	await _summon_boss()
	_check(not r.storm and _main.director.veil.target == 0.0, "desert: the wind drops for the boss")
	_check(String(_main.boss.controller.data.id) == "the_pale_herald", "desert: the Pale Herald")


# --- Phase 5 ---------------------------------------------------------------

func _sunken() -> void:
	var r = await _enter("sunken")
	var p = _main.player
	for pt in r.road:
		_check(absf(pt.x) < 1450.0 and absf(pt.y) < 1450.0, "sunken: road inside the arena")
	p.global_position = r.convoy_pos() + Vector2(50, 0)
	var s0: float = r.convoy_s
	r.tick(1.0, 20.0)
	_check(r.convoy_s > s0, "sunken: convoy advances")
	_check(r.in_light(p.global_position) and _gm.mods.has_source("stage:lantern"), "sunken: lantern light protects")
	p.global_position = r.convoy_pos() + Vector2(1000, 0)
	s0 = r.convoy_s
	r.tick(1.0, 21.0)
	_check(is_equal_approx(r.convoy_s, s0), "sunken: convoy waits for a straggler")
	_check(not _gm.mods.has_source("stage:lantern"), "sunken: no protection outside the light")
	# Roadblock clears by timeout even if the wardens live.
	p.global_position = r.convoy_pos()
	r.intensity = 1
	r._start_roadblock()
	_check(r.paused_for == "roadblock", "sunken: roadblock halts the convoy")
	_check(get_tree().get_nodes_in_group("objectives").size() >= 1, "sunken: roadblock is an objective")
	r._tick_roadblocks(float(r.p("roadblock_timeout", 40.0)) + 1.0)
	_check(r.paused_for == "", "sunken: roadblock cannot block forever")
	# Shrines are optional and off the road.
	r._make_shrines()
	for sh in get_tree().get_nodes_in_group("shrines"):
		var on_road: Vector2 = r.road_point(r.road_progress(sh.global_position))
		_check(sh.global_position.distance_to(on_road) > 200.0, "sunken: shrine is a detour")
	# Bridge hold pauses with the game.
	_check(_main.director.debug_trigger_event("broken_bridge"), "sunken: broken bridge fires")
	var obj: StageObjective = r._bridge
	_check(obj != null and obj.kind == "hold", "sunken: bridge is a hold objective")
	p.global_position = obj.global_position
	await _frames(10)
	var prog: float = obj.progress
	_check(prog > 0.0, "sunken: holding fills progress")
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(obj.progress, prog), "sunken: objective pauses with the game")
	get_tree().paused = false
	await _frames(1)
	_check(_main.hud.objective_label.visible, "sunken: HUD shows the objective")
	_check(_main.hud.objective_label.text.begins_with("HOLD THE BRIDGE"), "sunken: HUD names the objective")
	obj.elapsed = obj.time_limit
	await _frames(2)
	_check(obj.state != "active" and r.paused_for == "", "sunken: a timed-out bridge releases the convoy")
	await _summon_boss()
	_check(String(_main.boss.controller.data.id) == "warden_of_the_road", "sunken: Warden of the Road")
	_check(r.gate_active, "sunken: the convoy forms the boss gate")
	var ctl = _main.boss.controller
	var pil = load("res://src/boss/attacks/pillars.gd")
	for trial in 4:
		var atk = _force(ctl, "roadblock_pillars")
		ctl.commit_cast()
		await _frames(1)
		for pl in get_tree().get_nodes_in_group("pillars"):
			_check(pl.global_position.distance_to(p.global_position) >= 160.0, "sunken: pillar clear of the player")
		_check(pil.open_directions(_main.director, p.global_position, []) >= 8, "sunken: pillars never trap the player (trial %d)" % trial)
	_check(get_tree().get_nodes_in_group("pillars").size() <= 4, "sunken: pillar count capped")


# --- Phase 6 ---------------------------------------------------------------

func _drowned() -> void:
	var r = await _enter("drowned")
	var p = _main.player
	_check(r.caches().size() >= 4 and r.low_tide(), "drowned: low tide bares the caches")
	var c = r.caches()[0]
	var gems0 := get_tree().get_nodes_in_group("gems").size()
	_check(c.open(), "drowned: a cache opens at low tide")
	await _frames(1)
	_check(get_tree().get_nodes_in_group("gems").size() > gems0, "drowned: the cache pays out")
	r.set_tide("warning")
	r.set_tide("high")
	_check(not c.can_open(), "drowned: caches are closed at high tide")
	r.set_tide("low")
	var gems1 := get_tree().get_nodes_in_group("gems").size()
	_check(not c.open() and get_tree().get_nodes_in_group("gems").size() == gems1, "drowned: an opened cache never refills")
	# Currents add to movement and are capped below walking speed.
	r.set_tide("warning")
	r.set_tide("high")
	var cur: Dictionary = r.currents[0]
	p.global_position = (Vector2(cur["from"]) + Vector2(cur["to"])) * 0.5
	p.push = Vector2.ZERO
	r.apply_currents()
	_check(p.push.length() > 1.0, "drowned: a current carries the player")
	await _frames(1)
	var walk: float = p.BASE_SPEED * _gm.speed_mult()
	p.add_push(Vector2(5000, 0))
	await _frames(1)
	_check(p.velocity.length() <= walk * p.MAX_PUSH_SHARE + 1.0, "drowned: outside forces never exceed the cap")
	_check(_main.director.debug_trigger_event("dead_tide"), "drowned: the dead tide rises")
	_check(r._reversals.size() == 2, "drowned: currents reverse twice")
	var sign0: float = r.currents[0]["sign"]
	r.reverse_currents()
	_check(r.currents[0]["sign"] == -sign0, "drowned: reversal flips the flow")
	r.clear_stage_hazards()
	var n: int = r.sail_ship()
	_check(n > 0 and n <= int(r.p("broadside", 7)), "drowned: a ghost ship fires a marked broadside")
	for h in get_tree().get_nodes_in_group("stage_hazards"):
		_check(h.warn_time >= 1.2, "drowned: broadside warns 1.2s+")
	_safe_ok(0.35, "drowned broadside")
	await _summon_boss()
	var ctl = _main.boss.controller
	_check(String(ctl.data.id) == "the_drowned_maw", "drowned: the Drowned Maw")
	_check(r.ring_active and r.currents.is_empty(), "drowned: the water rings the boss arena")
	ctl.debug_set_phase(1)
	var wp = null
	for a in ctl.passives:
		if a.has_method("strength"):
			wp = a
	_check(wp != null, "drowned: whirlpool in phase two")
	for i in 4:
		ctl.spawn_minion("anchor", p.global_position + Vector2(300 + i * 40, 0), true)
	await _frames(1)
	_check(wp.strength() <= walk * wp.ESCAPE_SHARE + 0.01, "drowned: whirlpool always escapable")
	var weak: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if String(e.etype) == "anchor":
			e.take_damage(999999.0, e.global_position, 0.0, "dagger")
	await _frames(1)
	weak = wp.strength()
	_check(weak <= float(wp.pf("pull", 95.0)) + 0.01, "drowned: sinking anchors weakens the pull")


# --- Phase 7 ---------------------------------------------------------------

func _bastion() -> void:
	var r = await _enter("bastion")
	var p = _main.player
	_check(r.wards.size() == 3, "bastion: three wards")
	var w = r.wards[0]
	w.light()
	_check(w.state == "active" and _gm.mods.has_source("stage:ward:" + w.kind), "bastion: a lit ward grants its boon")
	_check(not r.wards[1].activatable, "bastion: the first choice locks the others until 1:15")
	r.on_intensity(1)
	_check(r.wards[1].activatable, "bastion: more wards open at 1:15")
	_check(r.spawn_legacy_scar() == 1 and not get_tree().get_nodes_in_group("ash_scars").is_empty(),
		"bastion: the Hollow's scars return via AshScar")
	r.clear_stage_hazards()
	w.damage(99999.0)
	_check(w.state == "lost" and not _gm.mods.has_source("stage:ward:" + w.kind), "bastion: a lost ward takes its boon")
	r.wards[1].light()
	_check(_main.director.debug_trigger_event("final_siege"), "bastion: final siege")
	var portals: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if String(e.etype) == "siege_portal":
			portals.append(e)
	_check(portals.size() == 3, "bastion: three siege portals")
	for i in 2:
		portals[i].take_damage(999999.0, portals[i].global_position, 0.0, "dagger")
	await _frames(1)
	_check(r.portals_closed == 2, "bastion: closed portals counted")
	_check(is_equal_approx(r.reinforcement_for(2, 3), 0.5), "bastion: reinforcement math is deterministic")
	_check(is_equal_approx(r.reinforcement_for(0, 3), 1.0) and is_equal_approx(r.reinforcement_for(3, 3), 0.25),
		"bastion: reinforcement bounds")
	await _summon_boss()
	var ctl = _main.boss.controller
	_check(String(ctl.data.id) == "the_ashen_sovereign", "bastion: the Ashen Sovereign")
	_check(is_equal_approx(ctl.reinforcement_mult, 0.5), "bastion: portals thin the Sovereign's reinforcements")
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if String(e.etype) == "siege_portal":
			alive += 1
	await _frames(1)
	var hp0: float = _main.boss.hp
	r._fire_t = 0.0
	r.boss_tick(0.016)
	_check(_main.boss.hp < hp0, "bastion: surviving wards fire on the Sovereign")
	_main.boss.hp = _main.boss.max_hp * 0.1
	ctl.tick(0.016, Vector2.RIGHT)
	_check(ctl.final_stand and ctl.phase_idx == 1, "bastion: final stand below 15%")
	_check(ctl.cast_gap() >= ctl.data.min_cast_gap, "bastion: final stand cadence is capped")
	var hp1: float = _main.boss.hp
	ctl.tick(0.5, Vector2.RIGHT)
	_check(_main.boss.hp <= hp1, "bastion: no healing reset")


# --- cleanup ---------------------------------------------------------------

func _populate(r) -> Node:
	return r.spawn_hazard(HazardShape.circle(_main.player.global_position + Vector2(200, 0), 60.0), 2.0, 0.3, 1.0)


func _gone(n) -> bool:
	return n == null or not is_instance_valid(n) or n.is_queued_for_deletion()


func _leftovers() -> int:
	var n := 0
	for g in ["stage_hazards", "boss_hazards", "stage_objects", "boss_objects", "pillars", "blooms", "wards"]:
		for x in get_tree().get_nodes_in_group(g):
			if not x.is_queued_for_deletion():
				n += 1
	return n


func _cleanup_paths() -> void:
	# Stage transition is covered per stage above; here: restart, death,
	# victory and title, each from a populated stage.
	var r = await _enter("marsh")
	var old_h = _populate(r)
	var old_field = r._field
	_main.start_run()
	await _frames(2)
	_check(_gone(old_h) and _gone(old_field), "cleanup: restart frees the old stage's hazards and props")
	r = _main.director.rule
	_populate(r)
	_main.show_title()
	await _frames(2)
	_check(_leftovers() == 0, "cleanup: return to title leaves nothing")
	r = await _enter("cinder")
	_populate(r)
	_main.player.take_damage(99999999.0)
	await _frames(2)
	_check(get_tree().get_nodes_in_group("stage_hazards").filter(func(x): return not x.is_queued_for_deletion()).is_empty(),
		"cleanup: death clears stage hazards")
	_check(_gm.mods.sources().filter(func(s): return String(s).begins_with("stage:")).is_empty(), "cleanup: death clears stage boons")
	r = await _enter("drowned")
	_populate(r)
	_gm.stages_cleared = _gm.stages_in_run() - 1
	await _summon_boss()
	_main.boss.take_damage(999999999.0, _main.boss.global_position, 0.0, "dagger")
	await _frames(3)
	_check(_gm.state == _gm.State.VICTORY, "cleanup: victory reached")
	_check(get_tree().get_nodes_in_group("stage_hazards").filter(func(x): return not x.is_queued_for_deletion()).is_empty()
		and get_tree().get_nodes_in_group("boss_hazards").filter(func(x): return not x.is_queued_for_deletion()).is_empty(),
		"cleanup: victory clears stage and boss hazards")
	_main.show_title()
	await _frames(2)


func _determinism() -> void:
	# The same run seed lays the same stage out.
	_gm.forced_seed = 777
	var r = await _enter("marsh")
	var a: Array = []
	for i in r.islands:
		a.append(i["pos"])
	_check(_gm.run_seed == 777, "seed: the forced run seed is used")
	r = await _enter("marsh")
	var b: Array = []
	for i in r.islands:
		b.append(i["pos"])
	_check(a == b, "seed: identical seeds give identical layouts")
	_gm.forced_seed = 778
	r = await _enter("marsh")
	var c: Array = []
	for i in r.islands:
		c.append(i["pos"])
	_check(a != c, "seed: a different seed changes the layout")
	_check(_gm.run_stats.run_seed == 778, "seed: recorded for the post-run report")
	_main.show_title()
	await _frames(1)


func _force(ctl, attack_id: String):
	# Cast one named attack now, through the normal telegraph path.
	for a in ctl.attacks:
		if String(a.data.id) == attack_id:
			ctl.pending = a
			a.dir = Vector2.RIGHT
			a.telegraph()
			return a
	return null
