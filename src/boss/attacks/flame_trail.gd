extends BossAttack
# Passive: the crowned king leaves short-lived fire behind him. Bounded by
# max_trail so a long chase cannot carpet the arena.

var _t := 0.0
var _trail: Array = []


func tick(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or ctl.submerged:
		return
	_t = pf("interval", 0.4)
	_trail = _trail.filter(func(h): return is_instance_valid(h))
	if _trail.size() >= pi("max_trail", 8):
		return
	var h := hazard(HazardShape.circle(bpos(), pf("radius", 46.0)), pf("life", 2.2), pf("dmg", 0.25), 0.65)
	h.tick_interval = 0.5
	h.icon = "flame"
	h.color = Color(1.0, 0.5, 0.15)
	_trail.append(h)


func stop() -> void:
	for h in _trail:
		if is_instance_valid(h):
			h.finish_now()
	_trail.clear()
