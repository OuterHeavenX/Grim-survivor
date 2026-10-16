extends EnemyBehavior
# Banner carrier: rallies up to max_buffed nearby foes (faster, harder
# hitting). When it dies the banner falls and keeps a weaker rally going for
# fallen_time unless the player tramples it.

const FallenScript := preload("res://src/enemies/fallen_banner.gd")

var _pulse := 0.0
var buffed := 0


func step(delta: float, dir: Vector2) -> Vector2:
	t += delta
	_pulse -= delta
	if _pulse <= 0.0:
		_pulse = 0.4
		buffed = rally(enemy, enemy.global_position, pf("radius", 220.0), int(pf("max_buffed", 8.0)),
			pf("speed_buff", 1.25), pf("damage_buff", 1.2))
	# Stays behind its troops.
	return dir * 0.8


static func rally(source, at: Vector2, radius: float, cap: int, spd: float, dmg: float) -> int:
	var n := 0
	for e in source.get_tree().get_nodes_in_group("enemies"):
		if n >= cap:
			break
		if e == source or bool(e.get("dead")) or e.is_boss() or bool(e.get("is_boss_object")):
			continue
		if e.global_position.distance_to(at) <= radius:
			e.apply_rally(spd, dmg, 0.6)
			n += 1
	return n


func on_death() -> void:
	var m = main()
	if m == null or m.run == null:
		return
	var f = FallenScript.new()
	f.position = enemy.global_position
	f.life = pf("fallen_time", 6.0)
	f.radius = pf("radius", 220.0) * 0.8
	f.add_to_group("stage_objects")
	m.run.add_child(f)


func draw_body(c: CanvasItem) -> bool:
	robe(c, Color(0.3, 0.22, 0.1), Color(1.0, 0.8, 0.35), Color(1, 0.85, 0.4))
	c.draw_set_transform(Vector2.ZERO, -enemy.rotation, Vector2.ONE)
	c.draw_line(Vector2(12, 18), Vector2(12, -46), Color(0.4, 0.3, 0.2), 3.0)
	var wave := sin(t * 5.0) * 4.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(12, -46), Vector2(40, -40 + wave), Vector2(12, -28)]), Color(0.75, 0.15, 0.12))
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	c.draw_arc(Vector2.ZERO, pf("radius", 220.0), 0.0, TAU, 48, Color(1, 0.8, 0.35, 0.12 + 0.08 * pulse), 2.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
