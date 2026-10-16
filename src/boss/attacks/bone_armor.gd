extends BossAttack
# Passive: the Pale Herald draws bone plates out of nearby piles and wears
# them. While any plate stands, damage to the boss is cut by `reduction` and
# its spear volleys grow. Break every plate and the weak point is exposed for
# the rest of the fight. Plates are enemies, so every weapon can hit them.

var plates: Array = []
var exposed := false
var _ring: Node2D = null


func start() -> void:
	var n := pi("plates", 4)
	var r = rule()
	var extra := 0
	if r and r.has_method("take_pile_spots"):
		extra = r.take_pile_spots(bpos(), 2).size()
	n = clampi(2 + extra, 2, n)
	for i in n:
		var p = ctl.spawn_minion("bone_plate", bpos(), true)
		if p:
			p.set("is_boss_object", true)
			if p.behavior:
				p.behavior.set("anchor", boss())
				p.behavior.set("orbit_index", i)
				p.behavior.set("orbit_count", n)
			plates.append(p)
	_ring = ArmorRing.new()
	_ring.host = self
	ctl.own_object(_ring)
	if main().hud:
		main().hud.show_warning("BREAK THE BONE PLATES")


func armor_up() -> bool:
	return alive_plates() > 0


func alive_plates() -> int:
	var n := 0
	for p in plates:
		if is_instance_valid(p) and not bool(p.get("dead")):
			n += 1
	return n


func tick(_delta: float) -> void:
	if not exposed and not plates.is_empty() and alive_plates() == 0:
		exposed = true
		if main().hud:
			main().hud.show_warning("WEAK POINT EXPOSED")
		if main().jm:
			main().jm.shockwave(bpos(), Color(1, 0.9, 0.6), 220.0)


func modify_damage(amount: float, _from: Vector2, _source: String) -> float:
	if armor_up():
		return amount * (1.0 - pf("reduction", 0.7))
	if exposed:
		return amount * pf("exposed_mult", 1.25)
	return amount


func stop() -> void:
	for p in plates:
		if is_instance_valid(p):
			p.queue_free()
	plates.clear()
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()


class ArmorRing extends Node2D:
	# Mobile-scale readout: a thick ring with one notch per standing plate,
	# or a pulsing target once the weak point is open.
	var host = null
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		if host == null or host.ctl == null or not is_instance_valid(host.ctl.boss):
			return
		global_position = host.ctl.boss.global_position
		z_index = 6
		queue_redraw()

	func _draw() -> void:
		if host == null:
			return
		var n: int = host.alive_plates()
		if n > 0:
			draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 48, Color(0.95, 0.9, 0.75, 0.55), 6.0)
			for i in n:
				var a := TAU * float(i) / float(maxi(1, n)) + t
				draw_circle(Vector2.from_angle(a) * 70.0, 7.0, Color(1, 0.95, 0.8, 0.9))
		elif host.exposed:
			var pulse := 0.5 + 0.5 * sin(t * 8.0)
			draw_arc(Vector2.ZERO, 30.0 + 6.0 * pulse, 0.0, TAU, 32, Color(1, 0.3, 0.3, 0.9), 4.0)
			draw_line(Vector2(-40, 0), Vector2(-22, 0), Color(1, 0.3, 0.3), 3.0)
			draw_line(Vector2(22, 0), Vector2(40, 0), Color(1, 0.3, 0.3), 3.0)
			draw_line(Vector2(0, -40), Vector2(0, -22), Color(1, 0.3, 0.3), 3.0)
			draw_line(Vector2(0, 22), Vector2(0, 40), Color(1, 0.3, 0.3), 3.0)
