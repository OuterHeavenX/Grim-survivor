extends BossAttack
# Passive: after each major attack the Sovereign's core lies open for a short
# window and takes extra damage. The window is drawn as a pulsing core so the
# player knows when to commit.

var _glow: Node2D = null


func start() -> void:
	ctl.major_committed.connect(_on_major)
	_glow = Core.new()
	_glow.host = self
	ctl.own_object(_glow)


func _on_major(_id: String) -> void:
	ctl.open_punish_window(pf("window", 2.6), pf("mult", 1.6))
	if main().hud:
		main().hud.show_warning("THE CORE IS OPEN")


func stop() -> void:
	if ctl.major_committed.is_connected(_on_major):
		ctl.major_committed.disconnect(_on_major)
	if _glow and is_instance_valid(_glow):
		_glow.queue_free()


class Core extends Node2D:
	var host = null
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		if host == null or not is_instance_valid(host.ctl.boss):
			return
		global_position = host.ctl.boss.global_position
		z_index = 7
		visible = host.ctl.is_vulnerable()
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 10.0)
		draw_circle(Vector2(0, 8), 16.0 + 6.0 * pulse, Color(1.0, 0.9, 0.5, 0.55))
		draw_arc(Vector2(0, 8), 30.0 + 6.0 * pulse, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 3.0)
