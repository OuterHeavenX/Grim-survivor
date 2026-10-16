extends CanvasLayer
# Companion selection. Each pact is a companion the survivor can summon in a
# run; one is free, one is bought with shards, two are earned.

signal closed

var gm = null
var am = null
var balance_label: Label
var stats_label: Label
var cards := {}


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	gm = get_node("/root/GameManager")
	am = get_node("/root/AudioMan")

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	vb.add_child(_label("PACTS", 50, Color(0.55, 1.0, 0.8)))
	var sub := _label("Summon your companion with SPACE, Q or the sigil button. It fights for a few seconds, then must recharge.", 20, Color(0.55, 0.65, 0.68))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)
	balance_label = _label("", 26, Color(0.75, 0.45, 1.0))
	vb.add_child(balance_label)
	stats_label = _label("", 20, Color(0.75, 0.95, 0.85))
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(stats_label)
	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for id in gm.COMPANION_ORDER:
		var card := _card(id)
		cards[id] = card["refs"]
		list.add_child(card["node"])

	vb.add_child(HSeparator.new())
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(420, 88)
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(func () -> void: closed.emit())
	var cc := CenterContainer.new()
	cc.add_child(close)
	vb.add_child(cc)


class Glyph:
	extends Control
	var color := Color.WHITE
	var tex: Texture2D
	var _t := 0.0

	func _init(c: Color, t: Texture2D) -> void:
		color = c
		tex = t
		custom_minimum_size = Vector2(120, 120)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var pulse := 0.5 + 0.5 * sin(_t * 2.5)
		draw_circle(c, 56.0, Color(color, 0.10 + 0.08 * pulse))
		draw_arc(c, 54.0, 0, TAU, 40, Color(color, 0.6), 2.0)
		if tex:
			draw_texture_rect(tex, Rect2(c - Vector2(54, 54), Vector2(108, 108)), false, modulate)
		else:
			# The wisp is fire, not a figure.
			var f := 1.0 + 0.12 * sin(_t * 15.0)
			draw_circle(c, 24.0 * f, Color(color, 0.4))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 8), c + Vector2(0, -30 * f), c + Vector2(12, 8), c + Vector2(0, 14)]), Color(1.0, 0.8, 0.45))
			draw_circle(c + Vector2(0, 4), 7.0, Color(1, 0.97, 0.85))


func _card(id: String) -> Dictionary:
	var c: Dictionary = gm.COMPANIONS[id]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.08, 0.95)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	panel.add_child(hb)
	var path := "res://assets/sprites/companion_%s_portrait.png" % id
	var glyph := Glyph.new(c["color"], load(path) if ResourceLoader.exists(path) else null)
	hb.add_child(glyph)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	var name_l := _label(str(c["name"]), 28, Color(c["color"]).lightened(0.3))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(name_l)
	var desc := _label(str(c["desc"]), 19, Color(0.65, 0.7, 0.74))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	var lock_l := _label("", 18, Color(1.0, 0.78, 0.4))
	lock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lock_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(lock_l)
	var action := Button.new()
	action.custom_minimum_size = Vector2(140, 64)
	action.add_theme_font_size_override("font_size", 22)
	action.pressed.connect(_on_action.bind(id))
	var side := CenterContainer.new()
	side.add_child(action)
	hb.add_child(side)
	return {"node": panel, "refs": {"sb": sb, "action": action, "lock": lock_l, "glyph": glyph}}


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
	stats_label.text = "Lasts %.0fs  •  Recharges %.0fs  •  %d%% power   (raise these in SOUL UPGRADES › PACT)" % [
		gm.companion_duration(), gm.companion_cooldown(),
		int(round(100.0 * (1.0 + 0.12 * float(gm.meta_rank("pact_might")))))]
	for id in gm.COMPANION_ORDER:
		var refs: Dictionary = cards[id]
		var c: Dictionary = gm.COMPANIONS[id]
		var sb: StyleBoxFlat = refs["sb"]
		var action: Button = refs["action"]
		var lock_l: Label = refs["lock"]
		var glyph: Control = refs["glyph"]
		lock_l.visible = false
		glyph.modulate = Color.WHITE
		if id == gm.selected_companion:
			sb.border_color = c["color"]
			action.text = "ACTIVE"
			action.disabled = true
		elif gm.is_companion_unlocked(id):
			sb.border_color = Color(0.2, 0.3, 0.32)
			action.text = "SELECT"
			action.disabled = false
		else:
			sb.border_color = Color(0.25, 0.22, 0.18)
			glyph.modulate = Color(0.35, 0.35, 0.4)
			lock_l.text = "Unlock: " + gm.companion_unlock_text(id)
			lock_l.visible = true
			if str(c["unlock"]) == "shards":
				action.text = "%d" % int(c["cost"])
				action.icon = UIBits.shard_texture(26)
				action.expand_icon = true
				action.disabled = gm.shards < int(c["cost"])
			else:
				action.text = "LOCKED"
				action.icon = null
				action.disabled = true


func _on_action(id: String) -> void:
	if gm.is_companion_unlocked(id):
		if gm.select_companion(id):
			am.play("ui_click", -8.0)
	elif gm.unlock_companion(id):
		am.play("levelup_chime", -6.0)
		gm.select_companion(id)
	else:
		am.play("ui_click", -14.0)
	refresh()
