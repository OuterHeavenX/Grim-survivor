extends RelicEffect
# Frost and blade hits arc to one more foe within REACH for 30% of the hit,
# at most once per RATE seconds.

const REACH := 200.0
const RATE := 0.3

var _cd := 0.0


func tick(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)


func on_hit(e, amount: float, src: String, _kb: float) -> float:
	if _cd > 0.0 or (src != "frost" and src != "blades"):
		return amount
	var best = null
	var bd := REACH
	for o in main().get_tree().get_nodes_in_group("enemies"):
		if o == e or bool(o.get("untargetable")):
			continue
		var d: float = o.global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = o
	if best:
		_cd = RATE
		best.call_deferred("take_damage", amount * 0.3, e.global_position, 20.0, source())
		if gm().run_stats:
			gm().run_stats.add_proc("relic:drowned_bell")
	return amount
