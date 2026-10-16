extends RelicEffect
# Fire blasts leave a patch of burning ground that hurts foes, never you.
# At most MAX_PATCHES burn at once.

const MAX_PATCHES := 4


func on_explosion(pos: Vector2, radius: float, src: String) -> void:
	if not CombatRules.FIRE.has(src):
		return
	if main().get_tree().get_nodes_in_group("relic_patches").size() >= MAX_PATCHES:
		return
	var h := TimedHazard.new()
	h.setup(HazardShape.circle(pos, minf(radius * 0.7, 90.0)), 0.65, 3.0, 0.0, Color(1, 0.45, 0.15), source(), "player")
	h.enemy_damage = 8.0 * gm().might_mult()
	h.tick_interval = 0.5
	h.add_to_group("relic_patches")
	main().add_hazard_node(h)
