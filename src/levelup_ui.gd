extends CanvasLayer


signal choice_made

var gm = null
var panel: VBoxContainer
var buttons: Array = []
var reroll_btn: Button


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
	vb.add_theme_constant_override("separation", 20)
	center.add_child(vb)

	var title := Label.new()
	title.text = "LEVEL UP"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 16)
	vb.add_child(panel)

	reroll_btn = Button.new()
	reroll_btn.custom_minimum_size = Vector2(300, 64)
	reroll_btn.add_theme_font_size_override("font_size", 22)
	reroll_btn.pressed.connect(_on_reroll)
	var rc := CenterContainer.new()
	rc.add_child(reroll_btn)
	vb.add_child(rc)


func show_screen(choices: Array) -> void:
	for c in panel.get_children():
		c.queue_free()
	buttons.clear()
	for ch in choices:
		var b := Button.new()
		b.custom_minimum_size = Vector2(580, 134)
		b.add_theme_font_size_override("font_size", 24)
		b.text = _btn_text(ch)
		b.pressed.connect(_on_pick.bind(ch))
		_style_card(b, _accent(ch))
		panel.add_child(b)
		buttons.append(b)
	reroll_btn.visible = int(gm.rerolls_left) > 0
	reroll_btn.text = "REROLL  (%d left)" % int(gm.rerolls_left)
	visible = true
	# Cards deal in one after another rather than appearing as a block.
	for i in buttons.size():
		var b: Button = buttons[i]
		b.modulate.a = 0.0
		b.position.x = 0.0
		var tw := create_tween()
		tw.tween_interval(0.06 * float(i))
		tw.tween_property(b, "modulate:a", 1.0, 0.16)
	if not buttons.is_empty():
		buttons[0].grab_focus()


# Evolutions gold, weapons ember, passives violet: what kind of power a card
# offers reads before its text does.
func _accent(ch: Dictionary) -> Color:
	match str(ch.get("kind", "")):
		"evolve":
			return Color(1.0, 0.8, 0.3)
		"weapon":
			return Color(1.0, 0.5, 0.25)
		"pact":
			return Color(0.45, 1.0, 0.75)
	return Color(0.7, 0.5, 1.0)


func _style_card(b: Button, accent: Color) -> void:
	for st in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(12)
		s.bg_color = Color(0.05, 0.045, 0.07, 0.96) if st == "normal" else Color(accent.darkened(0.78), 0.98)
		s.border_color = Color(accent, 0.55) if st == "normal" else accent
		s.set_border_width_all(2)
		s.border_width_left = 8
		s.shadow_color = Color(accent, 0.25 if st == "normal" else 0.5)
		s.shadow_size = 6 if st == "normal" else 14
		s.content_margin_left = 20
		s.content_margin_right = 14
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_color", Color(0.93, 0.9, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))


func _btn_text(ch: Dictionary) -> String:
	var tag := "NEW!" if bool(ch.get("is_new", false)) else "Lv %d" % int(ch.get("to", 1))
	var bname := ""
	var desc := ""
	if ch["kind"] == "evolve":
		var ev: Dictionary = gm.EVOLUTIONS[ch["id"]]
		tag = "EVOLVE!"
		bname = str(ev["name"])
		desc = str(ev["desc"])
	elif ch["kind"] == "pact":
		var cname: String = str(gm.COMPANIONS[gm.selected_companion]["name"])
		bname = "PACT: " + cname
		tag = "Lv %d/%d" % [int(ch["to"]), gm.PACT_MAX]
		desc = "Your summon answers twice over." if int(ch["to"]) >= gm.PACT_MAX \
			else "Companion +25% damage, +1.5s, -7% cooldown."
	elif ch["kind"] == "weapon":
		var w: Dictionary = gm.WEAPONS[ch["id"]]
		bname = str(w["name"])
		desc = str(w["desc"]) if bool(ch.get("is_new", false)) else str(w["up"])
	else:
		var p: Dictionary = gm.PASSIVES[ch["id"]]
		bname = str(p["name"])
		desc = str(p["desc"])
	return "%s   ·   %s\n%s" % [bname.to_upper(), tag, desc]


func _on_reroll() -> void:
	if int(gm.rerolls_left) <= 0:
		return
	gm.rerolls_left -= 1
	var am = get_node_or_null("/root/AudioMan")
	if am:
		am.play("ui_click", -6.0)
	show_screen(gm.roll_upgrades())


func _on_pick(ch: Dictionary) -> void:
	gm.apply_upgrade(ch)
	visible = false
	choice_made.emit()


func hide_screen() -> void:
	visible = false
