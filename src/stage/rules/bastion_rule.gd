extends StageRule
# The Last Bastion: Siege of the Ashen Sovereign.
#
# Three ruined wards ring the start. Stand in one to light it; a lit ward
# grants its boon (flame: damage, stone: less harm, wind: speed) for as long
# as it stands. Foes crowding a ward wear it down; a lost ward takes its boon
# with it. Nothing here is mandatory: an unlit or lost ward changes the run,
# never whether it can be won.
#
#   0:00  light your first ward (all three are open)
#   1:15  the others open; Ashen Hollow's cinder scars return, sparse, using
#         the same AshScar implementation and stage hazard cap
#   3:00  elite commanders land beside lit wards
#   4:15  Final Siege: portals open; lit wards fire on them; each closed
#         portal deterministically trims the Sovereign's reinforcements
#   5:00  surviving wards fire on the Sovereign
#
# Ward outcomes live in "stage:" modifiers and this rule only: nothing about
# them is saved.

const WardScript := preload("res://src/stage/ward.gd")
const KINDS := ["flame", "stone", "wind"]
const BOONS := {
	"flame": {"damage": 1.15},
	"stone": {"damage_taken": 0.85},
	"wind": {"speed": 1.12},
}

var wards: Array = []
var portals_total := 0
var portals_closed := 0
var _first_obj: StageObjective = null
var _portal_obj: StageObjective = null
var _legacy_next := 0.0
var _commander_next := 0.0
var _fire_t := 0.0
var _siege := false
var _boss = null


func setup() -> void:
	var ring: float = float(p("ward_ring", 520.0))
	for i in 3:
		var w = WardScript.new()
		w.rule = self
		w.kind = KINDS[i]
		w.max_hp = float(p("ward_hp", 400.0))
		w.hp = w.max_hp
		w.radius = float(p("ward_radius", 110.0))
		w.position = Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 3.0) * ring
		w.activatable = true
		add_stage_object(w)
		wards.append(w)
	_first_obj = StageObjective.new()
	_first_obj.kind = "manual"
	_first_obj.label = "LIGHT A WARD"
	_first_obj.goal = 1.0
	_first_obj.time_limit = float(data.phase_times[0]) if data.phase_times.size() > 0 else 75.0
	add_stage_object(_first_obj)


func lit_wards() -> Array:
	return wards.filter(func(w): return is_instance_valid(w) and w.state == "active")


func on_ward_lit(w) -> void:
	gm.mods.set_mods("stage:ward:" + String(w.kind), BOONS[w.kind])
	announce("WARD OF %s LIT" % String(w.kind).to_upper())
	if _first_obj and is_instance_valid(_first_obj) and _first_obj.is_active():
		_first_obj.add_progress(1.0)
		# Until 1:15 only one ward may be lit: the first choice is a choice.
		for o in wards:
			if o != w and o.state == "dormant":
				o.activatable = false
	if gm.run_stats:
		gm.run_stats.log_event("ward %s lit" % w.kind)


func on_ward_lost(w) -> void:
	gm.mods.clear_source("stage:ward:" + String(w.kind))
	announce("WARD OF %s FALLS" % String(w.kind).to_upper())
	if gm.run_stats:
		gm.run_stats.log_event("ward %s lost" % w.kind)


func on_intensity(level: int) -> void:
	super.on_intensity(level)
	if level >= 1:
		for w in wards:
			if w.state == "dormant":
				w.activatable = true
		_legacy_next = gm.run_time + 2.0
	if level >= 2:
		_commander_next = gm.run_time + 3.0
		announce("COMMANDERS ASSAULT THE WARDS")


func tick(delta: float, t: float) -> void:
	if stopped:
		return
	if intensity >= 1 and intensity < 3 and t >= _legacy_next:
		_legacy_next = t + float(p("legacy_interval", 4.5))
		spawn_legacy_scar()
	if intensity == 2 and t >= _commander_next:
		_commander_next = t + float(p("commander_interval", 22.0))
		send_commander()
	if _siege:
		_ward_fire(delta)


