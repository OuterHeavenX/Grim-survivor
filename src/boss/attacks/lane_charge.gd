extends BossAttack
# Paint a lane, then charge down it regardless of what the player did. With
# target = "pillar" the boss charges at its nearest roadblock pillar instead
# and shatters it on arrival.

var _target = null


func telegraph() -> void:
	_target = null
	var d := dir
	if ps("target", "") == "pillar":
		var best = null
		var bd := 900.0
		for pl in ctl.get_tree().get_nodes_in_group("pillars"):
			var dd: float = pl.global_position.distance_to(bpos())
			if dd < bd:
				bd = dd
				best = pl
		if best:
			_target = best
			d = (best.global_position - bpos()).normalized()
	else:
		d = (ppos() - bpos()).normalized()
	if d.length() < 0.1:
		d = Vector2.RIGHT
	boss().set("_cast_dir", d)
	var h: Node2D = main().spawn_hazard("lane", bpos(), 0.0, ctl.data.aura)
	h.lane_to = bpos() + d * pf("length", 520.0)
	h.radius = float(boss().body_radius) * 1.1
	h.life = warn_time()
	h.add_to_group("boss_hazards")


func commit() -> void:
	var d: Vector2 = boss().get("_cast_dir")
	boss().set("_kb", d * pf("speed", 1150.0))
	if main().jm:
		main().jm.add_trauma(0.4)
	if _target and is_instance_valid(_target) and _target.has_method("shatter"):
		# Arrives in roughly length / speed seconds; the pillar breaks then.
		var t := clampf(_target.global_position.distance_to(bpos()) / pf("speed", 1150.0), 0.1, 0.8)
		_target.call_deferred("shatter_in", t)
