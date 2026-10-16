class_name RelicEffect
extends RefCounted
# Behaviour for a relic that a stat modifier cannot express. Every hook has a
# harmless default; an effect overrides only what it needs. Damage an effect
# deals must use source "relic:<id>" so CombatRules never chains off it.

var mgr = null
var id := ""
var data: RelicData


func source() -> String:
	return "relic:" + id


func gm():
	return mgr.gm


func main():
	return mgr.main


func on_added() -> void:
	pass


func on_hit(_e, amount: float, _source: String, _kb: float) -> float:
	return amount


func contact_damage(_e, amount: float) -> float:
	return amount


func on_kill(_e, _source: String) -> void:
	pass


func on_player_hit(_amount: float, _source: String) -> void:
	pass


func on_explosion(_pos: Vector2, _radius: float, _source: String) -> void:
	pass


func on_gem(_value: int) -> void:
	pass


func shatter_reach(r: float) -> float:
	return r


func tick(_delta: float) -> void:
	pass
