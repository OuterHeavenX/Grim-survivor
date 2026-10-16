class_name TimedHazard
extends Node2D
# The shared lifecycle for every telegraphed stage and boss hazard:
#
#   WARN     visible, harmless. Outline + filling progress + moving hatch +
#            an icon, so it reads without colour and through a crowd.
#   ACTIVE   damages, at most once per target unless tick_interval is set.
#   RECOVER  fading, harmless. The punish window after a big hit.
#   LINGER   optional harmless afterstate (cooled ash, spent ground).
#
# Damage is owned: every hit carries `source`, so the run report can say
# what hurt you. Hazards join "hazards" (capped and cleared by main.gd) and
# an owner group ("stage_hazards" / "boss_hazards") their owner cleans up.

enum Phase {WARN, ACTIVE, RECOVER, LINGER, DONE}

const MIN_WARN := 0.65
# The outline layer sits above actors, damage numbers and the visibility
# veil, so a warning stays readable through fog and enemy crowds.
const TOP_Z := 58
const PLAYER_RADIUS := 14.0

signal activated(h)
signal finished(h)

var shape := {}
var warn_time := 0.9
var active_time := 0.3
var recover_time := 0.3
var linger_time := 0.0
var player_damage := 10.0
var enemy_damage := 0.0
# 0 = each target is hit at most once per activation.
var tick_interval := 0.0
var knockback := 0.0
var source := "hazard"
var owner_kind := "stage"
var color := Color(1.0, 0.5, 0.2)
var icon := "warn"
# ring_gap: gaps turn at this rate. sector: the cone sweeps `sweep` radians
# across its active time, and the warning covers the whole swept arc.
var rot_speed := 0.0
var sweep := 0.0
var ignitable := false
var data := {}

var phase: int = Phase.WARN
var age := 0.0
var total_age := 0.0
var _hit := {}
var _tick_cd := 0.0
var _top: Node2D
var _gm = null
var _player = null


class TopLayer extends Node2D:
	var host = null

	func _draw() -> void:
		if host != null and is_instance_valid(host):
			host._draw_top(self)


func setup(p_shape: Dictionary, p_warn: float, p_active: float, p_player_dmg: float,
		p_color: Color, p_source: String, p_owner := "stage") -> TimedHazard:
	shape = p_shape
	warn_time = maxf(MIN_WARN, p_warn)
	active_time = p_active
	player_damage = p_player_dmg
	color = p_color
	source = p_source
	owner_kind = p_owner
	position = shape.get("pos", Vector2.ZERO)
	return self


func _ready() -> void:
	add_to_group("hazards")
	add_to_group("timed_hazards")
	add_to_group(owner_kind + "_hazards")
	z_index = -1
	_gm = get_node_or_null("/root/GameManager")
	_top = TopLayer.new()
	_top.host = self
	_top.z_as_relative = false
	_top.z_index = TOP_Z
	add_child(_top)
	# The warning is a promise: never shorter than the floor, whatever the
	# caller asked for.
	warn_time = maxf(MIN_WARN, warn_time)


func is_threat() -> bool:
	# Only things that can hurt the player close off safe ground; a relic's
	# burning patch or a cosmetic tongue line does not.
	return player_damage > 0.0 and (phase == Phase.WARN or phase == Phase.ACTIVE)


func is_damaging() -> bool:
	return phase == Phase.ACTIVE


func is_lingering() -> bool:
	return phase == Phase.LINGER


func time_to_impact() -> float:
	return maxf(0.0, warn_time - age) if phase == Phase.WARN else 0.0


func damage_shape() -> Dictionary:
	# A sweeping cone hurts only where the blade currently is.
	if String(shape.get("kind", "")) == "sector" and sweep > 0.0 and phase == Phase.ACTIVE:
		var f := clampf(age / maxf(active_time, 0.01), 0.0, 1.0)
		var base: float = float(shape["angle"]) - sweep * 0.5
		var s := shape.duplicate()
		s["angle"] = base + sweep * f
		s["half"] = float(data.get("blade_half", 0.32))
		return s
	return shape


func covers(p: Vector2, margin := 0.0) -> bool:
	return HazardShape.covers(shape, p, margin)


