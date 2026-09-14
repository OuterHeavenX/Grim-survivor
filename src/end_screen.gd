extends CanvasLayer


signal restart_pressed
signal title_pressed

var title_label: Label
var stats_label: Label
var is_victory := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	title_label = _label("", 72, Color.WHITE)
	vb.add_child(title_label)
	stats_label = _label("", 30, Color(0.85, 0.88, 0.94))
	vb.add_child(stats_label)

	var restart := Button.new()
	restart.text = "RESTART"
	restart.custom_minimum_size = Vector2(420, 104)
	restart.add_theme_font_size_override("font_size", 36)
	restart.pressed.connect(func () -> void: restart_pressed.emit())
	var rc := CenterContainer.new()
	rc.add_child(restart)
	vb.add_child(rc)

	var menu := Button.new()
	menu.text = "TITLE"
	menu.custom_minimum_size = Vector2(420, 80)
	menu.add_theme_font_size_override("font_size", 28)
	menu.pressed.connect(func () -> void: title_pressed.emit())
	var mc := CenterContainer.new()
	mc.add_child(menu)
	vb.add_child(mc)


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_screen(victory: bool, time: float, kills: int, level: int, shards_earned: int = 0) -> void:
	is_victory = victory
	if victory:
		title_label.text = "VICTORY"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	else:
		title_label.text = "SLAIN"
		title_label.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
	stats_label.text = "Survived %d:%02d\n%d slain    Level %d\n+%d soul shards" % [
		int(time) / 60, int(time) % 60, kills, level, shards_earned,
	]
	visible = true


func hide_screen() -> void:
	visible = false
