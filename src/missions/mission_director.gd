class_name MissionDirector
extends Node
# Side missions and horde surges inside a stage. Missions are offered a few at
# a time between the stage's own events; each has a time limit, so none can
# hold the boss back, and each pays out on success. Surges are short spikes
# of the horde between missions.
#
#   hold    - HOLD THE SHRINE: stand in a zone while the horde converges.
#   cull    - CULL THE HORDE: a wave arrives; kill N before time runs out.
#   marked  - SLAY THE MARKED: one elite carries a reticle; kill it.
#   thief   - CATCH THE SOUL THIEF: a fleeing thief with a sack of shards.
#   totems  - CLEANSE THE TOTEMS: stand by three obelisks to break them.
#
# Invariants
# - At most one mission at a time, and none while a stage rule's own
#   objective is running.
# - Nothing is offered in the last 35 s before the boss, or during it.
# - Everything spawned is a stage object, so stage cleanup removes it.

const ObjectiveScript := preload("res://src/stage/stage_objective.gd")
const TotemScript := preload("res://src/missions/totem.gd")

const KINDS := ["hold", "cull", "marked", "thief", "totems"]
const LABELS := {
	"hold": "HOLD THE SHRINE", "cull": "CULL THE HORDE", "marked": "SLAY THE MARKED",
	"thief": "CATCH THE SOUL THIEF", "totems": "CLEANSE THE TOTEMS",
}
const FIRST_OFFER := 30.0
const SURGE_TIMES := [70.0, 160.0, 240.0]
const SURGE_LENGTH := 10.0

var main = null
var gm = null
var rng := RandomNumberGenerator.new()
var current: Dictionary = {}
var next_offer := FIRST_OFFER
var completed := 0
var failed := 0
var surges_fired := {}
var surge_left := 0.0
var _last_kind := ""
var _hold_spawn := 0.0
var enabled := true


func setup(p_main, seed_value: int) -> void:
	main = p_main
	gm = main.gm
	rng.seed = seed_value ^ 0x5eed
	name = "Missions"


func tick(delta: float, t: float) -> void:
	if not enabled:
		return
	_tick_surges(delta, t)
	if current.is_empty():
		if t >= next_offer and t < gm.RUN_DURATION - 35.0:
			if _rule_objective_active():
				next_offer = t + 5.0
			else:
				_offer(t)
		return
	_tick_current(delta)


# --- surges ------------------------------------------------------------------

func _tick_surges(delta: float, t: float) -> void:
	if surge_left > 0.0:
		surge_left -= delta
		if surge_left <= 0.0:
			var p = main.player
			if p and is_instance_valid(p) and bool(p.get("alive")):
				gm.lifetime_surges += 1
				main.hud.show_warning("SURGE BROKEN")
				for i in 3:
					main.spawn_shard(main.clamp_arena(p.global_position + Vector2.from_angle(rng.randf() * TAU) * 70.0), 1)
		return
	for st in SURGE_TIMES:
		if t >= st and not surges_fired.has(st) and t < gm.RUN_DURATION - 20.0:
			surges_fired[st] = true
			start_surge(t)
			return


func start_surge(t: float) -> void:
	var p = main.player
	if p == null or not is_instance_valid(p):
		return
	surge_left = SURGE_LENGTH
	main.hud.show_warning("THE HORDE SURGES")
	main.am.play("elite_horn", -4.0, 0.8)
	main.jm.add_trauma(0.3)
	var n := 14 + 3 * int(gm.stage) + int(t / 60.0) * 2
	_ring_wave(p.global_position, n, 520.0, 680.0)


func is_surging() -> bool:
	return surge_left > 0.0


func _ring_wave(center: Vector2, n: int, rmin: float, rmax: float) -> void:
	var pool: Array = gm.stage_data()["pool"]
	if pool.is_empty():
		return
	var base := rng.randf() * TAU
	for i in n:
		if main._enemy_count() >= main.MAX_ENEMIES:
			return
		var ang := base + TAU * float(i) / float(n) + rng.randf_range(-0.15, 0.15)
		var pos: Vector2 = main.clamp_arena(center + Vector2.from_angle(ang) * rng.randf_range(rmin, rmax), 30.0)
		main._spawn_enemy(str(pool[rng.randi() % pool.size()]), pos)


