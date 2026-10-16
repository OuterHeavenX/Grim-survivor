class_name CombatRules
extends Node
# Cross-weapon interactions and the relic hooks that ride on every hit. Lives
# under the run node, so it resets with each run.
#
# Recursion guard: every triggered effect deals damage under its own source
# ("interaction:*" or "relic:*"), and no interaction triggers off those
# sources. A proc can therefore cause damage but never another proc of the
# same chain. On top of that each interaction has a rate limit, and every
# proc is recorded in RunStats so tests can count them.
#
#   ignite    fire blast + miasma cloud -> one capped explosion per cloud
#   shatter   heavy impact on a frozen foe -> bonus hit + shards to neighbours
#   harvest   scythe kill -> a spectral raven (max 4 alive)
#   conduct   blade hit while holding Chain Lightning -> a short arc
#   kindling  fire hits set foes burning; comets favour burning foes
#   mark      lance hits mark; the next thrown projectile hit cashes it in

const FIRE := ["fireball", "ember"]
const HEAVY := ["lance", "bulwark", "comet"]
const FOLLOWUP := ["dagger", "sdagger", "raven"]
const EXPLOSIVE := ["fireball", "ember", "comet", "interaction:ignite"]

const IGNITE_CAP := 60.0
const SHATTER_BONUS := 0.6
const SHATTER_SPLASH := 0.25
const MARK_BONUS := 0.4
const CONDUCT_SHARE := 0.35
const MAX_HARVEST_RAVENS := 4

# Minimum seconds between procs of each interaction.
const RATE := {"ignite": 0.33, "shatter": 0.1, "harvest": 1.0, "conduct": 0.6}

var main = null
var gm = null
var relics: RelicManager = null
var _next := {}
var _burn_tick := 0.0


func setup(p_main) -> void:
	main = p_main
	gm = main.gm
	name = "CombatRules"


func _ready_for(kind: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_next.get(kind, 0.0)):
		return false
	_next[kind] = now + float(RATE.get(kind, 0.0))
	return true


func _proc(kind: String) -> void:
	if gm and gm.run_stats:
		gm.run_stats.add_proc(kind)


static func is_proc_source(source: String) -> bool:
	return source.begins_with("interaction:") or source.begins_with("relic:")


func modify_hit(e, amount: float, source: String, kb: float) -> float:
	var v := amount
	if not is_proc_source(source):
		if FOLLOWUP.has(source) and e.has_status("marked"):
			e.clear_status("marked")
			v *= 1.0 + MARK_BONUS
			_proc("mark")
		if source == "lance":
			e.set_status("marked", 3.0)
		if FIRE.has(source):
			e.set_status("burning", 3.0)
		if HEAVY.has(source) and e.has_status("frozen") and _ready_for("shatter"):
			e.clear_status("frozen")
			_shatter(e, v)
		if source == "frost":
			e.set_status("frozen", 2.5)
		if source == "blades" and gm.weapons.has("lightning") and _ready_for("conduct"):
			_conduct(e)
	if relics:
		v = relics.on_hit(e, v, source, kb)
	var crit: float = gm.mods.add("crit_chance")
	if crit > 0.0 and not is_proc_source(source) and randf() < crit:
		v *= 2.0
	return v


func contact_damage(e, amount: float) -> float:
	return relics.contact_damage(e, amount) if relics else amount


func on_kill(e, source: String) -> void:
	if source == "scythe" and _ready_for("harvest"):
		_harvest(e.global_position)
	if relics:
		relics.on_kill(e, source)


func on_player_hit(amount: float, source: String) -> void:
	if relics:
		relics.on_player_hit(amount, source)


func on_explosion(pos: Vector2, radius: float, source: String) -> void:
	# Called by projectile blasts. Fire blasts may ignite miasma; the stage
	# hears about it too (marsh blooms). Ignitions themselves report as
	# "interaction:ignite", which is not fire, so they cannot chain.
	if FIRE.has(source):
		_ignite_clouds(pos, radius)
		if main.director and is_instance_valid(main.director):
			main.director.emit_element("fire", pos, radius, source)
	if relics:
		relics.on_explosion(pos, radius, source)


