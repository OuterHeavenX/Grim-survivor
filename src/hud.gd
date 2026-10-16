extends CanvasLayer


signal pause_pressed
signal summon_pressed


# The companion sigil: a round button that fills clockwise as the summon
# recharges and pulses when it is ready. Tap/click it, or press Space.
class SummonButton:
	extends Control
	signal pressed
	var frac := 0.0
	var charged := false
	var active := 0.0
	var color := Color(0.5, 1.0, 0.7)
	var portrait: Texture2D
	var label := ""
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(124, 124)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed):
			pressed.emit()
			accept_event()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 6.0
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		if charged:
			draw_circle(c, r + 6.0 + 4.0 * pulse, Color(color, 0.18 + 0.15 * pulse))
		draw_circle(c, r, Color(0.03, 0.03, 0.05, 0.88))
		if portrait:
			var pr := r * 0.86
			draw_texture_rect(portrait, Rect2(c - Vector2(pr, pr), Vector2(pr, pr) * 2.0), false,
				Color(1, 1, 1, 1.0 if charged else 0.45))
		else:
			draw_circle(c, r * 0.35, Color(color, 0.8 if charged else 0.3))
		draw_arc(c, r, 0, TAU, 48, Color(0.15, 0.15, 0.2), 6.0)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, Color(color, 1.0 if charged else 0.75), 6.0)
		if active > 0.0:
			draw_arc(c, r + 9.0, -PI * 0.5, -PI * 0.5 + TAU * active, 48, Color(1, 1, 1, 0.8), 3.0)
		var f := ThemeDB.fallback_font
		var fs := 20
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string_outline(f, Vector2(c.x - w * 0.5, size.y + 20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color.BLACK)
		draw_string(f, Vector2(c.x - w * 0.5, size.y + 20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color.lightened(0.3), 1.0) if charged else Color(0.75, 0.75, 0.8))

const JoystickScript := preload("res://src/joystick_ui.gd")
const IndicatorScript := preload("res://src/offscreen_indicators.gd")

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
var card_title: Label
var card_text: Label
var _card_t := 0.0
var objective_label: Label
var objective_bar: ProgressBar
var indicators: Control
var _heart_t := 0.0
var lowhp: TextureRect
var am = null
var summon_btn: SummonButton
var xp_glow: ColorRect
var hp_text: Label
var hint_label: Label
var _hints: Array = []
var _hint_t := 0.0
var _hint_dur := 0.0
var _last_xp := -1
var _last_level := 1
var _xp_flash := 0.0
var _last_kills := 0
var _kill_pop := 0.0
const KILL_MILESTONES := [50, 100, 250, 500, 1000, 2000, 5000]


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

	# The XP bar is the run's heartbeat: thick, bright and flashing on every
	# gem, so progress reads at a glance on a phone held at arm's length.
	xp_bar = _bar(Color(0.62, 0.42, 1.0), 26.0)
	var xfg := xp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	xfg.border_color = Color(0.85, 0.75, 1.0, 0.9)
	xfg.border_width_bottom = 0
	xfg.border_width_top = 3
	xfg.shadow_color = Color(0.6, 0.35, 1.0, 0.55)
	xfg.shadow_size = 8
	xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_left = 10
	xp_bar.offset_top = 6
	xp_bar.offset_right = -10
	xp_bar.offset_bottom = 32
	add_child(xp_bar)
	xp_glow = ColorRect.new()
	xp_glow.color = Color(1.0, 0.95, 1.0, 0.0)
	xp_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_bar.add_child(xp_glow)

	level_label = _label(30, HORIZONTAL_ALIGNMENT_LEFT)
	level_label.add_theme_color_override("font_color", Color(0.86, 0.76, 1.0))
	level_label.position = Vector2(16, 38)
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

	# The player already wears a health bar overhead; this one is the precise
	# readout, so it can be slimmer and carry the number.
	hp_bar = _bar(Color(0.86, 0.2, 0.22), 16.0)
	hp_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hp_bar.offset_left = -170
	hp_bar.offset_right = 170
	hp_bar.offset_top = -52
	hp_bar.offset_bottom = -34
	add_child(hp_bar)
	hp_text = _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	hp_text.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hp_text.offset_left = -170
	hp_text.offset_right = 170
	hp_text.offset_top = -80
	hp_text.offset_bottom = -54
	hp_text.add_theme_color_override("font_color", Color(1.0, 0.78, 0.76))
	add_child(hp_text)

	hint_label = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_left = -340
	hint_label.offset_right = 340
	hint_label.offset_top = -250
	hint_label.offset_bottom = -150
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	hint_label.modulate.a = 0.0
	add_child(hint_label)

	warn_label = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	warn_label.set_anchors_preset(Control.PRESET_CENTER)
	warn_label.offset_left = -340
	warn_label.offset_right = 340
	warn_label.offset_top = -260
	warn_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	warn_label.modulate.a = 0.0
	add_child(warn_label)

	# Stage card: the stage's name and its rule in one line, shown on entry
	# without pausing anything.
	card_title = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	card_title.set_anchors_preset(Control.PRESET_CENTER)
	card_title.offset_left = -340
	card_title.offset_right = 340
	card_title.offset_top = -400
	card_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	card_title.modulate.a = 0.0
	add_child(card_title)
	card_text = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	card_text.set_anchors_preset(Control.PRESET_CENTER)
	card_text.offset_left = -340
	card_text.offset_right = 340
	card_text.offset_top = -350
	card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_text.modulate.a = 0.0
	add_child(card_text)

	objective_label = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_label.offset_left = -300
	objective_label.offset_right = 300
	objective_label.offset_top = 164
	objective_label.offset_bottom = 192
	objective_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	objective_label.visible = false
	add_child(objective_label)
	objective_bar = _bar(Color(1.0, 0.82, 0.4), 10.0)
	objective_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_bar.offset_left = -200
	objective_bar.offset_right = 200
	objective_bar.offset_top = 194
	objective_bar.offset_bottom = 204
	objective_bar.visible = false
	add_child(objective_bar)

	indicators = IndicatorScript.new()
	add_child(indicators)

	summon_btn = SummonButton.new()
	summon_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	summon_btn.offset_left = -150
	summon_btn.offset_right = -26
	summon_btn.offset_top = -230
	summon_btn.offset_bottom = -106
	summon_btn.pressed.connect(func () -> void: summon_pressed.emit())
	add_child(summon_btn)

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
	_warn_t = 0.0
	lowhp.modulate.a = 0.0
	_heart_t = 0.0
	_card_t = 0.0
	card_title.modulate.a = 0.0
	card_text.modulate.a = 0.0
	_hints.clear()
	_hint_t = 0.0
	hint_label.modulate.a = 0.0
	_last_xp = -1
	_last_level = 1
	_xp_flash = 0.0
	_last_kills = 0
	_kill_pop = 0.0
	kills_label.scale = Vector2.ONE


# Queued one after another, each fading in and out over its own duration.
func show_hint(text: String, dur: float) -> void:
	_hints.append([text, dur])


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
	warn_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	warn_label.text = text
	_warn_t = 3.0


func show_card(title: String, text: String) -> void:
	card_title.text = title
	card_text.text = text
	_card_t = 4.5


func _tick_objective() -> void:
	var obj = null
	for o in get_tree().get_nodes_in_group("objectives"):
		if o.has_method("is_active") and o.is_active():
			obj = o
			break
	objective_label.visible = obj != null
	objective_bar.visible = obj != null
	if obj:
		objective_label.text = obj.hud_text()
		objective_bar.value = 100.0 * obj.frac()


func _process(delta: float) -> void:
	if not visible:
		return
	if _warn_t > 0.0:
		_warn_t -= delta
		warn_label.modulate.a = clampf(_warn_t, 0.0, 1.0)
	if _card_t > 0.0:
		_card_t -= delta
		var a := clampf(minf(_card_t, 4.5 - _card_t) * 2.0, 0.0, 1.0)
		card_title.modulate.a = a
		card_text.modulate.a = a
	_tick_objective()
	_tick_hint(delta)
	var need: int = gm.xp_needed()
	var target := 100.0 * float(gm.xp) / float(maxi(need, 1))
	if gm.level != _last_level:
		_last_level = gm.level
		xp_bar.value = 0.0
		_xp_flash = 1.0
	elif gm.xp > _last_xp and _last_xp >= 0:
		_xp_flash = maxf(_xp_flash, 0.45)
	_last_xp = gm.xp
	xp_bar.value = lerpf(xp_bar.value, target, minf(1.0, delta * 14.0))
	_xp_flash = maxf(0.0, _xp_flash - delta * 3.0)
	# Nearly full: a slow shimmer says the next power is one gem away.
	var near := 0.18 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 140.0)) if target > 80.0 else 0.0
	xp_glow.color.a = maxf(_xp_flash * 0.75, near)
	level_label.text = "Lv %d" % gm.level
	if gm.kills != _last_kills:
		for m in KILL_MILESTONES:
			if _last_kills < m and gm.kills >= m:
				show_warning("%d SLAIN" % m)
				warn_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		_last_kills = gm.kills
		_kill_pop = 1.0
	_kill_pop = maxf(0.0, _kill_pop - delta * 6.0)
	kills_label.pivot_offset = kills_label.size * Vector2(1.0, 0.5)
	kills_label.scale = Vector2.ONE * (1.0 + 0.16 * _kill_pop)
	var t: float = gm.run_time
	timer_label.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	kills_label.text = "%d slain" % gm.kills
	shard_label.text = "%d" % gm.run_shards
	_tick_summon()
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player:
		var hp: float = player.get("hp")
		var mhp: float = player.get("max_hp")
		hp_bar.value = 100.0 * hp / maxf(mhp, 1.0)
		hp_text.text = "%d / %d" % [ceili(maxf(hp, 0.0)), int(mhp)]
		_tick_lowhp(delta, hp / maxf(mhp, 1.0), bool(player.get("alive")))
	else:
		lowhp.modulate.a = 0.0


