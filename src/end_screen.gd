extends CanvasLayer


signal restart_pressed
signal title_pressed

var title_label: Label
var stats_label: Label
var report_label: Label
var _restart_btn: Button
var is_victory := false
var share_btn: Button
var _share_text := ""
const GAME_URL := "https://outerheavenx.github.io/Grim-survivor/"


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	title_label = _label("", 72, Color.WHITE)
	vb.add_child(title_label)
	stats_label = _label("", 30, Color(0.85, 0.88, 0.94))
	vb.add_child(stats_label)
	report_label = _label("", 20, Color(0.72, 0.76, 0.86))
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_label.custom_minimum_size = Vector2(640, 0)
	vb.add_child(report_label)

	var restart := Button.new()
	restart.text = "RESTART"
	restart.custom_minimum_size = Vector2(420, 104)
	restart.add_theme_font_size_override("font_size", 36)
	restart.pressed.connect(func () -> void: restart_pressed.emit())
	_restart_btn = restart
	var rc := CenterContainer.new()
	rc.add_child(restart)
	vb.add_child(rc)

	share_btn = Button.new()
	share_btn.text = "SHARE RESULT"
	share_btn.custom_minimum_size = Vector2(420, 72)
	share_btn.add_theme_font_size_override("font_size", 26)
	share_btn.add_theme_color_override("font_color", Color(0.95, 0.7, 1.0))
	share_btn.pressed.connect(_on_share)
	var sc := CenterContainer.new()
	sc.add_child(share_btn)
	vb.add_child(sc)

	var menu := Button.new()
	menu.text = "TITLE"
	menu.custom_minimum_size = Vector2(420, 80)
	menu.add_theme_font_size_override("font_size", 28)
	menu.pressed.connect(func () -> void: title_pressed.emit())
	var mc := CenterContainer.new()
	mc.add_child(menu)
	vb.add_child(mc)


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_screen(victory: bool, time: float, kills: int, level: int, shards_earned: int = 0, stats: RunStats = null) -> void:
	# Visible before any text is built: a failure in the report must never
	# leave a paused game with nothing on screen.
	visible = true
	is_victory = victory
	if victory:
		title_label.text = "VICTORY"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	else:
		title_label.text = "SLAIN"
		title_label.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
	stats_label.text = "Survived %d:%02d\n%d slain    Level %d\n+%d soul shards" % [
		int(time) / 60, int(time) % 60, kills, level, shards_earned,
	]
	report_label.text = report_text(stats) if stats else ""
	var gm = get_node_or_null("/root/GameManager")
	var head := "GRIM SURVIVORS"
	if gm and gm.daily:
		head = "GRIM SURVIVORS  -  Daily Rite %s" % gm.daily_key()
		stats_label.text = "DAILY RITE  •  %s\n" % gm.daily_key() + stats_label.text
	var where := ""
	if gm:
		where = " in %s" % str(gm.stage_data()["name"])
	_share_text = "%s\n%s at %s%s  |  %d slain  |  Lv %d\nCan you outlast me? %s" % [
		head, "Victorious" if victory else "Fell", _fmt_time(time), where, kills, level, GAME_URL]
	share_btn.text = "SHARE RESULT"
	visible = true
	if _restart_btn:
		_restart_btn.grab_focus()


# On a phone the system share sheet; everywhere else the clipboard.
func _on_share() -> void:
	var shared := false
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		var js := "(function(t){if(navigator.share){navigator.share({text:t}).catch(function(){});return true;}return false;})(%s)" % JSON.stringify(_share_text)
		shared = bool(JavaScriptBridge.eval(js, true))
	if not shared:
		DisplayServer.clipboard_set(_share_text)
	share_btn.text = "SHARED" if shared else "COPIED TO CLIPBOARD"
	var am = get_node_or_null("/root/AudioMan")
	if am:
		am.play("ui_click", -8.0)


static func _fmt_num(v: float) -> String:
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return str(int(round(v)))


static func _fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


func report_text(s: RunStats) -> String:
	# Short lines that fit a 720px portrait screen.
	var gm = get_node_or_null("/root/GameManager")
	var lines: Array[String] = []
	lines.append("RUN SEED %d  |  STAGES CLEARED %d" % [s.run_seed, s.stages_cleared])
	var dmg: Array[String] = []
	for row in s.top_damage(5):
		var src: String = str(row[0])
		var nm := src
		if gm and gm.WEAPONS.has(src):
			nm = str(gm.WEAPONS[src]["name"])
		elif src.begins_with("interaction:") or src.begins_with("relic:"):
			nm = src.get_slice(":", 1).capitalize()
		dmg.append("%s %s" % [nm, _fmt_num(float(row[1]))])
	if not dmg.is_empty():
		lines.append("DAMAGE  " + ", ".join(dmg))
	if not s.evolved.is_empty():
		var ev: Array[String] = []
		for id in s.evolved:
			ev.append(str(gm.EVOLUTIONS[id]["name"]) if gm and gm.EVOLUTIONS.has(id) else id)
		lines.append("EVOLVED  " + ", ".join(ev))
	lines.append("TAKEN %s  |  HEALED %s  |  ELITES %d" % [_fmt_num(s.damage_taken), _fmt_num(s.healing), s.elites_killed])
	var bt: Array[String] = []
	for st in s.stages:
		if float(st.get("boss_time", -1.0)) >= 0.0:
			bt.append("%d: %s" % [int(st["stage"]) + 1, _fmt_time(float(st["boss_time"]))])
	if not bt.is_empty():
		lines.append("BOSS TIME  " + ", ".join(bt))
	if not s.relics.is_empty():
		var rn: Array[String] = []
		for id in s.relics:
			var r = gm.CONTENT.relic(id) if gm else null
			rn.append(r.display_name if r else id)
		lines.append("RELICS  " + ", ".join(rn))
	if not s.recoveries.is_empty():
		lines.append("SAFETY NET  " + ", ".join(s.recoveries).to_upper())
	return "\n".join(lines)


func hide_screen() -> void:
	visible = false
