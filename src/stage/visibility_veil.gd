extends Node2D
# A darkness ring around the player for storms, ashfall and the convoy's
# night. It is drawn in world space below hazard outlines (TimedHazard.TOP_Z),
# so it can never hide a warning, and it leaves a clear circle around the
# player so the immediate fight is always readable.

var strength := 0.0
var target := 0.0
var clear_radius := 300.0
var target_clear := 300.0
var tint := Color(0.03, 0.03, 0.05)
var _gm = null


func _ready() -> void:
	z_as_relative = false
	z_index = 55
	_gm = get_node_or_null("/root/GameManager")


func set_veil(p_strength: float, p_clear := 300.0, p_tint := Color(0.03, 0.03, 0.05)) -> void:
	target = clampf(p_strength, 0.0, 0.8)
	target_clear = p_clear
	tint = p_tint


func _process(delta: float) -> void:
	strength = move_toward(strength, target, delta * 0.6)
	clear_radius = move_toward(clear_radius, target_clear, delta * 200.0)
	var p = get_tree().get_first_node_in_group("player")
	if p:
		global_position = p.global_position
	visible = strength > 0.01
	if visible:
		queue_redraw()


func _draw() -> void:
	# Soft edge from concentric bands; the outermost reaches past the screen
	# corners of a 720x1280 view.
	var bands := 6
	var outer := 1600.0
	for i in bands:
		var f := float(i + 1) / float(bands)
		var r0 := lerpf(clear_radius, clear_radius + 260.0, float(i) / float(bands))
		var w := 260.0 / float(bands) + 2.0
		draw_arc(Vector2.ZERO, r0 + w * 0.5, 0.0, TAU, 64, Color(tint, strength * f * 0.9), w)
	var r1 := clear_radius + 260.0
	draw_arc(Vector2.ZERO, (r1 + outer) * 0.5, 0.0, TAU, 64, Color(tint, strength * 0.9), outer - r1)
