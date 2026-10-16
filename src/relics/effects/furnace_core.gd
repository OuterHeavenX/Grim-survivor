extends RelicEffect
# A kill by an explosion shaves time off every weapon's cooldown, at most once
# per RATE seconds.

const CUT := 0.15
const RATE := 0.25

var _cd := 0.0


func tick(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)


func on_kill(_e, src: String) -> void:
	if _cd > 0.0 or not CombatRules.EXPLOSIVE.has(src):
		return
	_cd = RATE
	var p = main().player
	if p == null or not is_instance_valid(p) or p.weapons_node == null:
		return
	var timers: Dictionary = p.weapons_node.timers
	for k in timers:
		timers[k] = maxf(0.0, float(timers[k]) - CUT)
	if gm().run_stats:
		gm().run_stats.add_proc("relic:furnace_core")
