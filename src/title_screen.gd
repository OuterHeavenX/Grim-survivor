extends CanvasLayer


signal start_pressed
signal weapons_pressed
signal upgrades_pressed

var gm = null
var best_label: Label
var shard_label: Label
var sound_btn: Button
var stage_btns: Array[Button] = []
var stage_label: Label
var length_btns: Array[Button] = []
var length_label: Label
var root_page: VBoxContainer
var play_page: VBoxContainer
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
	vb.add_child(_label("Eight stages. Choose your ground and your hour.", 26, Color(0.55, 0.6, 0.72)))

	# Two pages so the title is not a wall of controls: the root offers the
	# three things you can do, and PLAY opens the run setup.
	root_page = VBoxContainer.new()
	root_page.add_theme_constant_override("separation", 16)
	vb.add_child(root_page)
	root_page.add_child(_big_button("PLAY", Color(0.9, 0.93, 1.0),
		func () -> void: _show_page(true)))
	root_page.add_child(_big_button("ARMOURY", Color(0.95, 0.75, 0.35),
		func () -> void: weapons_pressed.emit()))
	root_page.add_child(_big_button("UPGRADES", Color(0.85, 0.6, 1.0),
		func () -> void: upgrades_pressed.emit()))

	play_page = VBoxContainer.new()
	play_page.add_theme_constant_override("separation", 10)
	play_page.visible = false
	vb.add_child(play_page)
	play_page.add_child(_stage_picker())
	play_page.add_child(_big_button("START", Color(0.9, 0.93, 1.0),
		func () -> void: start_pressed.emit()))
	play_page.add_child(_big_button("BACK", Color(0.55, 0.6, 0.72),
		func () -> void: _show_page(false)))

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

	# show_screen() also refreshes, but the title is visible from boot without
	# necessarily going through it, so seed the picker's state here.
	_refresh_stages()
	_refresh_sound()


func _stage_picker() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	# Eight stages will not fit on one phone-width row, so wrap them.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in gm.STAGES.size():
		var b := Button.new()
		b.text = _numeral(i)
		b.custom_minimum_size = Vector2(104, 56)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_stage.bind(i))
		stage_btns.append(b)
		grid.add_child(b)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	box.add_child(gc)

	stage_label = _label("", 22, Color(0.62, 0.66, 0.78))
	box.add_child(stage_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for m in gm.RUN_LENGTHS:
		var b := Button.new()
		b.text = "%d" % m
		b.custom_minimum_size = Vector2(82, 54)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_length.bind(int(m)))
		length_btns.append(b)
		row.add_child(b)
	var lc := CenterContainer.new()
	lc.add_child(row)
	box.add_child(lc)

	length_label = _label("", 22, Color(0.62, 0.66, 0.78))
	box.add_child(length_label)
	return box


func _on_length(m: int) -> void:
	am.play("ui_click", -8.0)
	gm.selected_minutes = m
	_refresh_stages()


func _on_stage(i: int) -> void:
	am.play("ui_click", -8.0)
	gm.selected_stage = i
	_refresh_stages()


func _numeral(i: int) -> String:
	const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
	return NUMERALS[i] if i < NUMERALS.size() else str(i + 1)


func _refresh_stages() -> void:
	for i in stage_btns.size():
		var chosen: bool = i == int(gm.selected_stage)
		var b: Button = stage_btns[i]
		b.text = "[ %s ]" % _numeral(i) if chosen else _numeral(i)
		b.add_theme_color_override("font_color",
			Color(1.0, 0.82, 0.35) if chosen else Color(0.5, 0.54, 0.64))
	if stage_label != null:
		var sd: Dictionary = gm.STAGES[clampi(int(gm.selected_stage), 0, gm.STAGES.size() - 1)]
		stage_label.text = "%s  \u2014  %s" % [str(sd["name"]), str(sd["boss_name"])]

	var lengths: Array = gm.RUN_LENGTHS
	for i in length_btns.size():
		var picked: bool = int(lengths[i]) == int(gm.selected_minutes)
		var b: Button = length_btns[i]
		b.text = "[%d]" % int(lengths[i]) if picked else "%d" % int(lengths[i])
		b.add_theme_color_override("font_color",
			Color(1.0, 0.82, 0.35) if picked else Color(0.5, 0.54, 0.64))
	if length_label != null:
		var n: int = gm.stages_in_run()
		length_label.text = "%d min  \u2014  %d stage%s" % [int(gm.selected_minutes), n, "" if n == 1 else "s"]


func _big_button(text: String, col: Color, on_press: Callable) -> Control:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 92)
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(on_press)
	var c := CenterContainer.new()
	c.add_child(b)
	return c


func _show_page(play: bool) -> void:
	am.play("ui_click", -8.0)
	root_page.visible = not play
	play_page.visible = play


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
	if root_page != null:
		root_page.visible = true
	if play_page != null:
		play_page.visible = false
	_refresh_stages()
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
