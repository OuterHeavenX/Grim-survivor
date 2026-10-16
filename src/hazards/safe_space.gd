class_name SafeSpace
extends RefCounted
# Samples the area around a point to measure how much of it is free of
# threats. Rules and bosses use this before committing a pattern, and the
# tests use it to prove a pattern never closes every escape.

const STEP := 48.0


static func threat_shapes(tree: SceneTree) -> Array:
	var out: Array = []
	for h in tree.get_nodes_in_group("timed_hazards"):
		if is_instance_valid(h) and h.has_method("is_threat") and h.is_threat():
			out.append(h.shape)
	return out


static func is_safe(p: Vector2, shapes: Array, margin := 12.0) -> bool:
	for s in shapes:
		if HazardShape.covers(s, p, margin):
			return false
	return true


static func fraction(center: Vector2, radius: float, shapes: Array, margin := 12.0) -> float:
	var total := 0
	var safe := 0
	var n := int(ceil(radius / STEP))
	for ix in range(-n, n + 1):
		for iy in range(-n, n + 1):
			var off := Vector2(ix, iy) * STEP
			if off.length() > radius:
				continue
			var p := center + off
			if absf(p.x) > 1500.0 or absf(p.y) > 1500.0:
				continue
			total += 1
			if is_safe(p, shapes, margin):
				safe += 1
	return 1.0 if total == 0 else float(safe) / float(total)


static func nearest_safe(center: Vector2, reach: float, shapes: Array, margin := 12.0) -> Variant:
	# The closest safe sample within reach, or null if none.
	var best: Variant = null
	var bd := INF
	var n := int(ceil(reach / STEP))
	for ix in range(-n, n + 1):
		for iy in range(-n, n + 1):
			var off := Vector2(ix, iy) * STEP
			var d := off.length()
			if d > reach or d >= bd:
				continue
			var p := center + off
			if absf(p.x) > 1500.0 or absf(p.y) > 1500.0:
				continue
			if is_safe(p, shapes, margin):
				best = p
				bd = d
	return best


static func pattern_ok(tree: SceneTree, center: Vector2, extra: Array, area: float,
		min_fraction: float, reach: float) -> bool:
	# Would adding these shapes still leave enough room, and a spot within
	# reach? The answer every new pattern must give "yes" to.
	var shapes := threat_shapes(tree)
	shapes.append_array(extra)
	if fraction(center, area, shapes) < min_fraction:
		return false
	return nearest_safe(center, reach, shapes) != null
