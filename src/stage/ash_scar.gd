class_name AshScar
extends TimedHazard
# Ashen Hollow's cinder scar, shared with the Last Bastion's remix.
#   crack    dark fissures appear (part of the warning, harmless)
#   glow     the fissures fill with ember light (still harmless)
#   erupt    damages the player and any foe standing on it
#   cooled   grey ash: safe ground no new scar may form on until it fades

var crack_time := 0.6


static func make(rule: StageRule, pos: Vector2, prm: Dictionary) -> AshScar:
	var s := AshScar.new()
	var r := float(prm.get("radius", 70.0))
	s.crack_time = float(prm.get("crack_time", 0.6))
	var warn: float = s.crack_time + rule.data.warn_time
	s.setup(HazardShape.circle(pos, r), warn, float(prm.get("active", 0.35)),
		rule.scaled(float(prm.get("dmg", 16.0))), rule.data.color, rule.source_tag(), "stage")
	s.enemy_damage = float(prm.get("enemy_dmg", 40.0))
	s.knockback = 120.0
	s.recover_time = float(prm.get("recover", 0.3))
	s.linger_time = float(prm.get("cooled", 6.0))
	s.ignitable = true
	s.icon = "flame"
	s.add_to_group("ash_scars")
	rule.main.add_hazard_node(s)
	return s


static func on_cooled_ground(tree: SceneTree, p: Vector2, r: float) -> bool:
	for s in tree.get_nodes_in_group("ash_scars"):
		if s.is_lingering() and s.global_position.distance_to(p) < float(s.shape["radius"]) + r:
			return true
	return false


func is_cooled() -> bool:
	return is_lingering()


func _draw() -> void:
	if phase != Phase.WARN:
		super._draw()
		return
	var o := _opacity()
	var r: float = shape["radius"]
	var f := clampf(age / maxf(crack_time, 0.01), 0.0, 1.0)
	var glow := clampf((age - crack_time) / maxf(warn_time - crack_time, 0.01), 0.0, 1.0)
	draw_circle(Vector2.ZERO, r, Color(0.05, 0.03, 0.03, 0.35 * o))
	# Fissures: fixed per scar (seeded by instance), growing outward.
	var seed_a := float(get_instance_id() % 997)
	for i in 6:
		var a := seed_a + TAU * float(i) / 6.0
		var p0 := Vector2.from_angle(a) * r * 0.12
		var p1 := Vector2.from_angle(a + 0.25) * r * 0.55 * f
		var p2 := Vector2.from_angle(a - 0.15) * r * 0.95 * f
		var col := Color(0.12, 0.08, 0.06, 0.9).lerp(Color(1.0, 0.55, 0.15, 0.95), glow)
		draw_polyline(PackedVector2Array([p0, p1, p2]), Color(col, col.a * o), 3.0 + 2.0 * glow)
	if glow > 0.0:
		draw_circle(Vector2.ZERO, r * glow, Color(1.0, 0.45, 0.12, 0.22 * o))
