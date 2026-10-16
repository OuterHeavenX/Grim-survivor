extends EnemyBehavior
# Cultist healer: hangs back and channels a visible beam into the most
# wounded ally in range. Interruption rule: one hit worth break_frac of the
# healer's own health snaps the beam and forces a 2 s recovery. Each channel
# heals at most max_heal_mult x the healer's health before a cooldown.

var target = null
var _scan := 0.0
var _cd := 0.0
var _channel_heal := 0.0


func _find_target() -> void:
	target = null
	var best := 0.95
	for e in enemy.get_tree().get_nodes_in_group("enemies"):
		if e == enemy or bool(e.get("dead")) or bool(e.get("is_boss_object")):
			continue
		if e.global_position.distance_to(enemy.global_position) > pf("range", 320.0):
			continue
		var frac: float = float(e.hp) / maxf(float(e.max_hp), 1.0)
		# Elites and bosses count as more wounded than they are: those heals
		# matter most, so that is where a healer goes.
		if bool(e.get("is_elite")) or e.is_boss():
			frac -= 0.2
		if frac < best:
			best = frac
			target = e


func step(delta: float, dir: Vector2) -> Vector2:
	t += delta
	_cd = maxf(0.0, _cd - delta)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		if target == null or not is_instance_valid(target) or bool(target.get("dead")):
			_find_target()
	var dist: float = enemy.global_position.distance_to(ppos())
	if dist < pf("keep_away", 260.0):
		return -dir * 0.9
	if target and is_instance_valid(target):
		var to_t: Vector2 = target.global_position - enemy.global_position
		if to_t.length() > pf("range", 320.0) * 0.7:
			return to_t.normalized()
		if _cd <= 0.0 and to_t.length() <= pf("range", 320.0):
			var amt: float = pf("heal_frac", 0.06) * float(target.max_hp) * delta
			target.hp = minf(float(target.max_hp), float(target.hp) + amt)
			_channel_heal += amt
			if _channel_heal >= pf("max_heal_mult", 3.0) * float(enemy.max_hp):
				_interrupt(4.0)
		return Vector2.ZERO
	return dir * 0.5


func channeling() -> bool:
	return target != null and is_instance_valid(target) and _cd <= 0.0 \
		and target.global_position.distance_to(enemy.global_position) <= pf("range", 320.0)


func _interrupt(cd: float) -> void:
	target = null
	_cd = cd
	_channel_heal = 0.0


func modify_damage(amount: float, _from: Vector2, _source: String) -> float:
	if amount >= pf("break_frac", 0.15) * float(enemy.max_hp) and channeling():
		_interrupt(2.0)
	return amount


func draw_body(c: CanvasItem) -> bool:
	robe(c, Color(0.18, 0.3, 0.2), Color(0.5, 1.0, 0.6), Color(0.6, 1.0, 0.7))
	if channeling():
		var to: Vector2 = target.global_position - enemy.global_position
		c.draw_set_transform(Vector2.ZERO, -enemy.rotation, Vector2(1.0 / enemy.scale.x, 1.0 / enemy.scale.y))
		c.draw_line(Vector2.ZERO, to, Color(0.4, 1.0, 0.5, 0.35), 8.0)
		var k := fposmod(t * 2.0, 1.0)
		for i in 4:
			var f := fposmod(k + float(i) * 0.25, 1.0)
			c.draw_circle(to * f, 4.0, Color(0.8, 1.0, 0.8, 0.9))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
