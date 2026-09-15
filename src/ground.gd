extends Node2D




const ARENA := 1500.0


const THEMES := {
	"ashen": {
		"base": Color(0.038, 0.05, 0.085),
		"tile_hi": Color(0.1, 0.115, 0.16), "tile_lo": Color(0.028, 0.036, 0.06),
		"scorch": Color(0.012, 0.01, 0.02), "ash": Color(0.32, 0.34, 0.38),
		"crack_glow": Color(0.9, 0.32, 0.1), "rune": Color(0.35, 0.75, 0.85),
		"tex": "res://assets/ground/ashen.png", "tex_tint": Color(0.40, 0.44, 0.56),
		"border": Color(0.16, 0.18, 0.26), "stone": Color(0.2, 0.23, 0.32),
	},
	"marsh": {
		"base": Color(0.03, 0.06, 0.045),
		"tile_hi": Color(0.08, 0.13, 0.09), "tile_lo": Color(0.02, 0.045, 0.03),
		"scorch": Color(0.008, 0.02, 0.012), "ash": Color(0.25, 0.35, 0.22),
		"crack_glow": Color(0.35, 0.95, 0.4), "rune": Color(0.45, 0.9, 0.5),
		"tex": "res://assets/ground/marsh.png", "tex_tint": Color(0.17, 0.27, 0.19),
		"border": Color(0.12, 0.22, 0.14), "stone": Color(0.16, 0.26, 0.16),
	},
	"cinder": {
		"base": Color(0.07, 0.035, 0.03),
		"tile_hi": Color(0.15, 0.08, 0.06), "tile_lo": Color(0.05, 0.025, 0.02),
		"scorch": Color(0.02, 0.008, 0.006), "ash": Color(0.38, 0.28, 0.24),
		"crack_glow": Color(1.0, 0.4, 0.08), "rune": Color(1.0, 0.55, 0.2),
		"tex": "res://assets/ground/cinder.png", "tex_tint": Color(1.45, 0.90, 0.72),
		"border": Color(0.28, 0.14, 0.1), "stone": Color(0.3, 0.18, 0.14),
	},
}

var theme: Dictionary = THEMES["ashen"]
var _tex: Texture2D = null

# Scatter art built by tools/build_decor.gd: [small ground details, large props].
const DECOR_COUNTS := {"ashen": [10, 2], "marsh": [9, 3], "cinder": [10, 6]}
const SCATTER_COUNT := 190
const PROP_COUNT := 18
# Props are big enough to sit under the player at spawn, so keep them clear of it.
const PROP_CLEAR := 320.0

var _theme_key := "ashen"
var _decor_s: Array[Texture2D] = []
var _decor_p: Array[Texture2D] = []


func set_theme(key: String) -> void:
	theme = THEMES.get(key, THEMES["ashen"])
	_theme_key = key if THEMES.has(key) else "ashen"
	_tex = load(str(theme.get("tex", "")))
	_load_decor()
	_rng.seed = 4242 + abs(hash(key)) % 100000
	queue_redraw()

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _load_decor() -> void:
	_decor_s.clear()
	_decor_p.clear()
	var counts: Array = DECOR_COUNTS.get(_theme_key, [0, 0])
	for i in int(counts[0]):
		var t: Texture2D = load("res://assets/decor/%s_s%02d.png" % [_theme_key, i])
		if t != null:
			_decor_s.append(t)
	for i in int(counts[1]):
		var t: Texture2D = load("res://assets/decor/%s_p%02d.png" % [_theme_key, i])
		if t != null:
			_decor_p.append(t)


