extends CanvasLayer


signal start_pressed
signal upgrades_pressed

var gm = null
var best_label: Label
var shard_label: Label
var sound_btn: Button
var am = null


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	gm = get_node("/root/GameManager")
	am = get_node("/root/AudioMan")

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := _label("GRIM SURVIVORS", 76, Color(0.85, 0.88, 0.96))
	vb.add_child(title)
	vb.add_child(_label("Three stages. Fell the Cinder King.", 26, Color(0.55, 0.6, 0.72)))

	var start := Button.new()
	start.text = "START"
	start.custom_minimum_size = Vector2(420, 110)
	start.add_theme_font_size_override("font_size", 40)
	start.pressed.connect(func () -> void: start_pressed.emit())
	var sc := CenterContainer.new()
	sc.add_child(start)
	vb.add_child(sc)

	var upg := Button.new()
	upg.text = "UPGRADES"
	upg.custom_minimum_size = Vector2(420, 90)
	upg.add_theme_font_size_override("font_size", 32)
	upg.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	upg.pressed.connect(func () -> void: upgrades_pressed.emit())
	var uc := CenterContainer.new()
	uc.add_child(upg)
	vb.add_child(uc)

	var shard_center := CenterContainer.new()
	var shard_hb := HBoxContainer.new()
	shard_hb.add_theme_constant_override("separation", 10)
	var shard_icon := TextureRect.new()
	shard_icon.texture = UIBits.shard_texture(32)
	shard_icon.custom_minimum_size = Vector2(32, 32)
	shard_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shard_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shard_hb.add_child(shard_icon)
	shard_label = _label("", 30, Color(0.75, 0.45, 1.0))
	shard_hb.add_child(shard_label)
	shard_center.add_child(shard_hb)
	vb.add_child(shard_center)

	best_label = _label("", 26, Color(1.0, 0.85, 0.4))
	vb.add_child(best_label)

	vb.add_child(_label("Move: WASD / arrows, or drag on touch", 22, Color(0.45, 0.5, 0.62)))
	vb.add_child(_label("Weapons fire on their own. Grab the gems.", 22, Color(0.45, 0.5, 0.62)))

	sound_btn = Button.new()
	sound_btn.add_theme_font_size_override("font_size", 34)
	sound_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sound_btn.offset_left = -96
	sound_btn.offset_top = 24
	sound_btn.offset_right = -24
	sound_btn.offset_bottom = 96
	sound_btn.pressed.connect(_on_sound)
	add_child(sound_btn)
	_refresh_sound()


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_screen() -> void:
	_refresh_sound()
	var b: Dictionary = gm.best
	var t := float(b.get("time", 0.0))
	best_label.text = "BEST  %d:%02d    %d slain    Lv %d    %d victories" % [
		int(t) / 60, int(t) % 60,
		int(b.get("kills", 0)), int(b.get("level", 0)), int(b.get("wins", 0)),
	]
	shard_label.text = "%d soul shards" % gm.shards
	visible = true


func hide_screen() -> void:
	visible = false


func _on_sound() -> void:
	am.toggle_mute()
	_refresh_sound()
	am.play("ui_click", -8.0)


func _refresh_sound() -> void:
	sound_btn.text = "🔇" if am.is_muted() else "🔊"