func reignite(new_warn := -1.0) -> bool:
	# Cooled ground can be woken again (the Herald's second phase). Returns
	# false for anything that is not lying dormant.
	if phase != Phase.LINGER:
		return false
	phase = Phase.WARN
	age = 0.0
	_hit.clear()
	if new_warn > 0.0:
		warn_time = maxf(MIN_WARN, new_warn)
	linger_time = 0.0
	return true


func finish_now() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	finished.emit(self)
	queue_free()


func _physics_process(delta: float) -> void:
	if phase == Phase.DONE:
		return
	age += delta
	total_age += delta
	if rot_speed != 0.0 and String(shape.get("kind", "")) == "ring_gap" and is_threat():
		var gaps: Array = shape["gaps"]
		for g in gaps:
			g[0] = float(g[0]) + rot_speed * delta
	match phase:
		Phase.WARN:
			if age >= warn_time:
				_enter(Phase.ACTIVE)
		Phase.ACTIVE:
			_apply_damage(delta)
			if age >= active_time:
				_enter(Phase.RECOVER)
		Phase.RECOVER:
			if age >= recover_time:
				_enter(Phase.LINGER if linger_time > 0.0 else Phase.DONE)
		Phase.LINGER:
			if age >= linger_time:
				_enter(Phase.DONE)
	queue_redraw()
	if _top:
		_top.queue_redraw()


func _enter(p: int) -> void:
	if p == Phase.DONE:
		finish_now()
		return
	phase = p
	age = 0.0
	if p == Phase.ACTIVE:
		_hit.clear()
		_tick_cd = 0.0
		_apply_damage(0.0)
		activated.emit(self)
		var jm = get_node_or_null("/root/JuiceMan")
		if jm and String(shape.get("kind", "")) == "circle":
			jm.shockwave(global_position, color, float(shape["radius"]) * 1.3)


func _apply_damage(delta: float) -> void:
	var ds := damage_shape()
	if tick_interval > 0.0:
		_tick_cd -= delta
		if _tick_cd > 0.0:
			return
		_tick_cd = tick_interval
		_hit.clear()
	if player_damage > 0.0:
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player")
		if _player != null and bool(_player.get("alive")) and not _hit.has(0):
			if HazardShape.covers(ds, _player.global_position, PLAYER_RADIUS):
				_hit[0] = true
				_player.take_damage(player_damage, source)
	if enemy_damage > 0.0:
		var reach := HazardShape.extent(ds) + 60.0
		var c: Vector2 = ds.get("pos", global_position)
		for e in get_tree().get_nodes_in_group("enemies"):
			var id: int = e.get_instance_id()
			if _hit.has(id) or e.global_position.distance_to(c) > reach:
				continue
			if HazardShape.covers(ds, e.global_position, float(e.get("body_radius"))):
				_hit[id] = true
				e.take_damage(enemy_damage, c, knockback, source)


# --- drawing -------------------------------------------------------------

func _opacity() -> float:
	return float(_gm.setting("hazard_opacity")) if _gm else 1.0


func _contrast() -> bool:
	return bool(_gm.setting("high_contrast")) if _gm else false


func _local(s: Dictionary) -> Dictionary:
	var out := s.duplicate()
	out["pos"] = s["pos"] - global_position
	if out.has("to"):
		out["to"] = s["to"] - global_position
	return out


func _draw() -> void:
	var o := _opacity()
	var s := _local(shape)
	match phase:
		Phase.WARN:
			var f := clampf(age / warn_time, 0.0, 1.0)
			_fill(self, s, Color(color, (0.08 + 0.22 * f) * o))
			_fill_progress(self, s, f, Color(color, 0.22 * o))
			_hatch(self, s, Color(color, 0.35 * o))
		Phase.ACTIVE:
			_fill(self, _local(damage_shape()), Color(color.lightened(0.15), 0.55 * o))
		Phase.RECOVER:
			var g := 1.0 - clampf(age / maxf(recover_time, 0.01), 0.0, 1.0)
			_fill(self, s, Color(color, 0.3 * g * o))
		Phase.LINGER:
			_draw_linger(s, o)