func spawn_legacy_scar() -> int:
	var r: float = float(p("radius", 70.0))
	for attempt in 6:
		var pos := ring_point(ppos(), 160.0, 380.0)
		if AshScar.on_cooled_ground(get_tree(), pos, r):
			continue
		var s := HazardShape.circle(pos, r)
		if room_for(1) and pattern_ok([s]):
			AshScar.make(self, pos, {"radius": r, "dmg": 14.0, "enemy_dmg": 30.0, "cooled": 5.0})
			return 1
	return 0


func send_commander() -> void:
	var lit := lit_wards()
	if lit.is_empty() or main._live_elites() >= main.MAX_LIVE_ELITES:
		return
	var w = lit[rng.randi() % lit.size()]
	var pool: Array = gm.stage_data()["pool"]
	var e = main._spawn_enemy(str(pool[rng.randi() % pool.size()]), ring_point(w.global_position, 120.0, 180.0))
	if e:
		e.make_elite()


func on_event(id: String, ev: StageEventData) -> void:
	super.on_event(id, ev)
	if id != "final_siege":
		return
	_siege = true
	portals_total = int(p("portals", 3))
	var ring: float = float(p("portal_ring", 560.0))
	var a0 := rng.randf() * TAU
	for i in portals_total:
		var pos := clamp_arena(ppos() + Vector2.from_angle(a0 + TAU * float(i) / float(portals_total)) * ring, 120.0)
		var e = main._spawn_enemy("siege_portal", pos)
		if e:
			e.no_credit = true
	_portal_obj = StageObjective.new()
	_portal_obj.kind = "manual"
	_portal_obj.label = "CLOSE THE PORTALS"
	_portal_obj.goal = float(portals_total)
	_portal_obj.time_limit = ev.duration - 0.5
	add_stage_object(_portal_obj)


func _ward_fire(delta: float) -> void:
	_fire_t -= delta
	if _fire_t > 0.0:
		return
	_fire_t = float(p("ward_fire", 1.2))
	for w in lit_wards():
		var target = _boss if (_boss and is_instance_valid(_boss) and not _boss.dead) else nearest_portal(w.global_position)
		if target == null:
			continue
		target.take_damage(float(p("ward_bolt", 40.0)), w.global_position, 0.0, "stage:ward")
		var zap = load("res://src/projectile.gd").new()
		zap.setup("zap", 0.0, Vector2.ZERO)
		zap.set("zap_points", PackedVector2Array([w.global_position, target.global_position]))
		main.run.add_child(zap)


func nearest_portal(pos: Vector2):
	var best = null
	var bd := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if String(e.etype) == "siege_portal" and not e.dead:
			var d: float = e.global_position.distance_to(pos)
			if d < bd:
				bd = d
				best = e
	return best


func on_enemy_died(e) -> void:
	if String(e.etype) != "siege_portal":
		return
	portals_closed += 1
	if _portal_obj and is_instance_valid(_portal_obj):
		_portal_obj.add_progress(1.0)
	announce("PORTAL CLOSED %d / %d" % [portals_closed, portals_total])


static func reinforcement_for(closed: int, total: int) -> float:
	# Deterministic: every closed portal removes an equal share of up to 75%
	# of the Sovereign's reinforcements. No portals opened = full strength.
	if total <= 0:
		return 1.0
	return 1.0 - 0.75 * float(clampi(closed, 0, total)) / float(total)


func on_boss(boss) -> void:
	super.on_boss(boss)
	_boss = boss
	_siege = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if String(e.etype) == "siege_portal":
			e.queue_free()
	if boss and boss.controller:
		boss.controller.reinforcement_mult = reinforcement_for(portals_closed, portals_total)
	for o in get_tree().get_nodes_in_group("objectives"):
		o.state = "done"
	if gm.run_stats:
		gm.run_stats.log_event("siege: %d/%d portals, %d wards" % [portals_closed, portals_total, lit_wards().size()])


func boss_tick(delta: float) -> void:
	_ward_fire(delta)


func cleanup() -> void:
	super.cleanup()
	_siege = false
	_boss = null
	if gm:
		for k in KINDS:
			gm.mods.clear_source("stage:ward:" + k)


func debug_state() -> Dictionary:
	var d := super.debug_state()
	d["lit"] = lit_wards().size()
	d["portals"] = "%d/%d" % [portals_closed, portals_total]
	return d
