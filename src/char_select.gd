extends CanvasLayer



signal run_pressed
signal back_pressed

var gm = null
var am = null

var balance_label: Label
var cards := {}


class PortraitIcon:
	extends Control
	var portrait: Texture2D

	func _init(class_id: String) -> void:
		portrait = load("res://assets/sprites/player_%s_portrait.png" % class_id)
		custom_minimum_size = Vector2(96, 96)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if portrait != null:
			var edge := minf(size.x, size.y)
			draw_texture_rect(portrait, Rect2((size - Vector2.ONE * edge) * 0.5, Vector2.ONE * edge), false)


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	gm = get_node("/root/GameManager")
	am = get_node("/root/AudioMan")

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vb)

	vb.add_child(_label("CHOOSE YOUR SURVIVOR", 46, Color(0.88, 0.9, 0.97)))

	var bal_center := CenterContainer.new()
	var bal_hb := HBoxContainer.new()
	bal_hb.add_theme_constant_override("separation", 10)
	var bal_icon := TextureRect.new()
	bal_icon.texture = UIBits.shard_texture(32)
	bal_icon.custom_minimum_size = Vector2(32, 32)
	bal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bal_hb.add_child(bal_icon)
	balance_label = _label("", 30, Color(0.75, 0.45, 1.0))
	bal_hb.add_child(balance_label)
	bal_center.add_child(bal_hb)
	vb.add_child(bal_center)

	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for c in gm.CHAR_CLASSES:
		var id: String = str(c["id"])
		var card := _class_card(c)
		cards[id] = card["refs"]
		list.add_child(card["node"])

	vb.add_child(HSeparator.new())

	var run := Button.new()
	run.text = "RUN"
	run.custom_minimum_size = Vector2(420, 96)
	run.add_theme_font_size_override("font_size", 36)
	run.pressed.connect(func () -> void: run_pressed.emit())
	var rc := CenterContainer.new()
	rc.add_child(run)
	vb.add_child(rc)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(300, 64)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func () -> void: back_pressed.emit())
	var bc := CenterContainer.new()
	bc.add_child(back)
	vb.add_child(bc)


func _class_card(c: Dictionary) -> Dictionary:
	var id: String = str(c["id"])
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.13, 0.95)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.35, 0.2, 0.55)
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)

	var portrait := PortraitIcon.new(id)
	hb.add_child(portrait)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)

	var name_l := _label(str(c["name"]), 28, Color(0.92, 0.9, 0.97))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(name_l)
	var flavor := _label(str(c["flavor"]), 19, Color(0.55, 0.6, 0.72))
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(flavor)
	var stats := _label("HP %d   DMG %.2fx   SPD %.2fx" % [
		int(c["hp"]), float(c["dmg"]), float(c["speed"]),
	], 21, Color(0.75, 0.78, 0.88))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(stats)
	var weapon_name := "Dagger Throw"
	if gm.WEAPONS.has(str(c["weapon"])):
		weapon_name = str(gm.WEAPONS[str(c["weapon"])]["name"])
	var wpn := _label("Starts with: " + weapon_name, 21, Color(0.75, 0.55, 1.0))
	wpn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(wpn)

	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(side)
	var action := Button.new()
	action.custom_minimum_size = Vector2(148, 64)
	action.add_theme_font_size_override("font_size", 24)
	action.pressed.connect(_on_action.bind(id))
	side.add_child(action)

	return {"node": panel, "refs": {"panel": panel, "sb": sb, "action": action, "name_l": name_l}}


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_screen() -> void:
	refresh()
	visible = true


func hide_screen() -> void:
	visible = false


func refresh() -> void:
	balance_label.text = "%d soul shards" % gm.shards
	for c in gm.CHAR_CLASSES:
		var id: String = str(c["id"])
		var refs: Dictionary = cards[id]
		var sb: StyleBoxFlat = refs["sb"]
		var action: Button = refs["action"]
		var cost := int(c["cost"])
		if id == gm.selected_class:
			sb.border_color = Color(1.0, 0.8, 0.35)
			action.text = "ACTIVE"
			action.icon = null
			action.disabled = true
			action.modulate = Color(1, 1, 1, 0.75)
		elif gm.is_class_unlocked(id):
			sb.border_color = Color(0.35, 0.2, 0.55)
			action.text = "SELECT"
			action.icon = null
			action.disabled = false
			action.modulate = Color(1, 1, 1, 1)
		elif cost < 0:
			# Found, not bought: point at the stage that hides its relics.
			sb.border_color = Color(0.3, 0.26, 0.2)
			action.icon = null
			var st: int = gm.relic_stage_for_class(id)
			action.text = "STAGE %d" % (st + 1) if st >= 0 else "LOCKED"
			action.disabled = true
			action.modulate = Color(1, 1, 1, 0.9)
			action.add_theme_color_override("font_disabled_color", Color(1.0, 0.82, 0.35))
		else:
			sb.border_color = Color(0.35, 0.2, 0.55)
			action.icon = UIBits.shard_texture(28)
			action.expand_icon = true
			action.text = "%d" % cost
			if gm.shards >= cost:
				action.disabled = false
				action.modulate = Color(1, 1, 1, 1)
			else:
				action.disabled = true
				action.modulate = Color(1, 1, 1, 0.45)
				action.add_theme_color_override("font_disabled_color", Color(1.0, 0.45, 0.45))


func _on_action(id: String) -> void:
	if gm.is_class_unlocked(id):
		if gm.select_class(id):
			am.play("ui_click", -8.0)
	else:
		if gm.unlock_class(id):
			am.play("ui_click", -8.0)
			am.play("levelup_chime", -6.0)
			gm.select_class(id)
		else:
			am.play("ui_click", -14.0)
	refresh()
