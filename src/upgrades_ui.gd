extends CanvasLayer



signal closed

var gm = null
var am = null

var balance_label: Label
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
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vb)

	vb.add_child(_label("SOUL UPGRADES", 50, Color(0.85, 0.6, 1.0)))
	var sub := _label("Shards persist between runs. Death cannot take them.", 22, Color(0.5, 0.55, 0.68))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)

	var bal_center := CenterContainer.new()
	var bal_hb := HBoxContainer.new()
	bal_hb.add_theme_constant_override("separation", 12)
	var bal_icon := TextureRect.new()
	bal_icon.texture = UIBits.shard_texture(36)
	bal_icon.custom_minimum_size = Vector2(36, 36)
	bal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bal_hb.add_child(bal_icon)
	balance_label = _label("", 34, Color(0.75, 0.45, 1.0))
	bal_hb.add_child(balance_label)
	bal_center.add_child(bal_hb)
	vb.add_child(bal_center)

	var sep := HSeparator.new()
	vb.add_child(sep)

	for t in gm.META_TRACKS:
		var id: String = t["id"]
		var row := _track_row(t)
		rows[id] = row["refs"]
		vb.add_child(row["node"])

	var sep2 := HSeparator.new()
	vb.add_child(sep2)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(420, 92)
	close.add_theme_font_size_override("font_size", 32)
	close.pressed.connect(func () -> void: closed.emit())
	var cc := CenterContainer.new()
	cc.add_child(close)
	vb.add_child(cc)


func _track_row(t: Dictionary) -> Dictionary:
	var id: String = t["id"]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.13, 0.95)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.35, 0.2, 0.55)
	sb.set_border_width_all(2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)
	var name_l := _label(t["name"], 26, Color(0.9, 0.88, 0.97))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var pips := UIBits.PipsRow.new()
	top.add_child(pips)

	var desc := _label(t["desc"], 20, Color(0.55, 0.6, 0.72))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)

	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 12)
	vb.add_child(bot)
	var bonus := _label("", 21, Color(0.75, 0.5, 1.0))
	bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bonus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(bonus)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(132, 52)
	buy.add_theme_font_size_override("font_size", 24)
	buy.pressed.connect(_on_buy.bind(id))
	bot.add_child(buy)

	return {"node": panel, "refs": {"pips": pips, "bonus": bonus, "buy": buy}}


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
	if gm.shards <= 0:
		balance_label.text = "0 soul shards — earn more in runs"
	else:
		balance_label.text = "%d soul shards" % gm.shards
	for t in gm.META_TRACKS:
		var id: String = t["id"]
		var refs: Dictionary = rows[id]
		var rank: int = gm.meta_rank(id)
		(refs["pips"] as UIBits.PipsRow).set_rank(rank)
		var cost: int = gm.track_cost(id)
		var buy: Button = refs["buy"]
		var bonus_label := refs["bonus"] as Label
		if cost < 0:
			bonus_label.text = "Now: %s (MAX)" % gm.track_short_text(id)
			buy.text = "MAX"
			buy.icon = null
			buy.disabled = true
			buy.modulate = Color(1, 1, 1, 0.4)
			buy.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.6))
		else:
			bonus_label.text = "Now: %s  >  Next: %s" % [
				gm.track_short_text(id), gm.track_short_next_text(id),
			]
			buy.icon = UIBits.shard_texture(28)
			buy.expand_icon = true
			buy.text = "%d" % cost
			if gm.shards >= cost:
				buy.disabled = false
				buy.modulate = Color(1, 1, 1, 1)
			else:
				buy.disabled = true
				buy.modulate = Color(1, 1, 1, 0.45)
				buy.add_theme_color_override("font_disabled_color", Color(1.0, 0.45, 0.45))


func _on_buy(track_id: String) -> void:
	if gm.buy_track(track_id):
		am.play("ui_click", -8.0)
		am.play("levelup_chime", -6.0)
	else:
		am.play("ui_click", -14.0)
	refresh()