func _draw_linger(s: Dictionary, o: float) -> void:
	# Spent ground: cool grey with a dashed rim, so "safe" never relies on
	# colour alone.
	var fade := clampf((linger_time - age) / 1.0, 0.0, 1.0)
	var col := Color(0.55, 0.58, 0.62, 0.22 * fade * o)
	_fill(self, s, col)
	if String(s["kind"]) == "circle":
		var r: float = s["radius"]
		for i in 12:
			var a0 := TAU * float(i) / 12.0
			draw_arc(s["pos"], r, a0, a0 + TAU / 24.0, 4, Color(0.8, 0.85, 0.9, 0.5 * fade * o), 2.0)


func _draw_top(c: CanvasItem) -> void:
	if phase != Phase.WARN and phase != Phase.ACTIVE:
		return
	var o := _opacity()
	var s := _local(shape)
	var hc := _contrast()
	var w := 5.0 if hc else 3.0
	var col := Color(1, 1, 1, 0.95) if hc else Color(color.lightened(0.25), 0.9 * minf(o, 1.0))
	if hc:
		_outline(c, s, Color(0, 0, 0, 0.85), w + 3.0)
	if phase == Phase.ACTIVE:
		_outline(c, _local(damage_shape()), col, w + 1.0)
		return
	# Pulse quickens as impact nears: motion is the second signal.
	var f := clampf(age / warn_time, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(total_age * lerpf(8.0, 22.0, f))
	_outline(c, s, Color(col, col.a * (0.6 + 0.4 * pulse)), w)
	_icon(c, _icon_pos(s), hc)


func _icon_pos(s: Dictionary) -> Vector2:
	match String(s["kind"]):
		"line":
			return (Vector2(s["pos"]) + Vector2(s["to"])) * 0.5
		"sector":
			return Vector2(s["pos"]) + Vector2.from_angle(float(s["angle"])) * float(s["radius"]) * 0.5
		"ring_gap":
			return Vector2(s["pos"]) + Vector2(0, -(float(s["inner"]) + float(s["outer"])) * 0.5)
	return s["pos"]


func _icon(c: CanvasItem, p: Vector2, hc: bool) -> void:
	# A warning triangle with a bar: shape, not hue, says "danger here".
	var r := 13.0
	var tri := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.95, r * 0.7), p + Vector2(-r * 0.95, r * 0.7)])
	c.draw_colored_polygon(tri, Color(0, 0, 0, 0.75))
	c.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
		Color(1, 1, 1, 0.95) if hc else Color(color.lightened(0.4), 0.95), 2.5)
	c.draw_line(p + Vector2(0, -5), p + Vector2(0, 3), Color(1, 1, 1, 0.95), 2.5)
	c.draw_circle(p + Vector2(0, 7), 1.8, Color(1, 1, 1, 0.95))


static func _ring_spans(gaps: Array) -> Array:
	if gaps.is_empty():
		return [[0.0, TAU]]
	var gs: Array = []
	for g in gaps:
		gs.append([fposmod(float(g[0]), TAU), float(g[1])])
	gs.sort_custom(func(a, b): return a[0] < b[0])
	var spans: Array = []
	for i in gs.size():
		var a0: float = gs[i][0] + gs[i][1]
		var nxt: Array = gs[(i + 1) % gs.size()]
		var a1: float = nxt[0] - nxt[1]
		if i == gs.size() - 1:
			a1 += TAU
		if a1 > a0:
			spans.append([a0, a1])
	return spans


