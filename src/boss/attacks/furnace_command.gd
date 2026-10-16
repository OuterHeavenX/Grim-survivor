extends BossAttack
# The Cinder King commands the court's furnaces. Lanes fired this way belong
# to the boss, so they count against its hazard budget.


func budget_cost() -> int:
	return pi("count", 2)


func telegraph() -> void:
	var r = rule()
	var n := pi("count", 2)
	if r and r.has_method("fire_furnace"):
		var base := rng().randf() * TAU
		for i in n:
			var a := base + PI * float(i)
			var off := (float(i) - float(n - 1) * 0.5) * 300.0
			r.fire_furnace(a, off, warn_time(), "boss", ctl)
		return
	# Off the court: plain heat lanes.
	for i in n:
		var a2 := rng().randf() * TAU
		var u := Vector2.from_angle(a2)
		var c := ppos() + Vector2(-u.y, u.x) * (float(i) - 0.5) * 300.0
		var s := HazardShape.line(c - u * 700.0, c + u * 700.0, 120.0)
		if safe_with([s]):
			hazard(s, 1.4, 0.9)
