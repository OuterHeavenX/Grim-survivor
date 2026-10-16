extends BossAttack
# Summons a bounded group. revived adds give no XP, kills or drops, so a boss
# that raises the dead cannot be farmed; from_piles draws them up out of the
# desert's bone piles when there are any.


func available() -> bool:
	return ctl.alive_spawned(ps("etype", "skeleton")) < pi("max_alive", 3)


func telegraph() -> void:
	if main().jm:
		main().jm.shockwave(bpos(), ctl.data.aura, 180.0)
	if main().lm:
		main().lm.flash(bpos(), ctl.data.aura, 1.8, 2.6, warn_time())


func commit() -> void:
	var et := ps("etype", "skeleton")
	var room := pi("max_alive", 3) - ctl.alive_spawned(et)
	var n := mini(int(round(float(pi("count", 2)) * ctl.reinforcement_mult)), room)
	var spots: Array = []
	if bool(params.get("from_piles", false)):
		var r = rule()
		if r and r.has_method("take_pile_spots"):
			spots = r.take_pile_spots(bpos(), n)
	while spots.size() < n:
		spots.append(bpos() + Vector2.from_angle(rng().randf() * TAU) * pf("ring", 180.0))
	var no_credit := bool(params.get("revived", false)) or bool(params.get("no_credit", false))
	for i in n:
		var e = ctl.spawn_minion(et, spots[i], no_credit)
		if e and bool(params.get("revived", false)):
			e.set("revived", true)
