extends BossAttack
# Sinks the island nearest the player for a while; the ground there turns to
# sucking mire (a ticking hazard owned by the boss). Only offered where the
# stage has islands.


func available() -> bool:
	var r = rule()
	return r != null and r.has_method("sink_island")


func telegraph() -> void:
	var r = rule()
	if r == null:
		return
	var isl: Dictionary = r.sink_island(ppos(), warn_time() + pf("sink", 9.0))
	if isl.is_empty():
		return
	var s := HazardShape.circle(isl["pos"], float(isl["radius"]) * 0.9)
	if not safe_with([s]):
		return
	var h := hazard(s, pf("sink", 9.0), 0.25)
	h.tick_interval = 0.5
	h.color = Color(0.4, 0.75, 0.35)
	h.icon = "skull"
