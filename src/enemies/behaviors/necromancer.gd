extends EnemyBehavior
# Necromancer: walks to a bone pile (Bone Desert) or a fresh corpse, channels,
# and raises skeletons. Raised dead are flagged revived: no XP, no shards, no
# kill credit, so a necromancer is never a farm. A global cap bounds how many
# revived stand at once, and a heavy hit (20% of its health) breaks the
# channel.

const BREAK_FRAC := 0.2

var _state := "seek"
var _timer := 0.0
var _source = null   # a pile node or a corpse dictionary from main.gd


func _find_source() -> void:
	_source = null
	var m = main()
	if m == null:
		return
	if m.director and is_instance_valid(m.director) and m.director.rule \
			and m.director.rule.has_method("nearest_pile"):
		_source = m.director.rule.nearest_pile(enemy.global_position, 900.0)
	if _source == null and m.has_method("claim_corpse"):
		_source = m.claim_corpse(enemy.global_position, 600.0)


func _source_pos() -> Variant:
	if _source is Dictionary:
		return _source["pos"]
	if _source != null and is_instance_valid(_source):
		return _source.global_position
	return null


func step(delta: float, dir: Vector2) -> Vector2:
	t += delta
	match _state:
		"seek":
			if _source == null or _source_pos() == null:
				_find_source()
				if _source == null:
					return -dir * 0.6 if enemy.global_position.distance_to(ppos()) < 280.0 else Vector2.ZERO
			var to: Vector2 = Vector2(_source_pos()) - enemy.global_position
			if to.length() < 40.0:
				_state = "channel"
				_timer = pf("channel", 1.6)
				return Vector2.ZERO
			return to.normalized()
		"channel":
			_timer -= delta
			if _timer <= 0.0:
				_raise()
				_state = "cooldown"
				_timer = pf("cooldown", 6.0)
			return Vector2.ZERO
		_:
			_timer -= delta
			if _timer <= 0.0:
				_state = "seek"
				_source = null
			return -dir * 0.5 if enemy.global_position.distance_to(ppos()) < 260.0 else Vector2.ZERO
	return dir


static func revived_alive(tree: SceneTree) -> int:
	var n := 0
	for e in tree.get_nodes_in_group("enemies"):
		if bool(e.get("revived")) and not bool(e.get("dead")):
			n += 1
	return n


func _raise() -> void:
	var m = main()
	var p = _source_pos()
	if m == null or p == null:
		return
	var room := int(pf("max_revived", 10.0)) - revived_alive(enemy.get_tree())
	var n := mini(int(pf("raise", 2.0)), room)
	if _source != null and not (_source is Dictionary) and _source.has_method("consume"):
		n = mini(n, _source.consume(n))
	for i in n:
		if m._enemy_count() >= m.MAX_ENEMIES:
			break
		var e = m._spawn_enemy("skeleton", m.clamp_arena(Vector2(p) + Vector2.from_angle(randf() * TAU) * 30.0))
		e.set("revived", true)
		e.set("no_credit", true)
	if m.jm:
		m.jm.shockwave(Vector2(p), Color(0.6, 1.0, 0.7), 90.0)
	_source = null


func modify_damage(amount: float, _from: Vector2, _source_id: String) -> float:
	if _state == "channel" and amount >= BREAK_FRAC * float(enemy.max_hp):
		_state = "cooldown"
		_timer = 3.0
		_source = null
	return amount


func draw_body(c: CanvasItem) -> bool:
	robe(c, Color(0.12, 0.1, 0.16), Color(0.7, 1.0, 0.75), Color(0.6, 1.0, 0.6))
	c.draw_line(Vector2(13, -18), Vector2(13, 18), Color(0.6, 0.55, 0.45), 3.0)
	c.draw_circle(Vector2(13, -20), 4.5, Color(0.85, 0.85, 0.75))
	if _state == "channel":
		var k := fposmod(t * 1.5, 1.0)
		c.draw_arc(Vector2.ZERO, 18.0 + 22.0 * k, 0.0, TAU, 24, Color(0.6, 1.0, 0.7, 0.8 * (1.0 - k)), 3.0)
	return true
