extends CanvasLayer
# The armoury: every weapon in the game, with the ones chosen for the run's
# starting loadout marked. Weapons left out are still earnable on level-up.

signal closed

var gm = null
var am = null

var count_label: Label
var rows := {}


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	gm = get_node("/root/GameManager")
	am = get_node("/root/AudioMan")

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	vb.add_child(_label("ARMOURY", 46, Color(0.95, 0.75, 0.35)))
	var sub := _label("Pick up to %d to begin the run with. The rest can still be found on level-up." % gm.MAX_LOADOUT,
		20, Color(0.5, 0.55, 0.68))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)

	count_label = _label("", 26, Color(0.95, 0.75, 0.35))
	vb.add_child(count_label)
	vb.add_child(HSeparator.new())

	# Thirteen weapons do not fit on a phone, so the list scrolls.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for id in gm.WEAPONS:
		var row := _weapon_row(str(id), gm.WEAPONS[id])
		rows[str(id)] = row["refs"]
		list.add_child(row["node"])

	vb.add_child(HSeparator.new())
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(420, 84)
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(func () -> void: closed.emit())
	var cc := CenterContainer.new()
	cc.add_child(close)
	vb.add_child(cc)


func _weapon_row(id: String, w: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	panel.add_child(hb)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var name_lbl := _label(str(w["name"]), 26, Color(0.88, 0.9, 0.96))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(name_lbl)
	var desc := _label(str(w["desc"]), 18, Color(0.5, 0.55, 0.66))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	hb.add_child(text)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(132, 62)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_toggle.bind(id))
	hb.add_child(btn)

	return {"node": panel, "refs": {"btn": btn, "name": name_lbl}}


func _on_toggle(id: String) -> void:
	var added: bool = gm.toggle_loadout(id)
	# A refused add means the loadout is already full; say so rather than
	# clicking into silence.
	am.play("ui_click", -8.0 if added or gm.loadout_has(id) else -14.0)
	refresh()


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_screen() -> void:
	refresh()
	visible = true


func hide_screen() -> void:
	visible = false


func refresh() -> void:
	var n: int = gm.loadout.size()
	var full: bool = n >= gm.MAX_LOADOUT
	count_label.text = "%d / %d chosen" % [n, gm.MAX_LOADOUT] if n > 0 \
		else "none chosen — you will start with your class weapon"
	for id in rows:
		var refs: Dictionary = rows[id]
		var btn: Button = refs["btn"]
		var chosen: bool = gm.loadout_has(str(id))
		btn.text = "IN" if chosen else ("FULL" if full else "ADD")
		btn.disabled = full and not chosen
		btn.add_theme_color_override("font_color",
			Color(0.3, 1.0, 0.45) if chosen else Color(0.6, 0.64, 0.74))
		refs["name"].add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.4) if chosen else Color(0.88, 0.9, 0.96))
