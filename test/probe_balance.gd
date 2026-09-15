extends Node

# Balance measurement. Not an asserting suite -- run_tests.sh does not pick this
# up; it prints numbers to reason about.
#
#   godot --headless --path .   (with this injected into [autoload])
#
# Weapon DPS is measured by stepping the weapon system and its projectiles by
# hand with the tree paused, rather than watching a live run. A live run is
# bound to real time and headless here is ~9x slower than real time, which puts
# a thirteen-weapon sweep into the hours. Stepping manually is both far faster
# and deterministic, which matters more: two runs of the same build must give
# the same number or a tuning change cannot be told apart from noise.

const DT := 1.0 / 60.0
const SECS := 12.0
const DUMMY_HP := 5_000_000.0
const RING := 12
const TRIALS := 3

var _main = null
var _gm = null
var _player = null
var _w = null
var _phase := 0
var _wait := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_main = get_tree().get_first_node_in_group("main")
	_gm = get_node("/root/GameManager")
	_gm.selected_minutes = 30
	_main.start_run()
	set_process(true)


func _is_shot(n) -> bool:
	var sc = n.get_script()
	return sc != null and str(sc.resource_path).ends_with("projectile.gd")


func _shots() -> Array:
	# Orbitals (blades, scythe) hang off the player, not off run, so a scan of
	# run alone reports them as doing no damage at all.
	var out: Array = []
	for c in _main.run.get_children():
		if is_instance_valid(c) and _is_shot(c):
			out.append(c)
	for root in [_w.blades_root, _w.scythe_root]:
		if root != null and is_instance_valid(root):
			for c in root.get_children():
				if is_instance_valid(c):
					out.append(c)
	return out


func _clear() -> void:
	for c in _main.run.get_children():
		if _is_shot(c) or c.is_in_group("enemies"):
			_main.run.remove_child(c)
			c.free()
	# Orbitals outlive a measurement, so the next weapon would be credited with
	# the previous one's blades still spinning.
	for root in [_w.blades_root, _w.scythe_root]:
		if root != null and is_instance_valid(root):
			for c in root.get_children():
				root.remove_child(c)
				c.free()


func _dummies() -> Array:
	# A ring at a fixed radius: close enough that every weapon's range reaches,
	# spread so cones and rings are not unfairly rewarded or punished.
	# Spread across the band a swarm actually occupies rather than a single
	# radius. A fixed 150px ring sat outside the blades' 95px orbit and scored
	# them at zero while flattering anything ranged.
	const RADII := [70.0, 130.0, 190.0, 250.0]
	var out: Array = []
	for i in RING:
		var a := TAU * float(i) / float(RING)
		var r: float = RADII[i % RADII.size()]
		var e = _main._spawn_enemy("skeleton", _player.global_position + Vector2.from_angle(a) * r)
		e.max_hp = DUMMY_HP
		e.hp = DUMMY_HP
		e.speed = 0.0
		out.append(e)
	return out


func _measure(id: String, lvl: int) -> float:
	# Comet, ember and fireball place their hits randomly, so a single trial
	# swings ~17% run to run -- enough to mistake noise for a tuning change.
	# Seed each trial and average, so the number is both reproducible and not
	# over-fitted to one lucky scatter.
	var total := 0.0
	for trial in TRIALS:
		seed(1000 + trial)
		total += _measure_once(id, lvl)
	return total / float(TRIALS)


func _measure_once(id: String, lvl: int) -> float:
	_clear()
	_gm.weapons = {id: lvl}
	_gm.passives = {}
	var foes := _dummies()
	_w.timers = {}
	if _w.has_method("_on_weapons_changed"):
		_w._on_weapons_changed()
	var steps := int(SECS / DT)
	for s in steps:
		_w._physics_process(DT)
		for p in _shots():
			if is_instance_valid(p) and not p.is_queued_for_deletion():
				p._physics_process(DT)
		# queue_free() is processed at the end of a frame, and this whole sweep
		# runs inside one frame, so expired shots would never actually go --
		# they would pile up, keep being stepped, and eat the machine. (The
		# first run of this probe was OOM-killed doing exactly that.) Reaping
		# them here is what the engine would have done between frames.
		for p in _shots():
			if is_instance_valid(p) and p.is_queued_for_deletion():
				var par = p.get_parent()
				if par != null:
					par.remove_child(p)
				p.free()
	var total := 0.0
	for e in foes:
		if is_instance_valid(e):
			total += DUMMY_HP - float(e.hp)
	return total / SECS


