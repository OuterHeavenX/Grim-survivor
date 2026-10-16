extends BossAttack
# Passive: a whirlpool centred on the Drowned Maw drags the player inward.
# Each standing anchor strengthens it; destroying anchors weakens it. Rotating
# lanes of calm water cancel the pull entirely. The pull is hard-capped below
# the player's own walking speed, so walking out always works.

const ESCAPE_SHARE := 0.55

var _t := 0.0
var _swirl: Node2D = null


func start() -> void:
	_swirl = Swirl.new()
	_swirl.host = self
	ctl.own_object(_swirl)
	if main().hud:
		main().hud.show_warning("SINK THE ANCHORS")


func anchors() -> int:
	var n := 0
	for e in ctl.get_tree().get_nodes_in_group("enemies"):
		if String(e.get("etype")) == "anchor" and not bool(e.get("dead")):
			n += 1
	return n


func strength() -> float:
	var p = player()
	var walk: float = float(p.BASE_SPEED) * float(ctl.gm.speed_mult()) if p else 270.0
	var want := pf("pull", 95.0) + pf("per_anchor", 25.0) * float(anchors())
	return minf(minf(want, pf("max_pull", 135.0)), walk * ESCAPE_SHARE)


func lane_angle(i: int) -> float:
	var n := maxi(1, pi("lanes", 2))
	return _t * pf("lane_rot", 0.35) + TAU * float(i) / float(n)


func in_calm_lane(p: Vector2) -> bool:
	var a := (p - bpos()).angle()
	for i in pi("lanes", 2):
		if absf(wrapf(a - lane_angle(i), -PI, PI)) <= pf("lane_half", 0.45):
			return true
	return false


func tick(delta: float) -> void:
	_t += delta
	var p = player()
	if p == null or not bool(p.alive) or ctl.submerged:
		return
	var d: Vector2 = bpos() - p.global_position
	if d.length() < 1.0 or d.length() > 900.0 or in_calm_lane(p.global_position):
		return
	p.add_push(d.normalized() * strength())


func stop() -> void:
	if _swirl and is_instance_valid(_swirl):
		_swirl.queue_free()


class Swirl extends Node2D:
	var host = null

	func _process(_d: float) -> void:
		if host == null or not is_instance_valid(host.ctl.boss):
			return
		global_position = host.ctl.boss.global_position
		z_index = -2
		queue_redraw()

	func _draw() -> void:
		var t: float = host._t
		for i in 5:
			var r := 140.0 + 120.0 * float(i)
			draw_arc(Vector2.ZERO, r, t * 1.2 + float(i), t * 1.2 + float(i) + 2.4, 24,
				Color(0.4, 0.75, 1.0, 0.25), 4.0)
		# Calm lanes: bright, with chevrons pointing outward.
		for i in host.pi("lanes", 2):
			var a: float = host.lane_angle(i)
			var u := Vector2.from_angle(a)
			draw_line(u * 120.0, u * 700.0, Color(0.85, 1.0, 0.95, 0.45), 6.0)
			for k in 5:
				var c := u * (180.0 + 110.0 * float(k))
				var n := Vector2(-u.y, u.x) * 14.0
				draw_polyline(PackedVector2Array([c - u * 12.0 + n, c, c - u * 12.0 - n]), Color(1, 1, 1, 0.7), 3.0)
