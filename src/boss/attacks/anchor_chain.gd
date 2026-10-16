extends BossAttack
# Two anchors slam down either side of the player, then a chain between them
# burns for chain_time. The chain is only ever drawn and damaging between two
# standing anchors: break either anchor and the chain goes with it. Anchors
# outlive the chain and feed the whirlpool in phase two.

var _a := Vector2.ZERO
var _b := Vector2.ZERO
var _active := false
var _t := 0.0
var _anchors: Array = []
var _chain: TimedHazard = null


func budget_cost() -> int:
	return 3


func live_anchors() -> int:
	var n := 0
	for e in ctl.get_tree().get_nodes_in_group("enemies"):
		if String(e.get("etype")) == "anchor" and not bool(e.get("dead")):
			n += 1
	return n


func available() -> bool:
	return live_anchors() + 2 <= pi("max_anchors", 4)


func telegraph() -> void:
	var u := Vector2.from_angle(rng().randf() * TAU)
	_a = clamp_arena(ppos() + u * 230.0)
	_b = clamp_arena(ppos() - u * 230.0)
	for p in [_a, _b]:
		var h := hazard(HazardShape.circle(p, pf("radius", 70.0)), 0.3, pf("dmg", 1.0))
		h.icon = "warn"


func commit() -> void:
	_anchors.clear()
	for p in [_a, _b]:
		var e = ctl.spawn_minion("anchor", p, true)
		if e:
			e.set("is_boss_object", true)
			_anchors.append(e)
	if _anchors.size() < 2:
		return
	_chain = hazard(HazardShape.line(_a, _b, 30.0), pf("chain_time", 4.0), pf("chain_dmg", 0.35), 0.65)
	_chain.tick_interval = 0.5
	_chain.icon = "warn"
	_active = true
	_t = 0.0


func is_running() -> bool:
	return _active


func tick(delta: float) -> void:
	if not _active:
		return
	_t += delta
	for e in _anchors:
		if not is_instance_valid(e) or bool(e.get("dead")):
			if _chain and is_instance_valid(_chain):
				_chain.finish_now()
			_active = false
			return
	if _chain == null or not is_instance_valid(_chain):
		_active = false


func stop() -> void:
	_active = false
	if _chain and is_instance_valid(_chain):
		_chain.finish_now()
