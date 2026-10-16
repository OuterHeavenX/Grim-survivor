extends BossAttack
# A ring or fan of slow bolts. The telegraph paints a short spoke for every
# bolt that is coming, so the gaps can be read before anything flies.

var _angles: Array = []
var _spokes: Array = []


func _count() -> int:
	return pi("count_enraged", 12) if ctl.enraged else pi("count", 10)


func budget_cost() -> int:
	return _count()


func telegraph() -> void:
	var n := _count()
	var arc := pf("arc", TAU)
	var base: float
	if bool(params.get("aimed", false)):
		base = (ppos() - bpos()).angle()
	else:
		base = rng().randf() * TAU
	_angles.clear()
	for i in n:
		var a: float
		if arc >= TAU - 0.01:
			a = base + TAU * float(i) / float(n)
		else:
			a = base - arc * 0.5 + arc * (float(i) / float(maxi(1, n - 1)))
		_angles.append(a)
		var h: Node2D = main().spawn_hazard("lane", bpos(), 0.0, ctl.data.aura)
		h.lane_to = bpos() + Vector2.from_angle(a) * 170.0
		h.radius = 6.0
		h.life = warn_time()
		h.add_to_group("boss_hazards")
		_spokes.append(h)
	if main().lm:
		main().lm.flash(bpos(), ctl.data.aura, 2.0, 3.0, warn_time())


func commit() -> void:
	# The spokes have done their job; the bolts take their place in the
	# budget rather than adding to it.
	for s in _spokes:
		if is_instance_valid(s):
			s.remove_from_group("boss_hazards")
			s.queue_free()
	_spokes.clear()
	var spd := pf("speed", 210.0)
	for a in _angles:
		var b: Node2D = main().spawn_hazard("bolt", bpos(), dmg(pf("dmg", 0.8)), ctl.data.aura)
		b.vel = Vector2.from_angle(a) * spd
		b.radius = pf("radius", 12.0)
		b.life = pf("life", 3.4)
		b.set("source", "boss:%s:%s" % [String(ctl.data.id), String(data.id)])
		b.add_to_group("boss_hazards")
	_angles.clear()
