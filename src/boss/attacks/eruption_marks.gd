extends BossAttack
# Circles that warn, then erupt. Patterns:
#   predict      around where the player is heading (lead capped)
#   scatter      spread around the player, never on all sides at once
#   ring_player  a ring around the player with gaps between marks
# Every mark is checked against the safe-space rule before it is placed; a
# mark that would close the last escape is simply dropped.


func telegraph() -> void:
	var n := pi("count", 3)
	var r := pf("radius", 70.0)
	var spread := pf("spread", 150.0)
	var pattern := ps("pattern", "scatter")
	var center := ppos()
	var spots: Array = []
	match pattern:
		"predict":
			var lead := minf(pf("lead", 0.5), 0.6)
			var aim := center + pvel() * lead
			spots.append(aim)
			for i in n - 1:
				spots.append(aim + Vector2.from_angle(rng().randf() * TAU) * rng().randf_range(r * 1.4, spread))
		"ring_player":
			var a0 := rng().randf() * TAU
			for i in n:
				spots.append(center + Vector2.from_angle(a0 + TAU * float(i) / float(n)) * spread)
		_:
			for i in n:
				spots.append(center + Vector2.from_angle(rng().randf() * TAU) * rng().randf_range(0.0, spread))
	var placed: Array = []
	for s in spots:
		var shape := HazardShape.circle(clamp_arena(s), r)
		if not safe_with(placed + [shape]):
			continue
		placed.append(shape)
		var h := hazard(shape, 0.3, pf("dmg", 1.0))
		h.recover_time = 0.25
		h.linger_time = pf("linger", 0.0)
		h.ignitable = bool(params.get("ignitable", false))
		h.icon = "flame"
