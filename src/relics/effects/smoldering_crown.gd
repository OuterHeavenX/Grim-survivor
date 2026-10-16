extends RelicEffect
# Burning foes (set alight by fire hits) take a damage tick every half
# second. Burning refreshes, it never stacks.

const TICK := 0.5

var _t := 0.0


func tick(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	var d: float = 4.0 * gm().might_mult()
	for e in main().get_tree().get_nodes_in_group("enemies"):
		if e.has_status("burning") and not bool(e.dead):
			e.take_damage(d, e.global_position, 0.0, source())
