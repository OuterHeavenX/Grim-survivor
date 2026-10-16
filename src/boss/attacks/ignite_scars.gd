extends BossAttack
# The Herald's second phase sets its own cooled scars alight again. Nearest
# first, and only while the arena keeps its safe share; if too few scars lie
# cold it scorches fresh ones instead.


func telegraph() -> void:
	var cold: Array = []
	for h in ctl.get_tree().get_nodes_in_group("timed_hazards"):
		if h.is_lingering() and h.ignitable and h.global_position.distance_to(ppos()) < 900.0:
			cold.append(h)
	cold.sort_custom(func(a, b): return a.global_position.distance_to(ppos()) < b.global_position.distance_to(ppos()))
	var lit: Array = []
	for h in cold:
		if not safe_with(lit + [h.shape]):
			continue
		if h.reignite(warn_time()):
			lit.append(h.shape)
			# A relit scar belongs to the boss now, for the budget's sake.
			h.add_to_group("boss_hazards")
			h.linger_time = 0.0
	var want := pi("fallback_count", 4) - lit.size()
	for i in want:
		var p := ppos() + Vector2.from_angle(rng().randf() * TAU) * rng().randf_range(90.0, 260.0)
		var s := HazardShape.circle(clamp_arena(p), pf("radius", 72.0))
		if not safe_with(lit + [s]):
			continue
		lit.append(s)
		var h2 := hazard(s, 0.3, pf("dmg", 1.0))
		h2.linger_time = 4.0
		h2.ignitable = true
		h2.icon = "flame"
	if main().hud:
		main().hud.show_warning("THE SCARS IGNITE")
