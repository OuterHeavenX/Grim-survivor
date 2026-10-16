extends BossAttack
# A ring of damage with one or more gaps, optionally rotating. Anchored on the
# boss (a slow turning wall to walk with) or on the player (a cage to step
# out of). The first gap starts within reach of the player, so the escape is
# always reachable inside the warning.

const MAX_TRIES := 4


func telegraph() -> void:
	var anchor := ps("anchor", "boss")
	var center := bpos() if anchor == "boss" else ppos()
	var inner := pf("inner", 110.0)
	var outer := pf("outer", 560.0)
	var half := pf("gap_half", 0.6)
	var n := maxi(1, pi("gaps", 1))
	var to_p := (ppos() - center)
	var base := to_p.angle() if to_p.length() > 1.0 else rng().randf() * TAU
	var shape := {}
	for attempt in MAX_TRIES:
		var off := rng().randf_range(-0.5, 0.5)
		var gaps: Array = []
		for i in n:
			gaps.append([base + off + TAU * float(i) / float(n), half])
		var candidate := HazardShape.ring_gap(center, inner, outer, gaps)
		if safe_with([candidate]):
			shape = candidate
			break
		half = minf(half + 0.2, 1.2)
	if shape.is_empty():
		# No ring fits without closing the escape: this cast fizzles.
		return
	var active := pf("active", 1.0)
	var h := hazard(shape, active, pf("dmg", 1.0))
	h.rot_speed = pf("rot_speed", 0.0) * (1.0 if rng().randf() < 0.5 else -1.0)
	# Long rings tick; short ones hit once.
	h.tick_interval = 0.5 if active > 1.2 else 0.0
	h.recover_time = 0.3
	h.icon = "skull"
