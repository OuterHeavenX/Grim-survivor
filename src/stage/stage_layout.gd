class_name StageLayout
extends Node2D
# The shape of a stage: its bounds and the ruins standing in it. Walls are
# capsules and pillars circles, registered with the StageDirector as static
# obstacles that bodies slide along. They are low ruins: projectiles fly over
# them, bodies do not walk through them, so a gate or a colonnade is a choke
# point to hold rather than a wall to hide behind.
#
# Invariants
# - The start (origin) is always clear, with at least 260 px around it.
# - Every enclosed space has gates at least 240 px wide.
# - Layouts are pure data from spec(): the same stage always lays out the same.

const DEFAULT_HALF := Vector2(1500.0, 1500.0)

var spec_data: Dictionary = {}
var stone := Color(0.2, 0.22, 0.28)
var _t := 0.0


static func spec(stage_id: String) -> Dictionary:
	var walls: Array = []
	var pillars: Array = []
	var torches: Array = []
	var half := DEFAULT_HALF
	var title := ""
	match stage_id:
		"ashen_hollow":
			# A ruined keep around the start with four gates; the horde has to
			# funnel through them.
			title = "THE RUINED KEEP"
			var k := 560.0
			var g := 150.0
			for side in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				var along := Vector2(-side.y, side.x)
				var c: Vector2 = side * k
				walls.append(_w(c - along * k, c - along * g, 26.0))
				walls.append(_w(c + along * g, c + along * k, 26.0))
				torches.append(c + along * (g + 30.0) - side * 40.0)
				torches.append(c - along * (g + 30.0) - side * 40.0)
			for cx in [-1.0, 1.0]:
				for cy in [-1.0, 1.0]:
					pillars.append(_p(Vector2(cx, cy) * k, 62.0))
			# Outer rubble.
			walls.append(_w(Vector2(-1180, -300), Vector2(-1000, -520), 22.0))
			walls.append(_w(Vector2(1000, 420), Vector2(1220, 260), 22.0))
			walls.append(_w(Vector2(-260, 1100), Vector2(80, 1180), 22.0))
			walls.append(_w(Vector2(300, -1180), Vector2(560, -1040), 22.0))
		"weeping_marsh":
			title = "THE DROWNED WOODS"
			for l in [[Vector2(-900, -700), Vector2(-620, -560)], [Vector2(520, -820), Vector2(820, -660)],
					[Vector2(-1100, 300), Vector2(-860, 520)], [Vector2(760, 380), Vector2(1080, 300)],
					[Vector2(-300, 820), Vector2(40, 960)], [Vector2(240, -1180), Vector2(-60, -1060)],
					[Vector2(1160, -200), Vector2(1260, 140)]]:
				walls.append(_w(l[0], l[1], 20.0))
			for p in [Vector2(-560, -260), Vector2(620, 120), Vector2(-120, 640), Vector2(380, -560),
					Vector2(-980, -1100), Vector2(1100, 1000), Vector2(-1200, 1060)]:
				pillars.append(_p(p, 40.0))
		"throne_of_cinders":
			# A long throne hall: two colonnades split it into a nave and aisles.
			title = "THE GREAT HALL"
			half = Vector2(1050.0, 1500.0)
			var y := -1290.0
			var i := 0
			while y <= 1290.0:
				if absf(y) > 180.0:
					pillars.append(_p(Vector2(-430, y), 44.0))
					pillars.append(_p(Vector2(430, y), 44.0))
					if i % 2 == 0:
						torches.append(Vector2(-430, y + 50))
						torches.append(Vector2(430, y + 50))
				y += 285.0
				i += 1
			walls.append(_w(Vector2(-220, -1420), Vector2(220, -1420), 34.0))
		"bone_desert":
			title = "THE OPEN WASTE"
			half = Vector2(1850.0, 1250.0)
			for p in [[Vector2(-1350, -650), 110.0], [Vector2(1250, 700), 95.0], [Vector2(-700, 820), 80.0],
					[Vector2(820, -760), 90.0], [Vector2(1550, -200), 70.0], [Vector2(-1600, 300), 75.0]]:
				pillars.append(_p(p[0], p[1]))
		"sunken_road":
			# A narrow canyon road: the convoy goes north, the horde comes from
			# both ends, and there is nowhere wide to run.
			title = "THE CANYON ROAD"
			half = Vector2(620.0, 1650.0)
			var flip := 1.0
			var yy := -1450.0
			while yy < 1500.0:
				pillars.append(_p(Vector2(flip * 560.0, yy), 70.0 + 20.0 * absf(sin(yy))))
				flip = -flip
				yy += 330.0
		"drowned_reach":
			title = "THE BROKEN PIERS"
			for py in [-480.0, 480.0]:
				for seg in [[-1300.0, -820.0], [-560.0, -160.0], [160.0, 560.0], [820.0, 1300.0]]:
					walls.append(_w(Vector2(seg[0], py), Vector2(seg[1], py), 22.0))
				for x in [-1300.0, -820.0, -560.0, -160.0, 160.0, 560.0, 820.0, 1300.0]:
					pillars.append(_p(Vector2(x, py), 30.0))
		"last_bastion":
			# A fortress: curtain walls with four gates and corner towers. The
			# start is the courtyard.
			title = "THE FORTRESS"
			var k := 900.0
			var g := 170.0
			for side in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				var along := Vector2(-side.y, side.x)
				var c: Vector2 = side * k
				walls.append(_w(c - along * k, c - along * g, 32.0))
				walls.append(_w(c + along * g, c + along * k, 32.0))
				pillars.append(_p(c + along * (g + 20.0), 48.0))
				pillars.append(_p(c - along * (g + 20.0), 48.0))
				torches.append(c + along * (g + 20.0))
				torches.append(c - along * (g + 20.0))
			for cx in [-1.0, 1.0]:
				for cy in [-1.0, 1.0]:
					pillars.append(_p(Vector2(cx, cy) * k, 95.0))
					torches.append(Vector2(cx, cy) * k)
		"rotgrove":
			title = "THE ROTGROVE"
			for p in [Vector2(-700, -500), Vector2(650, -620), Vector2(-820, 640), Vector2(760, 560),
					Vector2(0, -1050), Vector2(1100, 0), Vector2(-1100, 80), Vector2(120, 1080)]:
				pillars.append(_p(p, 46.0))
	return {"half": half, "walls": walls, "pillars": pillars, "torches": torches, "title": title}


