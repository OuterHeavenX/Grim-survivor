extends Node2D
# A toxic bloom floating in marsh water. Standing in it poisons you a little.
# Fire detonates it after a short fuse: a big hit to foes, a tuned smaller one
# to you. The blast reports as "stage:bloom", not fire, so it can never set
# off its neighbours: one fire blast, one generation of blooms.

var rule = null
var radius := 58.0
var _t := 0.0
var _tick := 0.0
var _armed := false


func _ready() -> void:
	add_to_group("blooms")
	z_index = -1


func detonate() -> TimedHazard:
	if _armed or rule == null:
		return null
	_armed = true
	var blast: float = float(rule.p("bloom_blast", 130.0))
	var h := TimedHazard.new()
	h.setup(HazardShape.circle(global_position, blast), float(rule.p("bloom_fuse", 0.7)), 0.25,
		rule.scaled(float(rule.p("bloom_player_dmg", 10.0))), Color(0.6, 1.0, 0.3), "stage:bloom", "stage")
	h.enemy_damage = float(rule.p("bloom_enemy_dmg", 90.0))
	h.knockback = 200.0
	h.icon = "skull"
	rule.main.add_hazard_node(h)
	queue_free()
	return h


func _physics_process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		var p = get_tree().get_first_node_in_group("player")
		if p and bool(p.get("alive")) and p.global_position.distance_to(global_position) < radius:
			p.take_damage(rule.scaled(3.0) if rule else 3.0, "stage:bloom_poison")
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(Vector2.ZERO, radius, Color(0.45, 0.8, 0.25, 0.18 + 0.08 * pulse))
	for i in 6:
		var a := TAU * float(i) / 6.0 + _t * 0.3
		draw_circle(Vector2.from_angle(a) * radius * 0.5, 10.0, Color(0.6, 0.95, 0.3, 0.7))
	draw_circle(Vector2.ZERO, 12.0, Color(0.85, 1.0, 0.5, 0.9))
	# A flame glyph on the rim: "fire sets this off".
	var f := Vector2(0, -radius - 12.0)
	draw_colored_polygon(PackedVector2Array([f + Vector2(-6, 6), f + Vector2(6, 6), f + Vector2(0, -10)]), Color(1, 0.55, 0.2, 0.9))
