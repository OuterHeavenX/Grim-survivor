class_name EnemyBehavior
extends Node
# A role's behaviour, attached to an enemy as a child by EnemyData.behavior.
# enemy.gd calls these hooks and otherwise knows nothing about the role.

var enemy = null
var params: Dictionary = {}
var t := 0.0


func attach(p_enemy, p_params: Dictionary) -> void:
	enemy = p_enemy
	# A copy: runtime tweaks must never write back into the shared EnemyData.
	params = p_params.duplicate()
	name = "Behavior"
	_setup()


func _setup() -> void:
	pass


# Movement direction this frame. Return dir unchanged to walk at the player;
# its length scales speed (0 = stand still).
func step(_delta: float, dir: Vector2) -> Vector2:
	return dir


func modify_damage(amount: float, _from_pos: Vector2, _source: String) -> float:
	return amount


func can_contact() -> bool:
	return true


# Draw the body procedurally. Return true if drawn (skips the default).
func draw_body(_c: CanvasItem) -> bool:
	return false


func on_death() -> void:
	pass


func pf(key: String, fallback: float) -> float:
	return float(params.get(key, fallback))


func main():
	return enemy.main


func player():
	return enemy.player if enemy.player and is_instance_valid(enemy.player) else null


func ppos() -> Vector2:
	var p = player()
	return p.global_position if p else enemy.global_position


func shadow(c: CanvasItem, r: float) -> void:
	c.draw_set_transform(Vector2(0, r * 0.95), 0.0, Vector2(1.0, 0.4))
	c.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func robe(c: CanvasItem, body: Color, trim: Color, eyes: Color) -> void:
	# Shared hooded-cultist silhouette; roles add their own prop on top.
	var sway := sin(t * 6.0) * 2.0
	shadow(c, 14.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-11, -4), Vector2(11, -4), Vector2(14 + sway, 18), Vector2(-14 + sway, 18)]), body)
	c.draw_circle(Vector2(0, -12), 10.0, body.darkened(0.3))
	c.draw_arc(Vector2(0, -12), 10.0, PI, TAU, 12, trim, 2.0)
	c.draw_circle(Vector2(-3.5, -12), 2.0, eyes)
	c.draw_circle(Vector2(3.5, -12), 2.0, eyes)
