class_name BossController
extends Node
# Runs a data-driven boss: phases, attack choice, cooldowns, the hazard
# budget, enrage and cleanup. It drives through the enemy's existing cast
# clock (_cast_t / _cast_phase in enemy.gd): the enemy asks begin_cast() for
# a wind-up and commit_cast() for the hit, so telegraph and impact can never
# drift apart.
#
# Invariants
# - An attack is only chosen if the live boss hazards plus its cost fit in
#   data.max_hazards. Enrage and the final stand shorten gaps; they never
#   raise the budget, so a faster boss is never a wider one.
# - The first cast of every phase is that phase's first attack, so a phase
#   always opens with its signature move.
# - No phase heals the boss or resets its health.
# - cleanup() removes every hazard and object the boss owns.

signal phase_changed(index: int)
signal major_committed(attack_id: String)

var boss = null
var data: BossData
var main = null
var gm = null
var rng := RandomNumberGenerator.new()
var phase_idx := -1
var attacks: Array = []
var passives: Array = []
var running: Array = []
var pending: BossAttack = null
var last_attack := ""
var casts_in_phase := 0
var cooldowns := {}
var clock := 0.0
var enraged := false
var final_stand := false
var vulnerable_t := 0.0
var vulnerable_mult := 1.0
var stun_t := 0.0
var submerged := false
# Bastion: closed portals thin the boss's reinforcements (1.0 = full).
var reinforcement_mult := 1.0
var spawned: Array = []

var _summon_t := 9.0
var _cleaned := false


func setup(p_boss, p_data: BossData, p_main) -> void:
	boss = p_boss
	data = p_data
	main = p_main
	gm = main.gm
	name = "BossController"
	rng.seed = abs(hash("%d:%s" % [gm.run_seed, String(data.id)]))
	_summon_t = data.summon_interval
	_enter_phase(0, true)


func phase() -> BossPhaseData:
	return data.phase(phase_idx)


func hp_frac() -> float:
	return clampf(boss.hp / maxf(boss.max_hp, 1.0), 0.0, 1.0)


func tick(delta: float, _dir: Vector2) -> void:
	if _cleaned:
		return
	clock += delta
	var f := hp_frac()
	while phase_idx + 1 < data.phases.size() and f <= data.phase(phase_idx + 1).threshold:
		_enter_phase(phase_idx + 1)
	if not enraged and f <= data.enrage_threshold:
		enraged = true
		_announce("ENRAGED")
	if not final_stand and data.final_stand_threshold > 0.0 and f <= data.final_stand_threshold:
		final_stand = true
		_announce("FINAL STAND")
		if main.jm:
			main.jm.add_trauma(0.5)
	if vulnerable_t > 0.0:
		vulnerable_t -= delta
		if vulnerable_t <= 0.0:
			vulnerable_mult = 1.0
	if stun_t > 0.0:
		stun_t -= delta
	for a in passives:
		a.tick(delta)
	for a in running.duplicate():
		a.tick(delta)
		if not a.is_running():
			running.erase(a)
	_summon_t -= delta
	if _summon_t <= 0.0:
		_summon_t = data.summon_interval * (0.7 if enraged else 1.0)
		_summon()


func _summon() -> void:
	var n := int(round(float(data.summon_count) * reinforcement_mult))
	for i in n:
		if main._enemy_count() >= main.MAX_ENEMIES:
			return
		var p: Vector2 = boss.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 160.0)
		main._spawn_enemy(String(data.summon_enemy), main.clamp_arena(p))


func _enter_phase(i: int, quiet := false) -> void:
	for a in passives:
		a.stop()
	passives.clear()
	attacks.clear()
	phase_idx = i
	casts_in_phase = 0
	var ph := phase()
	if ph == null:
		return
	for item in ph.attacks:
		var a := _make(item as BossAttackData)
		if a:
			attacks.append(a)
	for item in ph.passives:
		var a := _make(item as BossAttackData)
		if a:
			passives.append(a)
			a.start()
	if not quiet:
		if ph.banner != "":
			_announce(ph.banner)
		if main.jm:
			main.jm.add_trauma(0.45)
			main.jm.shockwave(boss.global_position, data.aura, 320.0)
		if main.lm:
			main.lm.flash(boss.global_position, data.aura, 2.6, 4.0, 0.5)
		if gm.run_stats:
			gm.run_stats.log_event("%s phase %d" % [data.display_name, i + 1])
	phase_changed.emit(i)


func _make(ad: BossAttackData) -> BossAttack:
	if ad == null or ad.impl == null:
		return null
	var a: BossAttack = ad.impl.new()
	a.init(self, ad)
	return a


func _announce(text: String) -> void:
	if main and main.hud:
		main.hud.show_warning(text)


# --- casting ---------------------------------------------------------------

func budget_used() -> int:
	var n := 0
	for h in get_tree().get_nodes_in_group("boss_hazards"):
		if h.has_method("is_threat"):
			if h.is_threat():
				n += 1
		else:
			n += 1
	return n


func can_afford(a: BossAttack) -> bool:
	return budget_used() + a.budget_cost() <= data.max_hazards


