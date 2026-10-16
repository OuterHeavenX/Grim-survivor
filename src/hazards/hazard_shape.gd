class_name HazardShape
extends RefCounted
# Geometry for hazards, as plain dictionaries in world space so a rule can
# test a pattern for safety before any node exists.
#
#   circle    {kind, pos, radius}
#   line      {kind, pos, to, width}             capsule from pos to to
#   sector    {kind, pos, radius, angle, half}   a pie slice
#   ring_gap  {kind, pos, inner, outer, gaps: [[angle, half], ...]}


static func circle(pos: Vector2, radius: float) -> Dictionary:
	return {"kind": "circle", "pos": pos, "radius": radius}


static func line(from: Vector2, to: Vector2, width: float) -> Dictionary:
	return {"kind": "line", "pos": from, "to": to, "width": width}


static func sector(pos: Vector2, radius: float, angle: float, half: float) -> Dictionary:
	return {"kind": "sector", "pos": pos, "radius": radius, "angle": angle, "half": half}


static func ring_gap(pos: Vector2, inner: float, outer: float, gaps: Array) -> Dictionary:
	return {"kind": "ring_gap", "pos": pos, "inner": inner, "outer": outer, "gaps": gaps}


static func seg_dist(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (a + ab * t).distance_to(p)


static func covers(s: Dictionary, p: Vector2, margin := 0.0) -> bool:
	var pos: Vector2 = s.get("pos", Vector2.ZERO)
	match String(s.get("kind", "")):
		"circle":
			return p.distance_to(pos) <= float(s["radius"]) + margin
		"line":
			return seg_dist(pos, s["to"], p) <= float(s["width"]) * 0.5 + margin
		"sector":
			var d := p.distance_to(pos)
			if d > float(s["radius"]) + margin:
				return false
			if d < 1.0:
				return true
			var diff := absf(wrapf((p - pos).angle() - float(s["angle"]), -PI, PI))
			return diff <= float(s["half"])
		"ring_gap":
			var d2 := p.distance_to(pos)
			if d2 < float(s["inner"]) - margin or d2 > float(s["outer"]) + margin:
				return false
			var a := (p - pos).angle()
			for g in s.get("gaps", []):
				if absf(wrapf(a - float(g[0]), -PI, PI)) <= float(g[1]):
					return false
			return true
	return false


static func extent(s: Dictionary) -> float:
	# Rough radius around pos, for culling.
	match String(s.get("kind", "")):
		"circle":
			return float(s["radius"])
		"line":
			return (s["to"] - s["pos"]).length() + float(s["width"])
		"sector":
			return float(s["radius"])
		"ring_gap":
			return float(s["outer"])
	return 0.0