# --- missions ----------------------------------------------------------------

func _rule_objective_active() -> bool:
	for o in get_tree().get_nodes_in_group("objectives"):
		if o.has_method("is_active") and o.is_active() and not o.has_meta("mission"):
			return true
	return false


func _spot(rmin: float, rmax: float) -> Vector2:
	var p: Vector2 = main.player.global_position
	var best := p
	for i in 14:
		var c: Vector2 = main.clamp_arena(p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(rmin, rmax), 200.0)
		best = c
		if main.director == null or not main.director.blocked(c, 120.0):
			return c
	return best


func _offer(t: float) -> void:
	var p = main.player
	if p == null or not is_instance_valid(p) or not bool(p.get("alive")):
		next_offer = t + 5.0
		return
	var choices: Array = KINDS.duplicate()
	choices.erase(_last_kind)
	start(str(choices[rng.randi() % choices.size()]))


func start(kind: String) -> Dictionary:
	_last_kind = kind
	var obj = ObjectiveScript.new()
	obj.set_meta("mission", kind)
	obj.label = LABELS[kind]
	obj.kind = "manual"
	obj.color = Color(1.0, 0.75, 0.3)
	current = {"kind": kind, "obj": obj}
	match kind:
		"hold":
			obj.kind = "hold"
			obj.radius = 150.0
			obj.goal = 8.0
			obj.decay = 0.4
			obj.time_limit = 40.0
			obj.position = _spot(420.0, 650.0)
			_hold_spawn = 1.0
		"cull":
			obj.goal = float(30 + 3 * int(gm.stage))
			obj.time_limit = 24.0
			obj.position = main.player.global_position
			_ring_wave(main.player.global_position, 18 + 2 * int(gm.stage), 480.0, 640.0)
		"marked":
			obj.goal = 1.0
			obj.time_limit = 35.0
			obj.position = main.player.global_position
			var pool: Array = gm.stage_data()["pool"]
			var e = main._spawn_enemy(str(pool[rng.randi() % pool.size()]), _spot(560.0, 720.0))
			if e:
				e.make_elite()
				e.set_meta("marked", true)
				current["target"] = e
		"thief":
			obj.goal = 1.0
			obj.time_limit = 22.0
			obj.position = main.player.global_position
			var e = main._spawn_enemy("soul_thief", _spot(380.0, 480.0))
			if e:
				e.add_to_group("elites")   # off-screen arrow points at it
				current["target"] = e
		"totems":
			obj.goal = 3.0
			obj.time_limit = 45.0
			var c := _spot(480.0, 700.0)
			obj.position = c
			var base := rng.randf() * TAU
			for i in 3:
				var tt = TotemScript.new()
				tt.main = main
				tt.position = main.clamp_arena(c + Vector2.from_angle(base + TAU * float(i) / 3.0) * 240.0, 120.0)
				if main.director:
					tt.position = main.director.resolve(tt.position, 60.0)
				tt.cleansed.connect(func (_t) -> void: obj.add_progress(1.0))
				main.run.add_child(tt)
	obj.completed.connect(_on_completed)
	obj.failed.connect(_on_failed)
	main.run.add_child(obj)
	var lm = main.lm
	if lm and kind in ["hold", "totems"]:
		lm.attach_aura(obj, Color(1.0, 0.75, 0.3), 3.0, 0.8)
	main.hud.show_warning("MISSION: " + LABELS[kind])
	main.am.play("boss_warning_horn", -12.0, 1.4)
	return current