static func _sector_points(s: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array([s["pos"]])
	var a: float = s["angle"]
	var h: float = s["half"]
	var segs := maxi(6, int(h * 24.0))
	for i in segs + 1:
		var t := lerpf(a - h, a + h, float(i) / float(segs))
		pts.append(Vector2(s["pos"]) + Vector2.from_angle(t) * float(s["radius"]))
	return pts


static func _line_points(s: Dictionary) -> PackedVector2Array:
	var a: Vector2 = s["pos"]
	var b: Vector2 = s["to"]
	var d := b - a
	if d.length() < 0.5:
		d = Vector2.RIGHT
	var n := Vector2(-d.y, d.x).normalized() * float(s["width"]) * 0.5
	return PackedVector2Array([a + n, b + n, b - n, a - n])


static func _fill(c: CanvasItem, s: Dictionary, col: Color) -> void:
	match String(s.get("kind", "")):
		"circle":
			c.draw_circle(s["pos"], s["radius"], col)
		"line":
			c.draw_colored_polygon(_line_points(s), col)
			c.draw_circle(s["pos"], float(s["width"]) * 0.5, col)
			c.draw_circle(s["to"], float(s["width"]) * 0.5, col)
		"sector":
			c.draw_colored_polygon(_sector_points(s), col)
		"ring_gap":
			var mid := (float(s["inner"]) + float(s["outer"])) * 0.5
			var wid := float(s["outer"]) - float(s["inner"])
			for sp in _ring_spans(s["gaps"]):
				var n := maxi(4, int((sp[1] - sp[0]) * 16.0))
				c.draw_arc(s["pos"], mid, sp[0], sp[1], n, col, wid)


static func _outline(c: CanvasItem, s: Dictionary, col: Color, w: float) -> void:
	match String(s.get("kind", "")):
		"circle":
			c.draw_arc(s["pos"], s["radius"], 0.0, TAU, 40, col, w, true)
		"line":
			var pts := _line_points(s)
			pts.append(pts[0])
			c.draw_polyline(pts, col, w, true)
		"sector":
			var sp := _sector_points(s)
			sp.append(sp[0])
			c.draw_polyline(sp, col, w, true)
		"ring_gap":
			var p: Vector2 = s["pos"]
			for span in _ring_spans(s["gaps"]):
				var n := maxi(4, int((span[1] - span[0]) * 16.0))
				c.draw_arc(p, s["inner"], span[0], span[1], n, col, w, true)
				c.draw_arc(p, s["outer"], span[0], span[1], n, col, w, true)
				for a in [span[0], span[1]]:
					c.draw_line(p + Vector2.from_angle(a) * float(s["inner"]),
						p + Vector2.from_angle(a) * float(s["outer"]), col, w, true)


static func _fill_progress(c: CanvasItem, s: Dictionary, f: float, col: Color) -> void:
	# The fill grows towards the moment of impact, so the deadline reads at a
	# glance without a number.
	match String(s.get("kind", "")):
		"circle":
			c.draw_circle(s["pos"], float(s["radius"]) * f, col)
		"line":
			var s2 := s.duplicate()
			s2["to"] = Vector2(s["pos"]).lerp(s["to"], f)
			c.draw_colored_polygon(_line_points(s2), col)
		"sector":
			var s3 := s.duplicate()
			s3["radius"] = float(s["radius"]) * f
			c.draw_colored_polygon(_sector_points(s3), col)
		"ring_gap":
			var s4 := s.duplicate()
			s4["outer"] = lerpf(float(s["inner"]), float(s["outer"]), f)
			_fill(c, s4, col)


func _hatch(c: CanvasItem, s: Dictionary, col: Color) -> void:
	# Travelling marks give a motion cue that survives colour-blindness and
	# low contrast: chevrons run along lines, ripples spread through circles.
	var t := fposmod(total_age * 1.6, 1.0)
	match String(s.get("kind", "")):
		"circle":
			c.draw_arc(s["pos"], float(s["radius"]) * t, 0.0, TAU, 28, col, 2.0)
		"line":
			var a: Vector2 = s["pos"]
			var b: Vector2 = s["to"]
			var d := (b - a)
			var L := d.length()
			if L < 1.0:
				return
			var u := d / L
			var n := Vector2(-u.y, u.x) * float(s["width"]) * 0.35
			var k := 0.0
			while k < L:
				var p := a + u * fposmod(k + t * 90.0, L)
				c.draw_polyline(PackedVector2Array([p - u * 14.0 + n, p, p - u * 14.0 - n]), col, 2.5)
				k += 90.0
		"sector":
			c.draw_arc(s["pos"], float(s["radius"]) * t, float(s["angle"]) - float(s["half"]),
				float(s["angle"]) + float(s["half"]), 16, col, 2.5)
		"ring_gap":
			var s2 := s.duplicate()
			var r := lerpf(float(s["inner"]), float(s["outer"]), t)
			for sp in _ring_spans(s["gaps"]):
				c.draw_arc(s2["pos"], r, sp[0], sp[1], 24, col, 2.0)
