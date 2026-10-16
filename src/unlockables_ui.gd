extends CanvasLayer

signal closed

var gm = null
var am = null
var stats_label: Label
var challenge_list: VBoxContainer
var sigil_row: GridContainer


func _ready() -> void:
	layer = 17
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	gm = get_node("/root/GameManager")
	am = get_node("/root/AudioMan")

	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.018, 0.035, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28 if side != "bottom" else 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_label("CHALLENGES & SIGILS", 46, Color(0.92, 0.88, 0.78)))
	stats_label = _label("", 22, Color(0.62, 0.66, 0.76))
	root.add_child(stats_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	challenge_list = VBoxContainer.new()
	challenge_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_list.add_theme_constant_override("separation", 8)
	scroll.add_child(challenge_list)

	root.add_child(_label("DISPLAY SIGIL", 24, Color(0.95, 0.72, 0.32)))
	# Four to a row: there are more sigils than fit across a phone.
	sigil_row = GridContainer.new()
	sigil_row.columns = 4
	sigil_row.add_theme_constant_override("h_separation", 8)
	sigil_row.add_theme_constant_override("v_separation", 8)
	var sc := CenterContainer.new()
	sc.add_child(sigil_row)
	root.add_child(sc)

	var back := Button.new()
	back.text = "BACK TO ALTAR"
	back.custom_minimum_size = Vector2(0, 72)
	back.add_theme_font_size_override("font_size", 27)
	back.pressed.connect(func() -> void: closed.emit())
	root.add_child(back)


func show_screen() -> void:
	var newly: Array[String] = gm.refresh_achievements()
	if not newly.is_empty():
		gm.save_meta()
	_rebuild()
	visible = true


func hide_screen() -> void:
	visible = false


func _rebuild() -> void:
	for child in challenge_list.get_children():
		child.queue_free()
	for child in sigil_row.get_children():
		child.queue_free()
	var complete := 0
	for a in gm.ACHIEVEMENTS:
		var p: Dictionary = gm.achievement_progress(a)
		if p["unlocked"]:
			complete += 1
		challenge_list.add_child(_challenge_card(a, p))
	stats_label.text = "%d / %d COMPLETE     %d RUNS     %d VICTORIES     %d SLAIN" % [
		complete, gm.ACHIEVEMENTS.size(), gm.lifetime_runs, gm.lifetime_wins, gm.lifetime_kills]
	for id in gm.SIGILS:
		var data: Dictionary = gm.SIGILS[id]
		var b := Button.new()
		var unlocked: bool = gm.sigil_unlocked(str(id))
		b.text = str(data["name"]) if unlocked else "LOCKED"
		b.custom_minimum_size = Vector2(150, 56)
		b.disabled = not unlocked
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", data["color"])
		if str(id) == gm.selected_sigil:
			b.text = "[ %s ]" % b.text
		b.pressed.connect(_select_sigil.bind(str(id)))
		sigil_row.add_child(b)


func _challenge_card(a: Dictionary, p: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.06, 0.09, 0.96)
	sb.border_color = Color(0.75, 0.52, 0.2, 0.75) if p["unlocked"] else Color(0.24, 0.25, 0.32)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var title := _label(str(a["name"]), 24, Color(0.95, 0.82, 0.5) if p["unlocked"] else Color(0.82, 0.84, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(title)
	var desc := _label(str(a["desc"]), 17, Color(0.55, 0.59, 0.68))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(desc)
	var status := _label("CLAIMED" if p["unlocked"] else "%d / %d\n+%d SHARDS" % [p["value"], p["goal"], a["reward"]], 18,
		Color(0.55, 0.95, 0.65) if p["unlocked"] else Color(0.72, 0.46, 0.95))
	status.custom_minimum_size.x = 130
	row.add_child(status)
	return panel


func _select_sigil(id: String) -> void:
	if gm.select_sigil(id):
		am.play("ui_click", -8.0)
		_rebuild()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