func pick_attack() -> BossAttack:
	var ready: Array = []
	for a in attacks:
		if clock >= float(cooldowns.get(String(a.data.id), 0.0)) and can_afford(a) and a.available():
			ready.append(a)
	if ready.is_empty():
		return null
	if casts_in_phase == 0 and not attacks.is_empty() and ready.has(attacks[0]):
		return attacks[0]
	if ready.size() > 1:
		for a in ready.duplicate():
			if String(a.data.id) == last_attack and ready.size() > 1:
				ready.erase(a)
	var total := 0.0
	for a in ready:
		total += maxf(0.01, a.data.weight)
	var roll := rng.randf() * total
	for a in ready:
		roll -= maxf(0.01, a.data.weight)
		if roll <= 0.0:
			return a
	return ready[-1]


func begin_cast(dir: Vector2) -> float:
	# Returns the wind-up length, or -1 if nothing fits the budget right now.
	if submerged or _cleaned:
		return -1.0
	var a := pick_attack()
	if a == null:
		return -1.0
	pending = a
	a.dir = dir if dir.length() > 0.1 else Vector2.RIGHT
	a.telegraph()
	return a.warn_time()


func commit_cast() -> float:
	if pending != null:
		var a := pending
		pending = null
		a.commit()
		last_attack = String(a.data.id)
		casts_in_phase += 1
		cooldowns[last_attack] = clock + a.data.cooldown
		if a.is_running() and not running.has(a):
			running.append(a)
		if a.data.major:
			major_committed.emit(last_attack)
		if gm.run_stats:
			gm.run_stats.add_proc("boss:" + last_attack)
	return cast_gap()


func cast_gap() -> float:
	var g := data.cast_gap
	var ph := phase()
	if ph:
		g *= ph.cadence
	if enraged:
		g *= data.enrage_cadence
	if final_stand:
		g *= data.final_stand_cadence
	return maxf(g, data.min_cast_gap)


func modify_damage(amount: float, from_pos: Vector2, source: String) -> float:
	var v := amount
	for a in passives:
		v = a.modify_damage(v, from_pos, source)
	if vulnerable_t > 0.0:
		v *= vulnerable_mult
	return v


func open_punish_window(t: float, mult: float) -> void:
	vulnerable_t = maxf(vulnerable_t, t)
	vulnerable_mult = maxf(vulnerable_mult, mult)


func is_vulnerable() -> bool:
	return vulnerable_t > 0.0


func untargetable() -> bool:
	return submerged


func speed_scale() -> float:
	return 0.0 if stun_t > 0.0 or submerged else 1.0


# --- ownership helpers -----------------------------------------------------

func spawn_hazard(shape: Dictionary, warn: float, active: float, dmg: float, attack_id: String) -> TimedHazard:
	var h := TimedHazard.new()
	h.setup(shape, maxf(warn, data.min_warn), active, dmg, data.aura,
		"boss:%s:%s" % [String(data.id), attack_id], "boss")
	main.add_hazard_node(h)
	return h


func own_object(n: Node) -> void:
	n.add_to_group("boss_objects")
	main.run.add_child(n)


func spawn_minion(etype: String, pos: Vector2, no_credit := false):
	if main._enemy_count() >= main.MAX_ENEMIES:
		return null
	var e = main._spawn_enemy(etype, main.clamp_arena(pos))
	if e:
		e.set("no_credit", no_credit)
		e.set("summoner", boss)
		spawned.append(e)
	return e


func alive_spawned(etype: String) -> int:
	var n := 0
	for e in spawned:
		if is_instance_valid(e) and not bool(e.get("dead")) and String(e.get("etype")) == etype:
			n += 1
	return n


func cleanup() -> void:
	if _cleaned:
		return
	_cleaned = true
	for a in passives + attacks + running:
		a.stop()
	passives.clear()
	running.clear()
	pending = null
	for g in ["boss_hazards", "boss_objects"]:
		for n in get_tree().get_nodes_in_group(g):
			n.remove_from_group(g)
			n.remove_from_group("hazards")
			n.queue_free()
	for e in spawned:
		if is_instance_valid(e) and bool(e.get("is_boss_object")):
			e.queue_free()
	spawned.clear()
	var p = main.player if main else null
	if p and is_instance_valid(p):
		p.set("push", Vector2.ZERO)


func _exit_tree() -> void:
	cleanup()


# --- debug -------------------------------------------------------------------

func debug_state() -> Dictionary:
	return {"boss": String(data.id), "phase": phase_idx, "hp": hp_frac(),
		"enraged": enraged, "final": final_stand, "budget": budget_used(),
		"max_budget": data.max_hazards, "running": running.size(),
		"vulnerable": vulnerable_t > 0.0, "submerged": submerged}


func debug_set_phase(i: int) -> void:
	var idx := clampi(i, 0, data.phases.size() - 1)
	var th := data.phase(idx).threshold
	# Drop health to the phase line rather than skipping it, so the phase
	# logic itself is what moves the fight on.
	if hp_frac() > th:
		boss.hp = boss.max_hp * th
	while phase_idx < idx:
		_enter_phase(phase_idx + 1)
