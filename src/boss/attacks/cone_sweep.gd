extends BossAttack
# A cone from the boss. With sweep > 0 the blade travels across the cone over
# its active time and the warning covers the whole arc it will pass through;
# with sweep = 0 it is a single directional slam.


func telegraph() -> void:
	var a := (ppos() - bpos()).angle()
	var half := pf("half_angle", 0.45)
	var sweep := pf("sweep", 0.0)
	var shape := HazardShape.sector(bpos(), pf("radius", 500.0), a, half + sweep * 0.5)
	# Into an already crowded arena, the swing is held back rather than
	# closing the last way out.
	if not safe_with([shape]):
		return
	var h := hazard(shape, pf("active", 0.8), pf("dmg", 1.0))
	h.sweep = sweep
	h.data["blade_half"] = half
	h.recover_time = 0.3
	h.knockback = 0.0
	h.icon = "sword"
