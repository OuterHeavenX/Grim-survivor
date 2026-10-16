extends Control
# Edge-of-screen arrows for things worth walking to: the boss, elites, stage
# objectives, chests, unlock relics and relic altars. Each kind has its own
# shape and letter, not just a colour. The target list is rebuilt at 10 Hz
# from small groups; only the projection runs every frame.

const MARGIN := 46.0
const KINDS := {
	"boss": {"col": Color(1.0, 0.35, 0.4), "glyph": "B", "size": 22.0},
	"elite": {"col": Color(1.0, 0.7, 0.3), "glyph": "E", "size": 16.0},
	"objective": {"col": Color(1.0, 0.9, 0.5), "glyph": "!", "size": 18.0},
	"chest": {"col": Color(1.0, 0.8, 0.3), "glyph": "C", "size": 15.0},
	"relic": {"col": Color(0.7, 0.9, 1.0), "glyph": "R", "size": 15.0},
	"altar": {"col": Color(1.0, 0.85, 0.45), "glyph": "A", "size": 17.0},
}

var _targets: Array = []
var _scan := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _collect() -> void:
	_targets.clear()
	var tree := get_tree()
	var main = tree.get_first_node_in_group("main")
	if main and main.boss and is_instance_valid(main.boss):
		_targets.append([main.boss, "boss"])
	for e in tree.get_nodes_in_group("elites"):
		_targets.append([e, "elite"])
	for o in tree.get_nodes_in_group("objectives"):
		if o.has_method("is_active") and o.is_active():
			_targets.append([o, "objective"])
	for cv in tree.get_nodes_in_group("convoy"):
		_targets.append([cv, "objective"])
	for w in tree.get_nodes_in_group("wards"):
		if w.has_method("needs_player") and w.needs_player():
			_targets.append([w, "objective"])
	for c in tree.get_nodes_in_group("chests"):
		_targets.append([c, "chest"])
	for r in tree.get_nodes_in_group("relics"):
		_targets.append([r, "relic"])
	for a in tree.get_nodes_in_group("relic_altars"):
		_targets.append([a, "altar"])


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.1
		_collect()
	queue_redraw()


func edge_point(screen_pos: Vector2, view: Vector2) -> Variant:
	# Where an arrow for screen_pos sits, or null if it is on screen.
	var inner := Rect2(Vector2(MARGIN, MARGIN), view - Vector2(MARGIN, MARGIN) * 2.0)
	if inner.has_point(screen_pos):
		return null
	var c := view * 0.5
	var d := screen_pos - c
	if d.length() < 1.0:
		return null
	var sx := (inner.size.x * 0.5) / maxf(absf(d.x), 0.001)
	var sy := (inner.size.y * 0.5) / maxf(absf(d.y), 0.001)
	return c + d * minf(sx, sy)


func _draw() -> void:
	var view := get_viewport_rect().size
	var xf := get_viewport().get_canvas_transform()
	var font := ThemeDB.fallback_font
	for t in _targets:
		var n = t[0]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var sp: Vector2 = xf * n.global_position
		var ep = edge_point(sp, view)
		if ep == null:
			continue
		var k: Dictionary = KINDS[t[1]]
		var col: Color = k["col"]
		var s: float = k["size"]
		var dir := (sp - view * 0.5).normalized()
		var tip: Vector2 = ep + dir * s
		var side := Vector2(-dir.y, dir.x) * s * 0.7
		draw_colored_polygon(PackedVector2Array([tip, ep - side, ep + side]), Color(col, 0.9))
		draw_circle(ep - dir * s * 0.6, s * 0.75, Color(0, 0, 0, 0.75))
		draw_arc(ep - dir * s * 0.6, s * 0.75, 0.0, TAU, 20, col, 2.0)
		draw_string(font, ep - dir * s * 0.6 + Vector2(-s * 0.4, s * 0.38), str(k["glyph"]),
			HORIZONTAL_ALIGNMENT_CENTER, s * 0.8, int(s), Color(1, 1, 1))
