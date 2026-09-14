extends CanvasLayer


signal pause_pressed

const JoystickScript := preload("res://src/joystick_ui.gd")

var gm = null
var player = null

var xp_bar: ProgressBar
var hp_bar: ProgressBar
var boss_bar: ProgressBar
var boss_label: Label
var level_label: Label
var timer_label: Label
var stage_label: Label
var kills_label: Label
var shard_label: Label
var warn_label: Label
var joy = null
var pause_btn: Button

var _warn_t := 0.0
var _heart_t := 0.0
var lowhp: TextureRect
var am = null


func _ready() -> void:
	layer = 10
	gm = get_node("/root/GameManager")
	am = get_node("/root/AudioMan")

	var vig := TextureRect.new()
	vig.texture = _vignette_tex()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

	lowhp = TextureRect.new()
	lowhp.texture = _lowhp_tex()
	lowhp.set_anchors_preset(Control.PRESET_FULL_RECT)
	lowhp.stretch_mode = TextureRect.STRETCH_SCALE
	lowhp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lowhp.modulate.a = 0.0
	add_child(lowhp)

	xp_bar = _bar(Color(0.55, 0.35, 0.95), 18.0)
	xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_left = 10
	xp_bar.offset_top = 8
	xp_bar.offset_right = -10
	xp_bar.offset_bottom = 28
	add_child(xp_bar)

	level_label = _label(28, HORIZONTAL_ALIGNMENT_LEFT)
	level_label.position = Vector2(16, 36)
	add_child(level_label)

	timer_label = _label(46, HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.offset_left = -160
	timer_label.offset_right = 160
	timer_label.offset_top = 34
	timer_label.offset_bottom = 90
	add_child(timer_label)

	stage_label = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	stage_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stage_label.offset_left = -200
	stage_label.offset_right = 200
	stage_label.offset_top = 88
	stage_label.offset_bottom = 116
	add_child(stage_label)

	kills_label = _label(28, HORIZONTAL_ALIGNMENT_RIGHT)
	kills_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kills_label.offset_left = -260
	kills_label.offset_right = -92
	kills_label.offset_top = 38
	kills_label.offset_bottom = 70
	add_child(kills_label)

	pause_btn = Button.new()
	pause_btn.text = "I I"
	pause_btn.add_theme_font_size_override("font_size", 26)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -76
	pause_btn.offset_top = 30
	pause_btn.offset_right = -12
	pause_btn.offset_bottom = 94
	pause_btn.pressed.connect(func () -> void: pause_pressed.emit())
	add_child(pause_btn)

	shard_label = _label(28, HORIZONTAL_ALIGNMENT_RIGHT)
	shard_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shard_label.offset_left = -260
	shard_label.offset_right = -92
	shard_label.offset_top = 72
	shard_label.offset_bottom = 104
	shard_label.add_theme_color_override("font_color", Color(0.75, 0.45, 1.0))
	add_child(shard_label)

	var shard_icon := TextureRect.new()
	shard_icon.texture = UIBits.shard_texture(30)
	shard_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shard_icon.offset_left = -306
	shard_icon.offset_right = -274
	shard_icon.offset_top = 72
	shard_icon.offset_bottom = 104
	shard_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shard_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(shard_icon)

	boss_label = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	boss_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_label.offset_left = -300
	boss_label.offset_right = 300
	boss_label.offset_top = 100
	boss_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.5))
	boss_label.visible = false
	add_child(boss_label)

	boss_bar = _bar(Color(0.7, 0.15, 0.3), 20.0)
	boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_bar.offset_left = -280
	boss_bar.offset_right = 280
	boss_bar.offset_top = 134
	boss_bar.offset_bottom = 156
	boss_bar.visible = false
	add_child(boss_bar)

	hp_bar = _bar(Color(0.25, 0.9, 0.35), 22.0)
	hp_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hp_bar.offset_left = -220
	hp_bar.offset_right = 220
	hp_bar.offset_top = -66
	hp_bar.offset_bottom = -42
	add_child(hp_bar)

	warn_label = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	warn_label.set_anchors_preset(Control.PRESET_CENTER)
	warn_label.offset_left = -340
	warn_label.offset_right = 340
	warn_label.offset_top = -260
	warn_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	warn_label.modulate.a = 0.0
	add_child(warn_label)

	joy = JoystickScript.new()
	add_child(joy)


func _vignette_tex() -> GradientTexture2D:
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.9)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.01, 0.01, 0.03, 0.62),
	])
	grad.gradient = g
	grad.width = 256
	grad.height = 256
	return grad


func _lowhp_tex() -> GradientTexture2D:
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.85)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(0.6, 0, 0, 0), Color(0.6, 0, 0, 0), Color(0.55, 0.02, 0.05, 0.75),
	])
	grad.gradient = g
	grad.width = 256
	grad.height = 256
	return grad


func _label(fs: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	return l


func _bar(fill: Color, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 100.0
	b.value = 100.0
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.05, 0.09, 0.88)
	bg.set_corner_radius_all(5)
	bg.border_color = Color(0.2, 0.22, 0.32)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(5)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.custom_minimum_size = Vector2(0, h)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b



func set_stage(idx: int, stage_name: String) -> void:
	stage_label.text = "STAGE %d — %s" % [idx + 1, stage_name]


func reset() -> void:
	xp_bar.value = 0.0
	hp_bar.value = 100.0
	boss_bar.visible = false
	boss_label.visible = false
	warn_label.modulate.a = 0.0
	lowhp.modulate.a = 0.0
	_heart_t = 0.0


func set_run_visible(v: bool) -> void:
	visible = v


func show_boss(bname: String) -> void:
	boss_label.text = bname
	boss_label.visible = true
	boss_bar.visible = true


func update_boss(hp: float, max_hp: float) -> void:
	if max_hp > 0.0:
		boss_bar.value = 100.0 * hp / max_hp


func hide_boss() -> void:
	boss_label.visible = false
	boss_bar.visible = false


func show_warning(text: String) -> void:
	warn_label.text = text
	_warn_t = 3.0


func _process(delta: float) -> void:
	if not visible:
		return
	if _warn_t > 0.0:
		_warn_t -= delta
		warn_label.modulate.a = clampf(_warn_t, 0.0, 1.0)
	var need: int = gm.xp_needed()
	xp_bar.value = 100.0 * float(gm.xp) / float(maxi(need, 1))
	level_label.text = "Lv %d" % gm.level
	var t: float = gm.run_time
	timer_label.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	kills_label.text = "%d slain" % gm.kills
	shard_label.text = "%d" % gm.run_shards
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player:
		var hp: float = player.get("hp")
		var mhp: float = player.get("max_hp")
		hp_bar.value = 100.0 * hp / maxf(mhp, 1.0)
		_tick_lowhp(delta, hp / maxf(mhp, 1.0), bool(player.get("alive")))
	else:
		lowhp.modulate.a = 0.0


func _tick_lowhp(delta: float, frac: float, alive: bool) -> void:
	if alive and frac < 0.3:
		var danger := 1.0 - frac / 0.3
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 7.0)
		lowhp.modulate.a = (0.25 + 0.55 * pulse) * (0.35 + 0.65 * danger)
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = 0.85
			am.play("heartbeat", -8.0, 0.95)
	else:
		lowhp.modulate.a = 0.0
		_heart_t = 0.0