func _process(_delta: float) -> void:
	_wait += 1
	if _phase != 0 or _wait < 6:
		return
	_phase = 1
	_player = _main.player
	_w = _player.get_node("Weapons")
	_player.set("max_hp", 1e9)
	_player.set("hp", 1e9)
	get_tree().paused = true

	var ids: Array = []
	for id in _gm.WEAPONS.keys():
		ids.append(str(id))
	ids.sort()

	print("=== WEAPON DPS (level 1 / level 5, %d dummies, %.0fs) ===" % [RING, SECS])
	var l1 := {}
	var l5 := {}
	for id in ids:
		var t0 := Time.get_ticks_msec()
		l1[id] = _measure(id, 1)
		l5[id] = _measure(id, 5)
		print("DPS %-9s L1=%9.1f  L5=%9.1f  growth=%4.2fx  (%dms)" % [
			id, l1[id], l5[id], (l5[id] / maxf(1.0, l1[id])),
			Time.get_ticks_msec() - t0])

	_summary("L1", l1)
	_summary("L5", l5)

	print("=== ENEMY SCALING ===")
	for st in _gm.STAGES.size():
		var hp_m: float = _gm.enemy_hp_mult(st, 0.0)
		var dmg_m: float = _gm.enemy_dmg_mult(st, 0.0)
		var late_hp: float = _gm.enemy_hp_mult(st, 300.0)
		print("stage %d  hp x%.2f (x%.2f at 5min)  dmg x%.2f  boss hp %.0f" % [
			st + 1, hp_m, late_hp, dmg_m,
			float(_gm.STAGES[st]["boss"] == "herald") * 0.0
				+ _boss_hp(str(_gm.STAGES[st]["boss"])) * late_hp])

	print("=== INCOMING DAMAGE ===")
	# Each touching enemy hits on its own 0.7s timer, so pressure is per-enemy
	# DPS times however many reach you. Compared against a player who has taken
	# every HP upgrade going: 100 base + 100 from Vitality + 60 from meta.
	var E = load("res://src/enemy.gd")
	var maxed_hp := 260.0
	for st in _gm.STAGES.size():
		var dmg_m: float = _gm.enemy_dmg_mult(st, 300.0)
		var pool: Array = _gm.STAGES[st]["pool"]
		var worst := 0.0
		for et in pool:
			worst = maxf(worst, float(E.TYPES[str(et)]["dmg"]) * dmg_m)
		var per_foe := worst / 0.9
		print("stage %d  worst contact %5.1f  per-foe DPS %5.1f  3 foes kill a maxed player in %4.1fs" % [
			st + 1, worst, per_foe, maxed_hp / maxf(0.1, per_foe * 3.0)])

	get_tree().paused = false
	print("PROBE DONE")
	get_tree().quit(0)


func _boss_hp(etype: String) -> float:
	var E = load("res://src/enemy.gd")
	return float(E.TYPES[etype]["hp"])


func _summary(tag: String, d: Dictionary) -> void:
	var lo := 1e18
	var hi := 0.0
	var lo_id := ""
	var hi_id := ""
	var sum := 0.0
	for id in d:
		var v: float = d[id]
		sum += v
		if v < lo:
			lo = v
			lo_id = str(id)
		if v > hi:
			hi = v
			hi_id = str(id)
	print("%s spread: worst %s %.0f, best %s %.0f, ratio %.1fx, mean %.0f" % [
		tag, lo_id, lo, hi_id, hi, hi / maxf(1.0, lo), sum / float(d.size())])
