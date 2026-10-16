extends RelicEffect
# +10% move speed while above 80% health.

func tick(_delta: float) -> void:
	var p = main().player
	if p == null or not is_instance_valid(p):
		return
	var healthy: bool = p.hp > p.max_hp * 0.8
	gm().mods.set_mod("relic:iron_greaves:swift", "speed", 1.1 if healthy else 1.0)