func comet_weight(e) -> float:
	return 3.0 if e.has_status("burning") else 1.0


func pick_comet_target(foes: Array):
	var total := 0.0
	for f in foes:
		total += comet_weight(f)
	var roll := randf() * total
	for f in foes:
		roll -= comet_weight(f)
		if roll <= 0.0:
			return f
	return foes[-1] if not foes.is_empty() else null


# --- interactions ----------------------------------------------------------

func _ignite_clouds(pos: Vector2, radius: float) -> void:
	for c in get_tree().get_nodes_in_group("miasma_clouds"):
		if bool(c.get("ignited")):
			continue
		var cr: float = float(c.get("cloud_radius"))
		if c.global_position.distance_to(pos) > cr + radius:
			continue
		if not _ready_for("ignite"):
			return
		c.set("ignited", true)
		c.set("life", minf(float(c.get("life")), 0.3))
		var blast := minf(float(c.get("damage")) * 5.0, IGNITE_CAP * gm.might_mult())
		for en in get_tree().get_nodes_in_group("enemies"):
			if en.global_position.distance_to(c.global_position) < cr * 1.1 + float(en.body_radius):
				en.take_damage(blast, c.global_position, 160.0, "interaction:ignite")
		main.spawn_boom(c.global_position, cr * 1.1)
		_proc("ignite")


func _shatter(e, hit: float) -> void:
	var bonus := hit * SHATTER_BONUS
	var reach := 90.0
	if relics:
		reach = relics.shatter_reach(reach)
	_proc("shatter")
	e.call_deferred("take_damage", bonus, e.global_position, 0.0, "interaction:shatter")
	var n := 0
	for o in get_tree().get_nodes_in_group("enemies"):
		if n >= 3:
			break
		if o == e or o.global_position.distance_to(e.global_position) > reach:
			continue
		o.call_deferred("take_damage", hit * SHATTER_SPLASH, e.global_position, 60.0, "interaction:shatter")
		n += 1
	if main.jm:
		main.jm.shockwave(e.global_position, Color(0.75, 0.95, 1.0), reach)


func _harvest(pos: Vector2) -> void:
	if get_tree().get_nodes_in_group("harvest_ravens").size() >= MAX_HARVEST_RAVENS:
		return
	var r = load("res://src/projectile.gd").new()
	var lvl := int(gm.weapons.get("scythe", 1))
	r.setup_raven(22.0 * (1.0 + 0.2 * float(lvl - 1)) * gm.might_mult(), pos, 1)
	r.set("source_id", "interaction:harvest")
	r.add_to_group("harvest_ravens")
	main.run.add_child(r)
	_proc("harvest")


func _conduct(e) -> void:
	var lvl := int(gm.weapons.get("lightning", 1))
	var d: float = 24.0 * (1.0 + 0.45 * float(lvl - 1)) * gm.might_mult() * CONDUCT_SHARE
	var from: Vector2 = e.global_position
	var pts := PackedVector2Array([from])
	var skip := {e.get_instance_id(): true}
	for jump in 2:
		var best = null
		var bd := 220.0
		for o in get_tree().get_nodes_in_group("enemies"):
			if skip.has(o.get_instance_id()) or bool(o.get("untargetable")):
				continue
			var dd: float = o.global_position.distance_to(from)
			if dd < bd:
				bd = dd
				best = o
		if best == null:
			break
		skip[best.get_instance_id()] = true
		pts.append(best.global_position)
		best.call_deferred("take_damage", d, from, 20.0, "interaction:conduct")
		from = best.global_position
	if pts.size() > 1:
		var zap = load("res://src/projectile.gd").new()
		zap.setup("zap", 0.0, Vector2.ZERO)
		zap.set("zap_points", pts)
		main.run.add_child(zap)
		_proc("conduct")


func _physics_process(delta: float) -> void:
	if relics:
		relics.tick(delta)
