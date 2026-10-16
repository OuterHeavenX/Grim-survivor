extends BossAttack
# The crowned king's arena-wide furnace decree. Two opposite quadrants burn,
# then the other two, alternating for `steps` waves. Half the arena is always
# clear and the clear half is always adjacent to wherever you stand, so the
# answer is a short step sideways each wave. Afterwards the king stands spent
# and takes extra damage: the pattern pays you for surviving it.
#
# Timing (t = 0 when the first wave lands): wave k telegraphs at
# k * period - warn and lands at k * period, after wave k-1 has finished, so
# two waves never overlap.

var _active := false
var _step := 0
var _t := 0.0
var _center := Vector2.ZERO
var _pair := 0


func budget_cost() -> int:
	return 2


func period() -> float:
	return warn_time() + pf("active", 1.1) + 0.4


func telegraph() -> void:
	_center = ppos()
	_pair = rng().randi() % 2
	_step = 0
	_fire_step()


func burning_quadrants() -> Array:
	return [_pair, _pair + 2]


func _fire_step() -> void:
	var R := pf("radius", 760.0)
	var shapes: Array = []
	for q in burning_quadrants():
		shapes.append(HazardShape.sector(_center, R, PI * 0.5 * float(q) + PI * 0.25, PI * 0.25))
	if not safe_with(shapes):
		return
	for s in shapes:
		var h := hazard(s, pf("active", 1.1), pf("dmg", 1.0))
		h.recover_time = 0.3
		h.icon = "flame"


func commit() -> void:
	_active = true
	_t = 0.0


func is_running() -> bool:
	return _active


func tick(delta: float) -> void:
	if not _active:
		return
	_t += delta
	var steps := maxi(1, pi("steps", 2))
	if _step + 1 < steps and _t >= float(_step + 1) * period() - warn_time():
		_step += 1
		_pair = 1 - _pair
		_fire_step()
	if _t >= float(steps - 1) * period() + pf("active", 1.1) + 0.4:
		_active = false
		ctl.open_punish_window(pf("recovery", 2.6), pf("vulnerable", 1.5))
		ctl.stun_t = pf("recovery", 2.6)
		if main().hud:
			main().hud.show_warning("THE KING FALTERS")


func stop() -> void:
	_active = false
