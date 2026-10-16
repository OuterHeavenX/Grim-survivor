extends Node2D
# A banner dropped by a dead carrier. It keeps rallying nearby foes at half
# strength until it fades or the player walks over it, which breaks it for a
# small XP gem.

const BannerScript := preload("res://src/enemies/behaviors/banner.gd")

var life := 6.0
var radius := 180.0
var _age := 0.0
var _pulse := 0.0


func _ready() -> void:
	add_to_group("fallen_banners")
	z_index = -1


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	_pulse -= delta
	if _pulse <= 0.0:
		_pulse = 0.4
		BannerScript.rally(self, global_position, radius, 6, 1.12, 1.1)
	var p = get_tree().get_first_node_in_group("player")
	if p and bool(p.get("alive")) and p.global_position.distance_to(global_position) < 34.0:
		var m = get_tree().get_first_node_in_group("main")
		if m:
			m.spawn_gem(global_position, 3)
			if m.hud:
				m.hud.show_warning("BANNER TORN")
		queue_free()
		return
	queue_redraw()


func is_boss() -> bool:
	return false


func _draw() -> void:
	var a := clampf(life - _age, 0.0, 1.0)
	draw_line(Vector2(-18, 10), Vector2(22, -6), Color(0.4, 0.3, 0.2, a), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(22, -6), Vector2(40, 4), Vector2(18, 8)]), Color(0.7, 0.15, 0.12, a))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1, 0.8, 0.35, 0.12 * a), 2.0)
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 20, Color(1, 1, 1, 0.5 * a), 2.0)
