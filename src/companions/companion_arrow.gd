extends Node2D
# A Bone Archer's arrow: straight, fast, pierces a few foes, then fades.

const SPEED := 950.0
const LIFE := 0.75
const PIERCE := 3

var vel := Vector2.ZERO
var dmg := 10.0
var kb := 100.0
var color := Color(0.6, 0.85, 1.0)
var source := "companion:archer"
var _age := 0.0
var _hit := {}


func setup(pos: Vector2, dir: Vector2, p_dmg: float, p_kb: float, p_color: Color, p_source: String) -> void:
	position = pos
	vel = dir * SPEED
	dmg = p_dmg
	kb = p_kb
	color = p_color
	source = p_source
	rotation = dir.angle()


func _ready() -> void:
	add_to_group("stage_objects")
	z_index = 5


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	position += vel * delta
	for e in get_tree().get_nodes_in_group("enemies"):
		if _hit.has(e.get_instance_id()) or not is_instance_valid(e) or bool(e.get("dead")):
			continue
		if global_position.distance_to(e.global_position) <= float(e.get("body_radius")) + 8.0:
			_hit[e.get_instance_id()] = true
			e.take_damage(dmg, global_position - vel.normalized() * 20.0, kb, source)
			if _hit.size() >= PIERCE:
				queue_free()
				return
	queue_redraw()


func _draw() -> void:
	var a := clampf((LIFE - _age) * 6.0, 0.0, 1.0)
	draw_polygon(PackedVector2Array([Vector2(-6, -2.5), Vector2(-46, 0), Vector2(-6, 2.5)]),
		PackedColorArray([Color(color, 0.55 * a), Color(color, 0.0), Color(color, 0.55 * a)]))
	draw_line(Vector2(-14, 0), Vector2(10, 0), Color(0.85, 0.82, 0.75, a), 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(8, -4), Vector2(8, 4)]), Color(color.lightened(0.5), a))
