extends Node





var _tex: Texture2D


class FlashLight extends PointLight2D:
	var t := 0.0
	var dur := 0.35
	var base_energy := 2.2

	func _process(d: float) -> void:
		t += d
		var f := clampf(t / dur, 0.0, 1.0)
		energy = base_energy * (1.0 - f) * (1.0 - f)
		if f >= 1.0:
			queue_free()


class TorchLight extends PointLight2D:
	var _t := 0.0
	var base_energy := 1.15

	func _process(d: float) -> void:
		_t += d
		energy = base_energy + sin(_t * 11.0) * 0.05 + sin(_t * 5.7 + 1.3) * 0.06


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tex = _make_glow_texture()


func glow_texture() -> Texture2D:
	return _tex


func _make_glow_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _run_node():
	var main = get_tree().get_first_node_in_group("main")
	if main == null:
		return null
	return main.get("run")



func flash(pos: Vector2, color: Color, energy := 2.2, tex_scale := 3.0, dur := 0.35) -> void:
	var run = _run_node()
	if run == null:
		return
	if get_tree().get_nodes_in_group("light_flash").size() > 6:
		return
	var l := FlashLight.new()
	l.add_to_group("light_flash")
	l.texture = _tex
	l.color = color
	l.energy = energy
	l.base_energy = energy
	l.dur = dur
	l.texture_scale = tex_scale
	l.position = pos
	run.add_child(l)



func attach_aura(node: Node2D, color: Color, tex_scale: float, energy: float, torch := false) -> PointLight2D:
	var l: PointLight2D
	if torch:
		var t := TorchLight.new()
		t.base_energy = energy
		l = t
	else:
		l = PointLight2D.new()
	l.texture = _tex
	l.color = color
	l.energy = energy
	l.texture_scale = tex_scale
	node.add_child(l)
	return l
