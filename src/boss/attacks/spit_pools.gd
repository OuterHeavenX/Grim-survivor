extends BossAttack
# Lobs toxic spit that lands as lingering pools around the player: ground
# denial rather than a hit to dodge.


func budget_cost() -> int:
	return pi("count", 4)


func telegraph() -> void:
	var placed: Array = []
	for i in pi("count", 4):
		var p := ppos() + Vector2.from_angle(rng().randf() * TAU) * rng().randf_range(60.0, pf("spread", 150.0))
		var s := HazardShape.circle(clamp_arena(p), pf("radius", 60.0))
		if not safe_with(placed + [s]):
			continue
		placed.append(s)
		var h := hazard(s, pf("life", 6.0), pf("dmg", 0.3))
		h.tick_interval = 0.5
		h.recover_time = 0.6
		h.color = Color(0.5, 1.0, 0.3)
		h.icon = "skull"
