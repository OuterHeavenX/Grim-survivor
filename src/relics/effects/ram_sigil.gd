extends RelicEffect
# Hits that shove hard (knockback 200+) deal 15% more.

func on_hit(_e, amount: float, src: String, kb: float) -> float:
	if kb >= 200.0 and not CombatRules.is_proc_source(src):
		return amount * 1.15
	return amount
