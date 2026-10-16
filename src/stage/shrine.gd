extends Node2D
# An optional roadside shrine on the Sunken Road. Stand in it for ACTIVATE
# seconds to accept its bargain, a reward with a curse attached, for the rest
# of the stage. Ignoring it costs nothing.

const ACTIVATE := 1.5
const RADIUS := 70.0
const BARGAINS := {
	"blood": {"name": "SHRINE OF BLOOD: +25% DAMAGE, +20% HARM", "mods": {"damage": 1.25, "damage_taken": 1.2}},
	"haste": {"name": "SHRINE OF HASTE: +15% SPEED, +10% HARM", "mods": {"speed": 1.15, "damage_taken": 1.1}},
	"greed": {"name": "SHRINE OF GREED: SHARDS, AND COMPANY", "mods": {}},
}

var rule = null
var kind := "blood"
var used := false
var _hold := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("shrines")
	z_index = -1


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if used:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p and bool(p.get("alive")) and p.global_position.distance_to(global_position) < RADIUS:
		_hold += delta
		if _hold >= ACTIVATE:
			accept()
	else:
		_hold = 0.0


func accept() -> void:
	if used or rule == null:
		return
	used = true
	var b: Dictionary = BARGAINS[kind]
	if not (b["mods"] as Dictionary).is_empty():
		rule.gm.mods.set_mods("stage:shrine:" + kind, b["mods"])
	if kind == "greed":
		for i in 10:
			rule.main.spawn_shard(global_position + Vector2.from_angle(float(i)) * 30.0, 1)
		var pool: Array = rule.gm.stage_data()["pool"]
		for i in 4:
			rule.main._spawn_enemy(str(pool[i % pool.size()]), rule.ring_point(global_position, 250.0, 320.0))
	rule.announce(str(b["name"]))


func _draw() -> void:
	var col := Color(0.6, 0.6, 0.65) if used else Color(0.95, 0.75, 0.45)
	draw_circle(Vector2.ZERO, RADIUS, Color(col, 0.08))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(col, 0.6), 2.0)
	draw_rect(Rect2(-10, -40, 20, 44), Color(0.3, 0.27, 0.25))
	draw_circle(Vector2(0, -46), 9.0, Color(col, 0.9))
	if _hold > 0.0 and not used:
		draw_arc(Vector2.ZERO, RADIUS + 8.0, -PI * 0.5, -PI * 0.5 + TAU * _hold / ACTIVATE, 32, Color(1, 1, 1, 0.9), 4.0)
