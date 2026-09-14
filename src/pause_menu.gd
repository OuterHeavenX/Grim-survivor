extends CanvasLayer


signal resume_pressed
signal restart_pressed
signal title_pressed

var sound_btn: Button
var am = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	am = get_node("/root/AudioMan")

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	for def in [
		["RESUME", "resume_pressed"],
		["RESTART", "restart_pressed"],
		["TITLE", "title_pressed"],
	]:
		var b := Button.new()
		b.text = def[0]
		b.custom_minimum_size = Vector2(400, 92)
		b.add_theme_font_size_override("font_size", 32)
		var sig: String = def[1]
		b.pressed.connect(func () -> void: emit_signal(sig))
		var c := CenterContainer.new()
		c.add_child(b)
		vb.add_child(c)

	sound_btn = Button.new()
	sound_btn.custom_minimum_size = Vector2(400, 92)
	sound_btn.add_theme_font_size_override("font_size", 32)
	sound_btn.pressed.connect(_on_sound)
	var sc := CenterContainer.new()
	sc.add_child(sound_btn)
	vb.add_child(sc)


func show_screen() -> void:
	_refresh_sound()
	visible = true


func hide_screen() -> void:
	visible = false


func _on_sound() -> void:
	am.toggle_mute()
	_refresh_sound()
	am.play("ui_click", -8.0)


func _refresh_sound() -> void:
	sound_btn.text = "SOUND: OFF" if am.is_muted() else "SOUND: ON"