func _place(tex: Texture2D, pos: Vector2, rot: float, flip: float, tint: Color) -> void:
	draw_set_transform(pos, rot, Vector2(flip, 1.0))
	draw_texture(tex, -tex.get_size() * 0.5, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_decor(e: float) -> void:
	if _decor_s.is_empty() and _decor_p.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = 77 + abs(hash(_theme_key)) % 100000

	# Small stuff can face any way; a rotated wreck or column reads fine
	# top-down, but they get a flip rather than a spin so they stay grounded.
	for i in SCATTER_COUNT:
		if _decor_s.is_empty():
			break
		var t: Texture2D = _decor_s[r.randi_range(0, _decor_s.size() - 1)]
		var p := Vector2(r.randf_range(-e, e), r.randf_range(-e, e))
		_place(t, p, r.randf_range(0.0, TAU), 1.0, Color(0.66, 0.66, 0.7, 0.92))

	for i in PROP_COUNT:
		if _decor_p.is_empty():
			break
		var t: Texture2D = _decor_p[r.randi_range(0, _decor_p.size() - 1)]
		var p := Vector2(r.randf_range(-e, e), r.randf_range(-e, e))
		if p.length() < PROP_CLEAR:
			p = p.normalized() * PROP_CLEAR if p.length() > 1.0 else Vector2(PROP_CLEAR, 0)
		_place(t, p, 0.0, 1.0 if r.randf() < 0.5 else -1.0, Color(0.62, 0.62, 0.66, 1.0))


func _ready() -> void:
	# draw_texture_rect(..., tile = true) needs the repeat mode set on the node.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if _tex == null:
		_tex = load(str(theme.get("tex", "")))
	if _decor_s.is_empty() and _decor_p.is_empty():
		_load_decor()
	_rng.seed = 4242
	_noise.seed = 9001
	_noise.frequency = 0.012
	_noise.fractal_octaves = 3
	queue_redraw()


func _draw() -> void:
	var e := ARENA + 120.0

	draw_rect(Rect2(-e, -e, e * 2.0, e * 2.0), theme["base"])

	for i in 46:
		var p := Vector2(_rng.randf_range(-e, e), _rng.randf_range(-e, e))
		var r := _rng.randf_range(120.0, 320.0)
		var n := _noise.get_noise_2d(p.x * 0.01, p.y * 0.01)
		var c: Color = theme["tile_hi"] if n > 0.0 else theme["tile_lo"]
		for k in 3:
			var f := 1.0 - float(k) / 3.0
			draw_circle(p, r * f, Color(c, 0.16 * f))

	# Real tiled ground for the stage, or the procedural slab grid it replaced.
	# This has to come after the soft colour blotches above, which are opaque
	# enough to hide it, and before the scorch, cracks and runes below.
	if _tex != null:
		draw_texture_rect(_tex, Rect2(-e, -e, e * 2.0, e * 2.0), true,
			theme["tex_tint"])
	else:
		var tile := 96.0
		var n := int(e * 2.0 / tile)
		for ix in n:
			for iy in n:
				var v := _noise.get_noise_2d(float(ix) * 0.55, float(iy) * 0.55) * 0.014
				var c: Color = Color(theme["base"], 1.0).lightened(v * 4.0)
				draw_rect(Rect2(-e + ix * tile, -e + iy * tile, tile - 2.0, tile - 2.0), c)

	for i in 12:
		var p := Vector2(_rng.randf_range(-e, e), _rng.randf_range(-e, e))
		var r := _rng.randf_range(50.0, 110.0)
		for k in 3:
			var f := 1.0 - float(k) / 3.0
			draw_circle(p, r * f, Color(theme["scorch"], 0.5 * f))

	for i in 24:
		var p := Vector2(_rng.randf_range(-e, e), _rng.randf_range(-e, e))
		var r := _rng.randf_range(40.0, 120.0)
		for k in 3:
			var f := 1.0 - float(k) / 3.0
			draw_circle(p, r * f, Color(theme["ash"], 0.05 * f))

	for i in 26:
		var a := _rng.randf() * TAU
		var r0 := _rng.randf_range(60.0, 420.0)
		var p := Vector2(cos(a), sin(a)) * r0
		var pts := PackedVector2Array([p])
		var dir := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5))
		for k in 5:
			p += dir * _rng.randf_range(14.0, 30.0) + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
			pts.append(p)
		var heat := clampf(1.0 - r0 / 480.0, 0.15, 1.0)
		draw_polyline(pts, Color(0.05, 0.03, 0.03, 0.8), 5.0)
		draw_polyline(pts, Color(theme["crack_glow"], 0.35 * heat), 2.0)

	for i in 7:
		var p := Vector2(_rng.randf_range(-e * 0.8, e * 0.8), _rng.randf_range(-e * 0.8, e * 0.8))
		var r := _rng.randf_range(46.0, 80.0)
		draw_arc(p, r, 0, TAU, 48, Color(theme["rune"], 0.1), 3.0)
		draw_arc(p, r * 0.72, 0, TAU, 40, Color(theme["rune"], 0.07), 2.0)
		for k in 12:
			var ta := TAU * float(k) / 12.0
			var q := p + Vector2(cos(ta), sin(ta)) * r
			draw_line(q, q + Vector2(cos(ta), sin(ta)) * 7.0, Color(theme["rune"], 0.1), 2.0)

	for i in 220:
		var p := Vector2(_rng.randf_range(-e, e), _rng.randf_range(-e, e))
		var s := _rng.randf_range(3.0, 9.0)
		var g := _rng.randf_range(0.1, 0.18)
		draw_colored_polygon([
			p + Vector2(-s, s * 0.6), p + Vector2(0, -s),
			p + Vector2(s, s * 0.4), p + Vector2(s * 0.2, s),
			p + Vector2(-s * 0.7, s * 0.8),
		], Color(g, g, g + 0.02))

	for i in 26:
		var p := Vector2(_rng.randf_range(-e, e), _rng.randf_range(-e, e))
		var a := _rng.randf() * TAU
		draw_arc(p, _rng.randf_range(6.0, 12.0), a, a + 2.2, 10, Color(0.55, 0.53, 0.45, 0.5), 2.5)

	for i in 170:
		var p := Vector2(_rng.randf_range(-e, e), _rng.randf_range(-e, e))
		for k in 3:
			var tip := p + Vector2(_rng.randf_range(-7, 7), _rng.randf_range(-14, -6))
			draw_line(p, tip, Color(0.1, 0.11, 0.09), 2.0)

	_draw_decor(e)

	draw_rect(Rect2(-ARENA, -ARENA, ARENA * 2.0, ARENA * 2.0), Color(theme["border"], 0.55), false, 6.0)
	var steps := 48
	for i in steps:
		var t := TAU * float(i) / float(steps)
		var p := Vector2(cos(t), sin(t)) * ARENA
		var s := 7.0 + 3.0 * sin(t * 7.0)
		draw_circle(p, s, theme["stone"])
		draw_circle(p + Vector2(-2, -2), s * 0.5, Color(theme["stone"]).lightened(0.4))
