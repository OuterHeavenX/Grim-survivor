extends RelicEffect
# Frozen foes take 25% more, and shatters reach twice as far.

func on_hit(e, amount: float, _src: String, _kb: float) -> float:
	return amount * 1.25 if e.has_status("frozen") else amount


func shatter_reach(r: float) -> float:
	return r * 2.0