static func half_for(stage_id: String) -> Vector2:
	return spec(stage_id)["half"]


static func _w(a: Vector2, b: Vector2, r: float) -> Dictionary:
	return {"pos": a, "to": b, "radius": r}


static func _p(p: Vector2, r: float) -> Dictionary:
	return {"pos": p, "radius": r}


func setup(stage_id: String, stone_color: Color) -> void:
	spec_data = spec(stage_id)
	stone = stone_color
	name = "Layout"
	z_index = 1
	var lm = get_node_or_null("/root/LightingMan")
	for tp in spec_data["torches"]:
		var torch := Node2D.new()
		torch.position = tp
		add_child(torch)
		if lm:
			lm.attach_aura(torch, Color(1.0, 0.6, 0.28), 2.6, 0.75, true)


func obstacles() -> Array:
	return spec_data.get("walls", []) + spec_data.get("pillars", [])


func _process(delta: float) -> void:
	_t += delta
	if not spec_data.get("torches", []).is_empty():
		queue_redraw()


func _draw() -> void:
	if spec_data.is_empty():
		return
	var top := stone.lightened(0.18)
	var dark := stone.darkened(0.45)
	for w in spec_data["walls"]:
		var a: Vector2 = w["pos"]
		var b: Vector2 = w["to"]
		var r: float = w["radius"]
		var sh := Vector2(10, 14)
		draw_line(a + sh, b + sh, Color(0, 0, 0, 0.45), r * 2.0)
		draw_circle(a + sh, r, Color(0, 0, 0, 0.45))
		draw_circle(b + sh, r, Color(0, 0, 0, 0.45))
		draw_line(a, b, dark, r * 2.0)
		draw_circle(a, r, dark)
		draw_circle(b, r, dark)
		draw_line(a + Vector2(0, -4), b + Vector2(0, -4), stone, r * 1.5)
		draw_line(a + Vector2(0, -r * 0.55), b + Vector2(0, -r * 0.55), top, 3.0)
		# Mortar joints across the wall.
		var d := b - a
		var n := int(d.length() / 46.0)
		var u := d.normalized()
		var perp := Vector2(-u.y, u.x)
		for i in range(1, n):
			var c := a + u * (float(i) * 46.0)
			draw_line(c - perp * r * 0.7, c + perp * r * 0.7, Color(0, 0, 0, 0.35), 2.0)
		# Rubble at the broken ends.
		for e in [a, b]:
			for k in 3:
				var off := Vector2.from_angle(float(k) * 2.1 + e.x * 0.01) * (r + 8.0)
				draw_circle(e + off, 5.0 + float(k), stone.darkened(0.2))
	for pl in spec_data["pillars"]:
		var p: Vector2 = pl["pos"]
		var r: float = pl["radius"]
		draw_circle(p + Vector2(10, 14), r, Color(0, 0, 0, 0.45))
		draw_circle(p, r, dark)
		draw_circle(p + Vector2(-2, -4), r * 0.82, stone)
		draw_arc(p + Vector2(-2, -4), r * 0.82, PI * 1.1, PI * 1.9, 16, top, 3.0)
		draw_arc(p, r, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 2.0)
	for tp in spec_data["torches"]:
		var f := 0.85 + 0.15 * sin(_t * 11.0 + tp.x * 0.05) + 0.08 * sin(_t * 23.0 + tp.y)
		draw_rect(Rect2(tp + Vector2(-4, -6), Vector2(8, 14)), Color(0.22, 0.16, 0.1))
		draw_circle(tp + Vector2(0, -10), 9.0 * f, Color(1.0, 0.5, 0.15, 0.6))
		draw_circle(tp + Vector2(0, -12), 5.0 * f, Color(1.0, 0.85, 0.45))
