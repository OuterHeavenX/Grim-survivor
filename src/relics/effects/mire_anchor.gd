extends RelicEffect
# Slowed foes hit 30% softer.


func contact_damage(e, amount: float) -> float:
	return amount * 0.7 if e.is_slowed() else amount