func _tick_current(delta: float) -> void:
	var obj = current.get("obj")
	if obj == null or not is_instance_valid(obj):
		current = {}
		return
	match str(current["kind"]):
		"hold":
			if obj.player_inside():
				_hold_spawn -= delta
				if _hold_spawn <= 0.0:
					_hold_spawn = 1.1
					_ring_wave(obj.global_position, 2, 380.0, 460.0)
		"cull":
			obj.position = main.player.global_position
		"marked", "thief":
			var e = current.get("target")
			if e == null or not is_instance_valid(e):
				# Killed by anything counts; vanished without dying does not.
				if obj.is_active() and bool(current.get("target_died", false)):
					obj.add_progress(1.0)
				elif obj.is_active():
					obj.state = "failed"
					_on_failed(obj)


func on_enemy_died(e) -> void:
	if current.is_empty():
		return
	match str(current["kind"]):
		"cull":
			var obj = current["obj"]
			if obj and is_instance_valid(obj):
				obj.add_progress(1.0)
		"marked", "thief":
			if e == current.get("target"):
				current["target_died"] = true
				current["died_at"] = e.global_position


func _on_completed(obj) -> void:
	var kind := str(current.get("kind", ""))
	completed += 1
	gm.lifetime_missions += 1
	if kind == "thief":
		gm.lifetime_thieves += 1
	if gm.run_stats:
		gm.run_stats.log_event("mission %s done" % kind)
	var at: Vector2 = current.get("died_at", main.player.global_position if main.player else Vector2.ZERO)
	var reward := _reward(kind, at)
	main.hud.show_warning("MISSION COMPLETE — " + reward)
	main.am.play("victory_sting", -8.0, 1.2)
	main.jm.gold_burst(at)
	_finish(obj, true)


func _on_failed(obj) -> void:
	failed += 1
	var kind := str(current.get("kind", ""))
	if kind == "thief":
		var e = current.get("target")
		if e and is_instance_valid(e):
			main.jm.shockwave(e.global_position, Color(1.0, 0.8, 0.3), 120.0)
			e.set("no_credit", true)
			e.queue_free()
	main.hud.show_warning("MISSION FAILED")
	_finish(obj, false)


func _finish(obj, _ok: bool) -> void:
	for t in get_tree().get_nodes_in_group("mission_totems"):
		t.queue_free()
	var e = current.get("target")
	if e and is_instance_valid(e) and e.has_meta("marked"):
		e.remove_meta("marked")
	current = {}
	next_offer = gm.run_time + rng.randf_range(20.0, 28.0)
	if obj and is_instance_valid(obj):
		obj.remove_from_group("objectives")
		obj.queue_free()


# What a mission pays. The Soul Thief always pays in shards and a chest; the
# others draw from a table weighted toward what helps right now.
func _reward(kind: String, at: Vector2) -> String:
	var p = main.player
	if kind == "thief":
		for i in 8 + 2 * int(gm.stage):
			main.spawn_shard(main.clamp_arena(at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, 70.0)), 1)
		main.spawn_chest(main.clamp_arena(at))
		return "STOLEN SOULS AND A CHEST"
	var hurt: bool = p != null and float(p.get("hp")) < float(p.get("max_hp")) * 0.6
	var roll := rng.randf()
	if hurt and roll < 0.45:
		p.heal(float(p.get("max_hp")) * 0.4)
		return "WOUNDS MENDED"
	if roll < 0.55:
		main.spawn_chest(main.clamp_arena(at + Vector2(0, -80)))
		return "A CHEST"
	if roll < 0.75:
		main._vacuum_all()
		return "EVERY GEM CALLED HOME"
	if roll < 0.9 and main.summon and is_instance_valid(main.summon):
		main.summon.cooldown_left = 0.0
		return "YOUR COMPANION IS READY"
	for i in 5 + int(gm.stage):
		main.spawn_shard(main.clamp_arena(at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 80.0)), 1)
	return "SOUL SHARDS"


func on_boss() -> void:
	# The boss owns the arena: drop whatever is running, quietly.
	if not current.is_empty():
		_finish(current.get("obj"), false)
	enabled = false


func cleanup() -> void:
	enabled = false
	current = {}
	surge_left = 0.0


func debug_state() -> Dictionary:
	return {"current": str(current.get("kind", "")), "next": next_offer, "done": completed,
		"failed": failed, "surging": is_surging()}
