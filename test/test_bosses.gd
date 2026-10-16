extends Node
# Every expansion boss: phases and thresholds, each attack's warning, the
# hazard budget, safe space under worst-case casting, signature mechanics and
# cleanup on death.

const STAGES := [0, 1, 2, 3, 5, 6, 7]

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
	_gm.forced_seed = 99
	for idx in STAGES:
		await _boss_suite(idx)
	await _signatures()
	_gm.forced_seed = -1
	print("BOSSES TEST DONE fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _spawn(idx: int):
	_gm.selected_stage = idx
	_main.start_run()
	await _frames(3)
	_main.intermission = 99999.0
	var p = _main.player
	p.max_hp = 100000000.0
	p.hp = p.max_hp
	_gm.run_time = _gm.RUN_DURATION - 0.02
	await _frames(3)
	var b = _main.boss
	# Hold the boss's own clock: the suite casts by hand.
	b._cast_t = 9999.0
	b.global_position = p.global_position + Vector2(420, 0)
	return b


func _clear_boss_hazards() -> void:
	for h in get_tree().get_nodes_in_group("boss_hazards"):
		h.remove_from_group("boss_hazards")
		h.remove_from_group("hazards")
		h.remove_from_group("timed_hazards")
		h.queue_free()


func _measure(ctl, label: String) -> void:
	var shapes := SafeSpace.threat_shapes(get_tree())
	var c: Vector2 = _main.player.global_position
	var f := SafeSpace.fraction(c, 420.0, shapes)
	_check(f >= ctl.data.min_safe_fraction, "%s keeps safe space (%.0f%%)" % [label, f * 100.0])
	_check(SafeSpace.nearest_safe(c, 230.0, shapes) != null, "%s leaves a reachable escape" % label)
	_check(ctl.budget_used() <= ctl.data.max_hazards, "%s within hazard budget (%d/%d)" % [label, ctl.budget_used(), ctl.data.max_hazards])
	for h in get_tree().get_nodes_in_group("boss_hazards"):
		if h is TimedHazard and h.is_threat() and h.total_age < 0.05:
			_check(h.warn_time >= 0.65, "%s warns >= 0.65s" % label)


func _boss_suite(idx: int) -> void:
	var b = await _spawn(idx)
	var ctl = b.controller
	var tag := String(ctl.data.id)
	_check(ctl != null, "%s: controller attached" % tag)
	_check(ctl.data.phases.size() >= 2, "%s: two or more phases" % tag)
	_check(ctl.phase_idx == 0, "%s: opens in phase one" % tag)
	var opener = ctl.pick_attack()
	_check(opener == ctl.attacks[0], "%s: each phase opens with its first attack" % tag)
	var n_atk := 0
	for ph in ctl.data.phases:
		n_atk += (ph as BossPhaseData).attacks.size()
	_check(n_atk >= 3, "%s: at least three attacks" % tag)
	for pi in ctl.data.phases.size():
		ctl.debug_set_phase(pi)
		_check(ctl.phase_idx == pi, "%s: phase %d entered" % [tag, pi + 1])
		# Each attack alone.
		for a in ctl.attacks.duplicate():
			_clear_boss_hazards()
			await _frames(1)
			ctl.pending = a
			a.dir = Vector2.LEFT
			a.telegraph()
			_check(a.warn_time() >= 0.65, "%s/%s: warning floor" % [tag, a.data.id])
			_measure(ctl, "%s/%s" % [tag, a.data.id])
			ctl.commit_cast()
			for k in 30:
				ctl.tick(0.1, Vector2.LEFT)
			b.global_position = _main.player.global_position + Vector2(420, 0)
		# Worst case: cast back to back with no recovery, budget permitting.
		_clear_boss_hazards()
		await _frames(1)
		var casts := 0
		for k in 8:
			var w: float = ctl.begin_cast(Vector2.LEFT)
			if w < 0.0:
				break
			casts += 1
			_measure(ctl, "%s phase %d stack %d" % [tag, pi + 1, k + 1])
			ctl.commit_cast()
		_check(casts >= 1, "%s phase %d: casting proceeds" % [tag, pi + 1])
		_check(ctl.budget_used() <= ctl.data.max_hazards, "%s phase %d: budget holds under stacking" % [tag, pi + 1])
	# Thresholds and enrage.
	ctl.debug_set_phase(0)
	b.hp = b.max_hp
	_check(ctl.phase_idx == ctl.data.phases.size() - 1, "%s: phases never step backwards" % tag)
	b.hp = b.max_hp * 0.2
	ctl.tick(0.016, Vector2.LEFT)
	_check(ctl.enraged, "%s: enrages when low" % tag)
	_check(ctl.cast_gap() >= ctl.data.min_cast_gap, "%s: enrage cadence floored" % tag)
	# Let anything mid-flight (a submerge) finish: the boss always comes back
	# up on its own, which is itself part of the contract.
	for k in 40:
		ctl.tick(0.1, Vector2.LEFT)
	_check(not ctl.submerged, "%s: never stays out of reach" % tag)
	# Death cleans up everything the boss owns.
	b.take_damage(9999999999.0, b.global_position, 0.0, "dagger")
	await _frames(3)
	var live := 0
	for g in ["boss_hazards", "boss_objects"]:
		for n in get_tree().get_nodes_in_group(g):
			if not n.is_queued_for_deletion():
				live += 1
	_check(live == 0, "%s: death clears boss hazards and objects" % tag)
	_check(_gm.stage != idx or _gm.state != _gm.State.RUNNING, "%s: death advances the run" % tag)


func _first_phase_transition(idx: int) -> void:
	var b = await _spawn(idx)
	var ctl = b.controller
	b.hp = b.max_hp * 0.51
	ctl.tick(0.016, Vector2.LEFT)
	_check(ctl.phase_idx == 0, "%s: still phase one above 50%%" % ctl.data.id)
	b.hp = b.max_hp * 0.49
	ctl.tick(0.016, Vector2.LEFT)
	_check(ctl.phase_idx == 1, "%s: phase two at 50%%" % ctl.data.id)
	_check(_main.hud.warn_label.text == ctl.data.phase(1).banner, "%s: phase banner shown" % ctl.data.id)


func _force(ctl, id: String):
	for a in ctl.attacks:
		if String(a.data.id) == id:
			ctl.pending = a
			a.dir = Vector2.LEFT
			a.telegraph()
			return a
	return null


func _signatures() -> void:
	for idx in STAGES:
		await _first_phase_transition(idx)
	var p
	# Herald: phase two relights its own cooled scars.
	var b = await _spawn(0)
	var ctl = b.controller
	var scar = _force(ctl, "targeted_scar")
	ctl.commit_cast()
	var scars: Array = []
	for h in get_tree().get_nodes_in_group("boss_hazards"):
		if h is TimedHazard and h.ignitable:
			scars.append(h)
	_check(not scars.is_empty(), "herald: targeted scars are ignitable")
	for h in scars:
		h.age = h.warn_time
		for k in 80:
			h._physics_process(0.05)
	var cooled := scars.filter(func(h): return is_instance_valid(h) and h.is_lingering())
	_check(not cooled.is_empty(), "herald: scars cool")
	ctl.debug_set_phase(1)
	_force(ctl, "ignite_scars")
	_check(cooled.any(func(h): return is_instance_valid(h) and h.phase == TimedHazard.Phase.WARN), "herald: ignite relights cooled scars")
	_clear_boss_hazards()
	_force(ctl, "gap_ring")
	var ring = null
	for h in get_tree().get_nodes_in_group("boss_hazards"):
		if h is TimedHazard and String(h.shape["kind"]) == "ring_gap":
			ring = h
	_check(ring != null and ring.rot_speed != 0.0, "herald: phase two ring rotates")
	# Maw: the tongue pulls, strain breaks it, the pull never beats walking.
	b = await _spawn(1)
	ctl = b.controller
	p = _main.player
	var tongue = _force(ctl, "tongue_pull")
	ctl.commit_cast()
	_check(tongue.is_running(), "maw: tether latches")
	_check(tongue.max_pull() < p.BASE_SPEED * _gm.speed_mult(), "maw: tether weaker than walking")
	p.move_vec = (p.global_position - b.global_position).normalized()
	for k in 30:
		tongue.tick(0.05)
		p.move_vec = (p.global_position - b.global_position).normalized()
	_check(not tongue.is_running(), "maw: pulling away breaks the tether")
	p.move_vec = Vector2.ZERO
	ctl.debug_set_phase(1)
	var sub = _force(ctl, "submerge")
	ctl.commit_cast()
	_check(ctl.submerged and not b.is_in_group("enemies"), "maw: submerged boss is out of reach")
	var hp_sub: float = b.hp
	b.take_damage(500.0, b.global_position, 0.0, "dagger")
	_check(is_equal_approx(b.hp, hp_sub), "maw: cannot be hit underwater")
	for k in 30:
		ctl.tick(0.1, Vector2.LEFT)
	_check(not ctl.submerged and b.is_in_group("enemies"), "maw: resurfaces")
	_force(ctl, "mire_growths")
	ctl.commit_cast()
	await _frames(1)
	_check(ctl.alive_spawned("mire_growth") >= 1, "maw: mire growths sprout")
	b.hp = b.max_hp * 0.4
	var h0: float = b.hp
	await _frames(20)
	_check(b.hp > h0, "maw: growths heal it until destroyed")
	# Cinder King: the decree ends in a punish window.
	b = await _spawn(2)
	ctl = b.controller
	ctl.debug_set_phase(1)
	_check(ctl.passives.size() == 1, "king: crown ignition trail in phase two")
	var dec = _force(ctl, "decree_pattern")
	ctl.commit_cast()
	var opened := false
	for k in 80:
		ctl.tick(0.1, Vector2.LEFT)
		if ctl.is_vulnerable():
			opened = true
			break
	_check(opened and not dec.is_running(), "king: the decree resolves into a recovery window")
	_check(ctl.vulnerable_mult >= 1.5 and ctl.stun_t > 0.0, "king: recovery window takes extra damage and holds him still")
	var hp_k: float = b.hp
	b.take_damage(100.0, b.global_position + Vector2(10, 0), 0.0, "dagger")
	_check(hp_k - b.hp >= 149.0, "king: punish window damage applies")
	# Pale Herald: armour plates.
	b = await _spawn(3)
	ctl = b.controller
	ctl.debug_set_phase(1)
	await _frames(1)
	var armor = ctl.passives[0]
	_check(armor.alive_plates() >= 2, "pale: bone armour assembles")
	var hp_a: float = b.hp
	b.take_damage(1000.0, b.global_position + Vector2(10, 0), 0.0, "dagger")
	_check(hp_a - b.hp <= 1000.0 * 0.31 * 2.0, "pale: armour soaks damage")
	for pl in armor.plates:
		if is_instance_valid(pl):
			pl.take_damage(99999999.0, pl.global_position, 0.0, "dagger")
	await _frames(1)
	armor.tick(0.016)
	_check(armor.exposed, "pale: breaking every plate exposes the weak point")
	var spears = null
	for a in ctl.attacks:
		if String(a.data.id) == "bone_spears":
			spears = a
	_check(spears.budget_cost() == int(spears.params["count"]), "pale: spears lose their enhancement with the armour")
	# Warden: shield and pillars.
	b = await _spawn(5)
	ctl = b.controller
	var wall = ctl.passives[0]
	for k in 60:
		wall.tick(0.05)
	p = _main.player
	var hp_w: float = b.hp
	b.take_damage(100.0, p.global_position, 0.0, "dagger")
	var front: float = hp_w - b.hp
	hp_w = b.hp
	b.take_damage(100.0, b.global_position * 2.0 - p.global_position, 0.0, "dagger")
	var back: float = hp_w - b.hp
	_check(front < back * 0.5, "warden: the shield blocks frontal hits, not flanking ones")
	# Drowned Maw: an anchor's death breaks its chain.
	b = await _spawn(6)
	ctl = b.controller
	var chain = _force(ctl, "anchor_drop")
	ctl.commit_cast()
	_check(chain.is_running(), "drowned maw: chain between anchors")
	for e in chain._anchors:
		e.take_damage(99999999.0, e.global_position, 0.0, "dagger")
		break
	await _frames(1)
	chain.tick(0.016)
	_check(not chain.is_running() and (chain._chain == null or not is_instance_valid(chain._chain) or chain._chain.phase == TimedHazard.Phase.DONE),
		"drowned maw: a fallen anchor drops the chain")
	# Sovereign: a major attack opens the core.
	b = await _spawn(7)
	ctl = b.controller
	ctl.debug_set_phase(1)
	_check(not ctl.is_vulnerable(), "sovereign: core closed by default")
	_force(ctl, "herald_ring")
	ctl.commit_cast()
	_check(ctl.is_vulnerable() and ctl.vulnerable_mult >= 1.6, "sovereign: major attacks expose the core")
	var motifs := {}
	for a in ctl.attacks:
		motifs[String(a.data.impl.resource_path).get_file()] = true
	_check(motifs.has("gap_ring.gd") and motifs.has("lane_charge.gd"), "sovereign: borrows the Herald's ring and the Maw's charge")
	_main.show_title()
	await _frames(1)
