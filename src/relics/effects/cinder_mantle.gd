extends RelicEffect
# Retaliation: being struck bursts flame around you, at most every COOLDOWN.

const COOLDOWN := 1.5
const RADIUS := 140.0

var _cd := 0.0


func tick(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)


func on_player_hit(_amount: float, _src: String) -> void:
	if _cd > 0.0 or main().player == null:
		return
	_cd = COOLDOWN
	var at: Vector2 = main().player.global_position
	for e in main().get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(at) < RADIUS + float(e.body_radius):
			e.take_damage(30.0 * gm().might_mult(), at, 220.0, source())
	if main().jm:
		main().jm.shockwave(at, Color(1, 0.4, 0.15), RADIUS)
	if gm().run_stats:
		gm().run_stats.add_proc("relic:cinder_mantle")
