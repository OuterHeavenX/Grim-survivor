class_name BossAttack
extends RefCounted
# Base for a reusable boss attack. telegraph() runs at wind-up and should put
# every threat on the ground with its warning; commit() runs when the wind-up
# ends. Attacks that play out over time return true from is_running() and get
# tick() until they finish. Passives use start()/tick()/stop() and may adjust
# incoming damage.

var ctl: BossController
var data: BossAttackData
var params: Dictionary = {}
var dir := Vector2.RIGHT


func init(p_ctl: BossController, p_data: BossAttackData) -> void:
	ctl = p_ctl
	data = p_data
	params = data.params
	_setup()


func _setup() -> void:
	pass


func warn_time() -> float:
	return maxf(data.warn, ctl.data.min_warn)


func budget_cost() -> int:
	return data.budget_cost


func available() -> bool:
	return true


func telegraph() -> void:
	pass


func commit() -> void:
	pass


func is_running() -> bool:
	return false


func start() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func stop() -> void:
	pass


func modify_damage(amount: float, _from_pos: Vector2, _source: String) -> float:
	return amount


# --- helpers -----------------------------------------------------------------

func boss():
	return ctl.boss


func main():
	return ctl.main


func player():
	var m = ctl.main
	return m.player if m and m.player and is_instance_valid(m.player) else null


func ppos() -> Vector2:
	var p = player()
	return p.global_position if p else bpos()


func pvel() -> Vector2:
	var p = player()
	return p.velocity if p else Vector2.ZERO


func bpos() -> Vector2:
	return ctl.boss.global_position


func pf(key: String, fallback: float) -> float:
	return float(params.get(key, fallback))


func pi(key: String, fallback: int) -> int:
	return int(params.get(key, fallback))


func ps(key: String, fallback: String) -> String:
	return str(params.get(key, fallback))


func rng() -> RandomNumberGenerator:
	return ctl.rng


func dmg(mult: float) -> float:
	return float(ctl.boss.dmg) * mult


func hazard(shape: Dictionary, active: float, mult: float, warn := -1.0) -> TimedHazard:
	return ctl.spawn_hazard(shape, warn_time() if warn < 0.0 else warn, active, dmg(mult), String(data.id))


func rule():
	var m = ctl.main
	if m and m.director and is_instance_valid(m.director):
		return m.director.rule
	return null


func safe_with(shapes: Array, center := Vector2.INF) -> bool:
	var c := ppos() if center == Vector2.INF else center
	return SafeSpace.pattern_ok(ctl.get_tree(), c, shapes, 420.0, ctl.data.min_safe_fraction, 230.0)


func clamp_arena(v: Vector2, margin := 60.0) -> Vector2:
	return ctl.main.clamp_arena(v, margin)
