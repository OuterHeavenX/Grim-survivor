extends RelicEffect
# Killing a slowed foe heals 1 HP, at most MAX_PER_SEC a second.

const MAX_PER_SEC := 5

var _window := 0.0
var _count := 0


func tick(delta: float) -> void:
	_window -= delta
	if _window <= 0.0:
		_window = 1.0
		_count = 0


func on_kill(e, _src: String) -> void:
	if _count >= MAX_PER_SEC or not e.is_slowed():
		return
	var p = main().player
	if p and is_instance_valid(p):
		_count += 1
		p.heal(1.0)
