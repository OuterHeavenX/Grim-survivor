extends BossAttack
# The Maw's tongue: a tether that drags the player in. It is breakable two
# ways, and both are explicit: pull against it for strain_needed seconds, or
# hurt the boss for 6% of its health while it holds. The pull is always
# weaker than the player's own walking speed, so it slows you, never traps
# you.

const BREAK_DAMAGE := 0.06

var _active := false
var _t := 0.0
var _strain := 0.0
var _hp_at_start := 0.0
var _line: Line2D = null


func telegraph() -> void:
	var s := HazardShape.line(bpos(), ppos(), 22.0)
	var h := hazard(s, 0.05, 0.0)
	h.player_damage = 0.0
	h.icon = "warn"


func commit() -> void:
	if player() == null or ppos().distance_to(bpos()) > pf("range", 620.0):
		return
	_active = true
	_t = 0.0
	_strain = 0.0
	_hp_at_start = float(boss().hp)
	_line = Line2D.new()
	_line.width = 9.0
	_line.default_color = Color(0.85, 0.3, 0.4, 0.9)
	_line.z_index = 5
	ctl.own_object(_line)


func is_running() -> bool:
	return _active


func max_pull() -> float:
	var p = player()
	var walk: float = float(p.BASE_SPEED) * float(ctl.gm.speed_mult()) if p else 270.0
	return minf(pf("pull", 120.0), walk * 0.45)


func tick(delta: float) -> void:
	if not _active:
		return
	var p = player()
	if p == null or not bool(p.alive):
		stop()
		return
	_t += delta
	var to_boss: Vector2 = bpos() - p.global_position
	var d := to_boss.normalized() if to_boss.length() > 1.0 else Vector2.ZERO
	var mv: Vector2 = p.move_vec
	if mv.length() > 0.3 and mv.normalized().dot(-d) > 0.3:
		_strain += delta
	if _strain >= pf("strain_needed", 1.0) or _hp_at_start - float(boss().hp) >= float(boss().max_hp) * BREAK_DAMAGE:
		_snap(true)
		return
	if _t >= pf("duration", 2.6):
		_snap(false)
		return
	p.add_push(d * max_pull())
	if _line and is_instance_valid(_line):
		_line.points = PackedVector2Array([bpos(), p.global_position])
		_line.default_color.a = 0.6 + 0.3 * sin(_t * 20.0)


func _snap(broken: bool) -> void:
	if broken and main().hud:
		main().hud.show_warning("TETHER BROKEN")
	stop()


func stop() -> void:
	_active = false
	if _line and is_instance_valid(_line):
		_line.queue_free()
	_line = null