func _tick_summon() -> void:
	var main = get_tree().get_first_node_in_group("main")
	var ab = main.get("summon") if main else null
	summon_btn.visible = ab != null and is_instance_valid(ab)
	if not summon_btn.visible:
		return
	var kind: String = gm.selected_companion
	summon_btn.color = gm.COMPANIONS[kind]["color"]
	if summon_btn.portrait == null or summon_btn.get_meta("kind", "") != kind:
		summon_btn.set_meta("kind", kind)
		var path := "res://assets/sprites/companion_%s_portrait.png" % kind
		summon_btn.portrait = load(path) if ResourceLoader.exists(path) else null
	summon_btn.frac = ab.frac_ready()
	summon_btn.charged = ab.is_ready()
	var alive := get_tree().get_nodes_in_group("companions")
	var left := 0.0
	for c in alive:
		left = maxf(left, float(c.life) / maxf(float(c.max_life), 0.01))
	summon_btn.active = left
	summon_btn.label = "SUMMON" if ab.is_ready() else "%ds" % int(ceil(ab.cooldown_left))


func _tick_hint(delta: float) -> void:
	if _hint_t <= 0.0:
		if _hints.is_empty():
			hint_label.modulate.a = 0.0
			return
		var h: Array = _hints.pop_front()
		hint_label.text = str(h[0])
		_hint_dur = float(h[1])
		_hint_t = _hint_dur
	_hint_t -= delta
	hint_label.modulate.a = clampf(minf(_hint_t, _hint_dur - _hint_t) * 2.5, 0.0, 1.0)


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
