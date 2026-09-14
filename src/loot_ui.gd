extends CanvasLayer



signal loot_chosen(choice)

var gm = null
var panel: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	gm = get_node("/root/GameManager")
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)

	var title := Label.new()
	title.text = "ELITE SPOILS"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "choose one of three"
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 16)
	vb.add_child(panel)


func show_screen(options: Array) -> void:
	for c in panel.get_children():
		c.queue_free()
	for ch in options:
		var b := Button.new()
		b.custom_minimum_size = Vector2(580, 124)
		b.add_theme_font_size_override("font_size", 24)
		b.text = "%s\n%s" % [str(ch["name"]), str(ch["desc"])]
		b.pressed.connect(_on_pick.bind(ch))
		panel.add_child(b)
	visible = true


func _on_pick(ch: Dictionary) -> void:
	visible = false
	loot_chosen.emit(ch)


func hide_screen() -> void:
	visible = false
