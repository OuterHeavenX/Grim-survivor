extends Node2D
# A bastion ward. Dormant until the player stands in it long enough (when
# the rule allows), then active until foes crowding it wear it down.

var rule = null
var kind := "flame"
var state := "dormant"      # dormant, active, lost
var activatable := false
var radius := 110.0
var max_hp := 400.0
var hp := 400.0
var _hold := 0.0
var _wear := 0.0
var _t := 0.0

const COLORS := {"flame": Color(1.0, 0.5, 0.2), "stone": Color(0.75, 0.75, 0.85), "wind": Color(0.5, 0.95, 0.85)}
const GLYPH := {"flame": "F", "stone": "S", "wind": "W"}


func _ready() -> void:
	add_to_group("wards")
	z_index = -1


func needs_player() -> bool:
	return state == "dormant" and activatable


func light() -> void:
	if state != "dormant":
		return
	state = "active"
	hp = max_hp
	if rule:
		rule.on_ward_lit(self)


func damage(v: float) -> void:
	if state != "active":
		return
	hp -= v
	if hp <= 0.0:
		hp = 0.0
		state = "lost"
		if rule:
			rule.on_ward_lost(self)


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if needs_player():
		var p = get_tree().get_first_node_in_group("player")
		if p and bool(p.get("alive")) and p.global_position.distance_to(global_position) < radius:
			_hold += delta
			if _hold >= float(rule.p("ward_activate", 1.6)):
				light()
		else:
			_hold = 0.0
	elif state == "active":
		_wear -= delta
		if _wear <= 0.0:
			_wear = 0.5
			var dmg := 0.0
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.dmg > 0.0 and e.global_position.distance_to(global_position) < radius + 30.0:
					dmg += float(e.dmg) * 0.25
			if dmg > 0.0:
				damage(dmg)


func _draw() -> void:
	var col: Color = COLORS.get(kind, Color.WHITE)
	var a := 0.35 if state == "lost" else 1.0
	draw_circle(Vector2.ZERO, radius, Color(col, 0.07 * a))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(col, 0.5 * a), 3.0)
	draw_rect(Rect2(-18, -50, 36, 56), Color(0.3, 0.28, 0.26, a))
	if state == "active":
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(Vector2(0, -56), 12.0 + 3.0 * pulse, Color(col, 0.9))
		draw_rect(Rect2(-40, 14, 80, 8), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-40, 14, 80.0 * hp / maxf(max_hp, 1.0), 8), Color(col, 0.95))
	elif state == "lost":
		draw_line(Vector2(-18, -50), Vector2(18, 6), Color(0.1, 0.1, 0.1), 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(-12, -18), str(GLYPH.get(kind, "?")), HORIZONTAL_ALIGNMENT_CENTER, 24, 22, Color(1, 1, 1, a))
	if _hold > 0.0 and needs_player():
		draw_arc(Vector2.ZERO, radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * _hold / float(rule.p("ward_activate", 1.6)), 32, Color(1, 1, 1, 0.9), 4.0)
