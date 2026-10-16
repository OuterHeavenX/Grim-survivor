class_name UIBits
extends RefCounted




static var _shard_cache := {}



static func shard_texture(px: int = 30) -> Texture2D:
	if _shard_cache.has(px):
		return _shard_cache[px]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(px) * 0.5
	var rx := float(px) * 0.3
	var ry := float(px) * 0.44
	for y in px:
		for x in px:
			var dx := absf(float(x) + 0.5 - c) / rx
			var dy := absf(float(y) + 0.5 - c) / ry
			var d := dx + dy
			if d <= 1.0:
				var core := 1.0 - smoothstep(0.0, 1.0, d)
				var col := Color(0.55, 0.28, 0.95).lerp(Color(0.96, 0.88, 1.0), core * core)
				if float(y) < c and absf(float(x) + 0.5 - c) < rx * 0.4 * (1.0 - dy):
					col = col.lerp(Color.WHITE, 0.35 * core)
				col.a = 0.55 + 0.45 * (1.0 - smoothstep(0.7, 1.0, d))
				img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_shard_cache[px] = tex
	return tex


class PipsRow:
	extends Control
	var rank := 0
	var total := 5

	func _init(p_total: int = 5) -> void:
		total = p_total
		custom_minimum_size = Vector2(total * _step(), 30.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _step() -> float:
		return 30.0 if total <= 5 else 21.0

	func set_rank(r: int) -> void:
		rank = r
		queue_redraw()

	func _draw() -> void:
		var st := _step()
		var rad := 10.0 if total <= 5 else 7.5
		for i in total:
			var cp := Vector2(st * 0.5 + i * st, 15.0)
			# Ranks past the fifth are ascended: gold, not violet.
			var hi := Color(1.0, 0.8, 0.35) if i >= 5 else Color(0.78, 0.5, 1.0)
			if i < rank:
				draw_circle(cp, rad, Color(hi, 0.35))
				draw_circle(cp, rad * 0.65, hi)
				draw_arc(cp, rad, 0.0, TAU, 24, hi.lightened(0.4), 2.0)
			else:
				draw_arc(cp, rad, 0.0, TAU, 24, Color(hi.darkened(0.3), 0.7), 2.0)