class_name RelicManager
extends Node
# Holds the run's relic effects and fans hooks out to them. Stat-only relics
# need no effect: GameManager applies their modifiers when they are added.

var main = null
var gm = null
var effects: Array = []


func setup(p_main) -> void:
	main = p_main
	gm = main.gm
	name = "Relics"


func add(id: String) -> bool:
	if not gm.add_run_relic(id):
		return false
	var r: RelicData = gm.CONTENT.relic(id)
	# Max-HP factors apply to the body you have now.
	if r.modifiers.has("max_hp") and main.player and is_instance_valid(main.player):
		var p = main.player
		p.max_hp = maxf(1.0, p.max_hp * float(r.modifiers["max_hp"]))
		p.hp = minf(p.hp, p.max_hp)
		p.hp_changed.emit(p.hp, p.max_hp)
	if r.effect:
		var fx: RelicEffect = r.effect.new()
		fx.mgr = self
		fx.id = id
		fx.data = r
		effects.append(fx)
		fx.on_added()
	if gm.run_stats:
		gm.run_stats.relics.append(id)
		gm.run_stats.add_pickup("relics")
	return true


func has(id: String) -> bool:
	return gm.has_relic(id)


func on_hit(e, amount: float, source: String, kb: float) -> float:
	var v := amount
	for fx in effects:
		v = fx.on_hit(e, v, source, kb)
	return v


func contact_damage(e, amount: float) -> float:
	var v := amount
	for fx in effects:
		v = fx.contact_damage(e, v)
	return v


func on_kill(e, source: String) -> void:
	for fx in effects:
		fx.on_kill(e, source)


func on_player_hit(amount: float, source: String) -> void:
	for fx in effects:
		fx.on_player_hit(amount, source)


func on_explosion(pos: Vector2, radius: float, source: String) -> void:
	for fx in effects:
		fx.on_explosion(pos, radius, source)


func on_gem(value: int) -> void:
	for fx in effects:
		fx.on_gem(value)


func shatter_reach(r: float) -> float:
	var v := r
	for fx in effects:
		v = fx.shatter_reach(v)
	return v


func tick(delta: float) -> void:
	for fx in effects:
		fx.tick(delta)
