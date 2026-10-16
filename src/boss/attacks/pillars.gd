extends BossAttack
# Roadblock pillars: obstacles the Warden raises and later charges into.
# Placement can never wall the player in: pillars keep their distance from
# the player and from each other, there are never more than max_pillars, and
# a placement that would leave fewer than half the directions out of the
# player's spot open is rejected.

const PillarScript := preload("res://src/boss/pillar.gd")
const MIN_FROM_PLAYER := 170.0
const MIN_APART := 240.0

var _spots: Array = []


func budget_cost() -> int:
	return 0


func live_pillars() -> Array:
	return ctl.get_tree().get_nodes_in_group("pillars")


func available() -> bool:
	return live_pillars().size() < pi("max_pillars", 4)


static func open_directions(director, at: Vector2, extra: Array) -> int:
	# Of 16 headings, how many let a body walk 110px away unobstructed.
	var n := 0
	for i in 16:
		var d := Vector2.from_angle(TAU * float(i) / 16.0)
		var ok := true
		for step in [40.0, 75.0, 110.0]:
			var p: Vector2 = at + d * step
			if director and director.blocked(p, 18.0):
				ok = false
				break
			for e in extra:
				if p.distance_to(e) < PillarScript.RADIUS + 18.0:
					ok = false
					break
			if not ok:
				break
		if ok:
			n += 1
	return n


func choose_spots() -> Array:
	var room := pi("max_pillars", 4) - live_pillars().size()
	var want := mini(pi("count", 3), room)
	var spots: Array = []
	var existing: Array = []
	for pl in live_pillars():
		existing.append(pl.global_position)
	for attempt in 30:
		if spots.size() >= want:
			break
		var p := clamp_arena(bpos() + Vector2.from_angle(rng().randf() * TAU) * rng().randf_range(160.0, 520.0), 120.0)
		if p.distance_to(ppos()) < MIN_FROM_PLAYER:
			continue
		var clash := false
		for q in existing + spots:
			if p.distance_to(q) < MIN_APART:
				clash = true
		if clash:
			continue
		if open_directions(main().director, ppos(), existing + spots + [p]) < 8:
			continue
		spots.append(p)
	return spots


func telegraph() -> void:
	_spots = choose_spots()
	for p in _spots:
		var h := hazard(HazardShape.circle(p, PillarScript.RADIUS + 6.0), 0.15, 0.6)
		h.icon = "warn"


func commit() -> void:
	for p in _spots:
		var pl = PillarScript.new()
		pl.position = p
		pl.life = pf("life", 14.0)
		ctl.own_object(pl)
	_spots.clear()
