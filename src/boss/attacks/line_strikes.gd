extends BossAttack
# Lines of damage: parallel bands across the player (bone spears) or radial
# jets out of the boss (water jets). Bands keep at least `spacing - width`
# of clear ground between them.


func _count() -> int:
	var n := pi("count", 4)
	# The Pale Herald's spears grow while its bone armour stands.
	if params.has("enhanced_count") and _armored():
		n = pi("enhanced_count", n)
	return n


func _armored() -> bool:
	for a in ctl.passives:
		if a.has_method("armor_up") and a.armor_up():
			return true
	return false


func budget_cost() -> int:
	return _count()


func telegraph() -> void:
	var n := _count()
	var L := pf("length", 900.0)
	var w := pf("width", 48.0)
	var shapes: Array = []
	match ps("pattern", "parallel"):
		"radial":
			var base := (ppos() - bpos()).angle() + rng().randf_range(-0.25, 0.25)
			for i in n:
				var a := base + TAU * float(i) / float(n)
				shapes.append(HazardShape.line(bpos(), bpos() + Vector2.from_angle(a) * L, w))
		_:
			var ang := rng().randf() * PI
			var u := Vector2.from_angle(ang)
			var nrm := Vector2(-u.y, u.x)
			var spacing := maxf(pf("spacing", 190.0), w + 110.0)
			var shift := rng().randf_range(-0.5, 0.5) * spacing
			for i in n:
				var off := (float(i) - float(n - 1) * 0.5) * spacing + shift
				var c := ppos() + nrm * off
				shapes.append(HazardShape.line(c - u * L * 0.5, c + u * L * 0.5, w))
	var placed: Array = []
	for s in shapes:
		if not safe_with(placed + [s]):
			continue
		placed.append(s)
		var h := hazard(s, pf("active", 0.45), pf("dmg", 1.0))
		h.recover_time = 0.25
		h.icon = "bone"
