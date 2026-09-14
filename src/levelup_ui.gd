extends CanvasLayer


signal choice_made

var gm = null
var panel: VBoxContainer
var buttons: Array = []


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
		panel.add_child(b)
		buttons.append(b)
	visible = true


func _btn_text(ch: Dictionary) -> String:
	var tag := "NEW!" if bool(ch.get("is_new", false)) else "Lv %d" % int(ch.get("to", 1))
	var bname := ""
	var desc := ""
	if ch["kind"] == "evolve":
		var ev: Dictionary = gm.EVOLUTIONS[ch["id"]]
		tag = "EVOLVE!"
		bname = str(ev["name"])
		desc = str(ev["desc"])
	elif ch["kind"] == "weapon":
		var w: Dictionary = gm.WEAPONS[ch["id"]]
		bname = str(w["name"])
		desc = str(w["desc"]) if bool(ch.get("is_new", false)) else str(w["up"])
	else:
		var p: Dictionary = gm.PASSIVES[ch["id"]]
		bname = str(p["name"])
		desc = str(p["desc"])
	return "[%s]  %s\n%s" % [tag, bname, desc]


func _on_pick(ch: Dictionary) -> void:
	gm.apply_upgrade(ch)
	visible = false
	choice_made.emit()


func hide_screen() -> void:
	visible = false
