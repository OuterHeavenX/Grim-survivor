class_name StageObjective
extends Node2D
# An optional goal with HUD progress. Objectives are never on the critical
# path: a time limit always ends them, success or not, so none can hold the
# boss back. Progress only moves in _physics_process, so it pauses with the
# game.
#
# kind "hold":   progress fills while the player stands in the zone.
# kind "manual": the owner sets progress (kills, portals closed...).

signal completed(obj)
signal failed(obj)

var label := "OBJECTIVE"
var kind := "hold"
var radius := 160.0
var goal := 20.0           # seconds of holding, or count for manual
var progress := 0.0
var time_limit := 0.0      # 0 = none
var elapsed := 0.0
var state := "active"      # active, done, failed
var color := Color(1.0, 0.8, 0.4)
var decay := 0.0           # progress lost per second outside a hold zone

var _gm = null


func _ready() -> void:
	add_to_group("objectives")
	add_to_group("stage_objects")
	z_index = -2
	_gm = get_node_or_null("/root/GameManager")


func frac() -> float:
	return clampf(progress / maxf(goal, 0.001), 0.0, 1.0)


func is_active() -> bool:
	return state == "active"


func hud_text() -> String:
	var s := "%s  %d%%" % [label, int(frac() * 100.0)]
	if time_limit > 0.0 and is_active():
		s += "  %ds" % int(ceil(time_limit - elapsed))
	return s


func player_inside() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	return p != null and bool(p.get("alive")) and p.global_position.distance_to(global_position) <= radius


func add_progress(v: float) -> void:
	if not is_active():
		return
	progress = minf(goal, progress + v)
	if progress >= goal:
		state = "done"
		completed.emit(self)


func _physics_process(delta: float) -> void:
	if not is_active():
		queue_redraw()
		return
	elapsed += delta
	if kind == "hold":
		var spd: float = _gm.mods.mult("objective_speed") if _gm else 1.0
		if player_inside():
			add_progress(delta * spd)
		elif decay > 0.0:
			progress = maxf(0.0, progress - decay * delta)
	if is_active() and time_limit > 0.0 and elapsed >= time_limit:
		state = "failed"
		failed.emit(self)
	queue_redraw()


func _draw() -> void:
	if kind != "hold":
		return
	var inside := player_inside()
	var pulse := 0.5 + 0.5 * sin(elapsed * 4.0)
	var a := 1.0 if is_active() else 0.35
	draw_circle(Vector2.ZERO, radius, Color(color, (0.08 + (0.06 if inside else 0.0)) * a))
	# Dashed rim plus a progress arc: the zone and its state read by shape.
	for i in 24:
		var a0 := TAU * float(i) / 24.0
		draw_arc(Vector2.ZERO, radius, a0, a0 + TAU / 48.0, 4, Color(color, (0.55 + 0.3 * pulse) * a), 3.0)
	draw_arc(Vector2.ZERO, radius + 10.0, -PI * 0.5, -PI * 0.5 + TAU * frac(), 48, Color(1, 1, 1, 0.9 * a), 5.0)
