extends RelicEffect
# Every EVERY-th kill bursts the corpse. Kills made by the burst itself do not
# count towards the next one, so it cannot chain.

const EVERY := 15
const RADIUS := 80.0

var kills := 0


func on_kill(e, src: String) -> void:
	if src == source():
		return
	kills += 1
	if kills % EVERY != 0:
		return
	var at: Vector2 = e.global_position
	for o in main().get_tree().get_nodes_in_group("enemies"):
		if o != e and o.global_position.distance_to(at) < RADIUS + float(o.body_radius):
			o.call_deferred("take_damage", 25.0 * gm().might_mult(), at, 180.0, source())
	main().spawn_boom(at, RADIUS)
	if gm().run_stats:
		gm().run_stats.add_proc("relic:grave_pact")
