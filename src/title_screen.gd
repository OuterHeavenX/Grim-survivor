extends CanvasLayer

signal start_pressed
signal daily_pressed
signal survivors_pressed
signal weapons_pressed
signal upgrades_pressed
signal unlocks_pressed
signal settings_pressed

var gm
var am
var root_page: VBoxContainer
var play_page: VBoxContainer
var portrait: TextureRect
var altar: AltarStage
var hero_name: Label
var hero_weapon: Label
var progress_label: Label
var next_label: Label
var shard_label: Label
var best_label: Label
var sound_btn: Button
var continue_btn: Button
var descent_btn: Button
var daily_btn: Button
var stage_label: Label
var length_label: Label
var mode_label: Label
var stage_btns: Array[Button] = []
var length_btns: Array[Button] = []
var mode_btns: Array[Button] = []


# The altar the selected survivor stands in: a stone arch, light falling from
# above, a slowly turning sigil in the sigil's colour, candles and rising
# embers. Everything is drawn, so it costs no download and scales to any size.
class AltarStage:
	extends Control
	signal tapped
	var accent := Color(0.42, 0.46, 0.56)
	var portrait: TextureRect
	var front: Control
	var _t := 0.0
	var _embers: Array = []
	var _glow: Texture2D
	const EMBERS := 46
	const FLOOR := 0.76

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		clip_contents = true
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.85))
		g.set_color(1, Color(1, 1, 1, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		_glow = gt
		portrait = TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(portrait)
		front = Control.new()
		front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.set_anchors_preset(Control.PRESET_FULL_RECT)
		front.draw.connect(_draw_front)
		add_child(front)
		for i in EMBERS:
			_embers.append(_new_ember(true))

	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed):
			tapped.emit()
			accept_event()

	func _new_ember(anywhere: bool) -> Dictionary:
		return {
			"x": randf(), "y": randf() if anywhere else randf_range(0.85, 1.0),
			"vy": randf_range(0.035, 0.11), "sway": randf() * TAU,
			"r": randf_range(1.0, 2.8), "life": randf_range(0.5, 1.0),
		}

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		for e in _embers:
			e["y"] -= e["vy"] * delta
			e["x"] += sin(_t * 1.3 + e["sway"]) * 0.012 * delta
			if e["y"] < -0.02:
				e.merge(_new_ember(false), true)
		# The survivor breathes: a slow rise and a slight swell.
		var w := size.x
		var h := size.y
		var ps := minf(w * 0.54, h * 0.58)
		var breathe := sin(_t * 1.6)
		portrait.size = Vector2(ps, ps)
		portrait.pivot_offset = Vector2(ps * 0.5, ps)
		portrait.scale = Vector2.ONE * (1.0 + 0.012 * breathe)
		portrait.position = Vector2((w - ps) * 0.5, h * FLOOR + 14.0 - ps + breathe * 2.0)
		queue_redraw()
		front.queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cx := w * 0.5
		var floor_y := h * FLOOR
		# Night-dark stone fading to an ember-lit floor.
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0.02, 0.02, 0.035), Color(0.02, 0.02, 0.035),
				Color(0.09, 0.05, 0.04), Color(0.09, 0.05, 0.04)]))
		_draw_pillar(w * 0.08, w * 0.11, floor_y, h)
		_draw_pillar(w * 0.92, w * 0.11, floor_y, h)
		_draw_arch(cx, floor_y, w * 0.34, h * 0.07)
		# Light falling through the arch, swaying a little.
		for i in 3:
			var sway := sin(_t * 0.35 + float(i) * 1.7) * w * 0.03
			var top_x := cx + (float(i) - 1.0) * w * 0.09 + sway
			var spread := w * (0.1 + 0.04 * float(i))
			var a := 0.05 + 0.025 * sin(_t * 0.8 + float(i))
			draw_polygon(PackedVector2Array([
				Vector2(top_x - w * 0.02, h * 0.06), Vector2(top_x + w * 0.02, h * 0.06),
				Vector2(top_x + spread, floor_y), Vector2(top_x - spread, floor_y)]),
				PackedColorArray([Color(accent.lightened(0.4), a), Color(accent.lightened(0.4), a),
					Color(accent, 0.0), Color(accent, 0.0)]))
		# A halo in the sigil's colour behind the survivor.
		var pulse := 0.5 + 0.5 * sin(_t * 1.2)
		var gr := minf(w, h) * (0.42 + 0.03 * pulse)
		draw_texture_rect(_glow, Rect2(Vector2(cx, floor_y - h * 0.3) - Vector2.ONE * gr, Vector2.ONE * gr * 2.0),
			false, Color(accent, 0.30 + 0.12 * pulse))
		# Flagstones receding from the arch.
		draw_rect(Rect2(0, floor_y, w, h - floor_y), Color(0.045, 0.035, 0.04))
		for k in 5:
			var y := floor_y + (h - floor_y) * pow(float(k + 1) / 5.0, 1.6)
			draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, 0.6), 2.0)
		for k in range(-6, 7):
			draw_line(Vector2(cx + float(k) * w * 0.05, floor_y), Vector2(cx + float(k) * w * 0.2, h), Color(0, 0, 0, 0.45), 2.0)

	func _draw_pillar(x: float, pw: float, floor_y: float, h: float) -> void:
		var stone := Color(0.075, 0.07, 0.085)
		draw_rect(Rect2(x - pw * 0.5, 0, pw, floor_y), stone)
		draw_rect(Rect2(x - pw * 0.5, 0, pw * 0.22, floor_y), Color(0.11, 0.1, 0.12))
		draw_rect(Rect2(x + pw * 0.3, 0, pw * 0.2, floor_y), Color(0.04, 0.035, 0.05))
		for k in 7:
			var y := floor_y * float(k) / 7.0
			draw_line(Vector2(x - pw * 0.5, y), Vector2(x + pw * 0.5, y), Color(0, 0, 0, 0.5), 2.0)
		draw_rect(Rect2(x - pw * 0.7, floor_y - 18, pw * 1.4, 18), Color(0.09, 0.085, 0.1))
		draw_rect(Rect2(x - pw * 0.7, floor_y, pw * 1.4, h - floor_y), Color(0.05, 0.04, 0.05))

	func _arch_points(cx: float, base_y: float, half: float, top: float) -> PackedVector2Array:
		# An equilateral gothic arch: each side is an arc of radius equal to the
		# span, centred on the opposite springing point.
		var r := half * 2.0
		var spring := minf(top + r * sin(PI / 3.0), base_y)
		var pts := PackedVector2Array()
		pts.append(Vector2(cx - half, base_y))
		var steps := 18
		for i in steps + 1:
			var a := PI - float(i) / float(steps) * (PI / 3.0)
			pts.append(Vector2(cx + half + cos(a) * r, spring - sin(a) * r))
		for i in range(steps - 1, -1, -1):
			var a := float(i) / float(steps) * (PI / 3.0)
			pts.append(Vector2(cx - half + cos(a) * r, spring - sin(a) * r))
		pts.append(Vector2(cx + half, base_y))
		return pts

	func _draw_arch(cx: float, floor_y: float, half: float, top: float) -> void:
		var outer := _arch_points(cx, floor_y, half + 26.0, top)
		var inner := _arch_points(cx, floor_y, half, top + 30.0)
		draw_colored_polygon(outer, Color(0.085, 0.08, 0.095))
		draw_colored_polygon(inner, Color(0.012, 0.01, 0.018))
		# Voussoirs: joints running from the inner edge to the outer one.
		var n := mini(outer.size(), inner.size())
		for i in range(2, n - 2, 3):
			draw_line(inner[i], outer[i], Color(0, 0, 0, 0.55), 2.0)
		draw_polyline(inner, Color(accent.lightened(0.2), 0.22), 2.0)
		draw_polyline(outer, Color(0.16, 0.15, 0.17), 2.0)

	func _draw_sigil(cx: float, cy: float, r: float) -> void:
		var pulse := 0.55 + 0.45 * sin(_t * 1.2)
		var col := Color(accent.lightened(0.15), 0.55 + 0.3 * pulse)
		front.draw_set_transform(Vector2(cx, cy), 0.0, Vector2(1.0, 0.3))
		front.draw_circle(Vector2.ZERO, r * 1.05, Color(accent, 0.10 * pulse))
		front.draw_arc(Vector2.ZERO, r, 0, TAU, 64, col, 3.0)
		front.draw_arc(Vector2.ZERO, r * 0.82, 0, TAU, 64, Color(col, col.a * 0.7), 2.0)
		var spin := _t * 0.25
		for i in 24:
			var a := spin + TAU * float(i) / 24.0
			var d := Vector2.from_angle(a)
			front.draw_line(d * r * 0.84, d * r * (0.95 if i % 2 == 0 else 0.9), col, 2.0)
		# Five-pointed star turning against the ring.
		var star := PackedVector2Array()
		for i in 6:
			star.append(Vector2.from_angle(-spin * 1.6 + TAU * float(i * 2 % 5) / 5.0) * r * 0.78)
		front.draw_polyline(star, Color(col, col.a * 0.8), 2.0)
		front.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func cx_of(w: float) -> float:
		return w * 0.5

	func _draw_front() -> void:
		var w := size.x
		var h := size.y
		var floor_y := h * FLOOR
		# Fade the portrait's cut edge into the floor so the survivor stands in
		# the circle rather than being clipped by it.
		var pb := portrait.position.y + portrait.size.y * portrait.scale.y
		var pl := portrait.position.x - 10.0
		var pr := portrait.position.x + portrait.size.x + 10.0
		var floor_c := Color(0.045, 0.035, 0.04)
		front.draw_polygon(PackedVector2Array([Vector2(pl, pb - 70.0), Vector2(pr, pb - 70.0), Vector2(pr, pb + 2.0), Vector2(pl, pb + 2.0)]),
			PackedColorArray([Color(floor_c, 0.0), Color(floor_c, 0.0), floor_c, floor_c]))
		_draw_sigil(cx_of(w), floor_y + 10.0, w * 0.4)
		# Ground mist hides where the portrait is cut off.
		for i in 4:
			var mx := w * (0.5 + 0.28 * sin(_t * 0.18 + float(i) * 1.9))
			var mr := w * (0.32 + 0.05 * float(i))
			front.draw_set_transform(Vector2(mx, floor_y + 6.0 + float(i) * 6.0), 0.0, Vector2(1.0, 0.22))
			front.draw_circle(Vector2.ZERO, mr, Color(0.07, 0.06, 0.07, 0.3))
		front.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for side in [-1.0, 1.0]:
			for k in 3:
				var x: float = w * 0.5 + side * w * (0.27 + 0.055 * float(k))
				var ch := 26.0 + 16.0 * float((k + (1 if side > 0 else 0)) % 3)
				_candle(Vector2(x, floor_y + 30.0 + float(k) * 10.0), ch, float(k) * 2.1 + side)
		for e in _embers:
			var life: float = clampf(1.0 - absf(float(e["y"]) - 0.5) * 2.0, 0.0, 1.0) * float(e["life"])
			var p := Vector2(float(e["x"]) * w, float(e["y"]) * h)
			front.draw_circle(p, float(e["r"]) * 2.4, Color(1.0, 0.45, 0.15, 0.10 * life))
			front.draw_circle(p, float(e["r"]), Color(1.0, 0.7, 0.35, 0.85 * life))
		# Bottom fade into the panel below.
		front.draw_polygon(PackedVector2Array([Vector2(0, h - 40), Vector2(w, h - 40), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.01, 0.01, 0.02, 0.9), Color(0.01, 0.01, 0.02, 0.9)]))

	func _candle(base: Vector2, ch: float, seed_f: float) -> void:
		var cw := 11.0
		front.draw_rect(Rect2(base.x - cw * 0.5, base.y - ch, cw, ch), Color(0.78, 0.72, 0.6))
		front.draw_rect(Rect2(base.x + cw * 0.15, base.y - ch, cw * 0.35, ch), Color(0.6, 0.54, 0.45))
		var flick := 0.85 + 0.15 * sin(_t * 13.0 + seed_f * 3.0) + 0.08 * sin(_t * 23.0 + seed_f)
		var tip := base + Vector2(sin(_t * 3.0 + seed_f) * 1.5, -ch - 16.0 * flick)
		var fb := base + Vector2(0, -ch - 2.0)
		var gr := 46.0 * flick
		front.draw_texture_rect(_glow, Rect2(fb + Vector2(0, -6) - Vector2.ONE * gr, Vector2.ONE * gr * 2.0), false, Color(1.0, 0.55, 0.2, 0.32))
		front.draw_colored_polygon(PackedVector2Array([
			fb + Vector2(-4.5, 0), tip, fb + Vector2(4.5, 0), fb + Vector2(0, 3)]), Color(1.0, 0.62, 0.18))
		front.draw_colored_polygon(PackedVector2Array([
			fb + Vector2(-2.0, -1), fb.lerp(tip, 0.6), fb + Vector2(2.0, -1)]), Color(1.0, 0.95, 0.7))


func _ready() -> void:
	layer = 15; process_mode = Node.PROCESS_MODE_ALWAYS
	gm = get_node("/root/GameManager"); am = get_node("/root/AudioMan")
	var bg := TextureRect.new(); bg.texture = load("res://assets/ground/ashen.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; bg.modulate = Color(0.3,0.28,0.36)
	add_child(bg)
	var veil := ColorRect.new(); veil.color = Color(0.01,0.015,0.03,0.78); veil.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(veil)
	var margin := MarginContainer.new(); margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side, 26)
	add_child(margin)
	var shell := VBoxContainer.new(); shell.add_theme_constant_override("separation", 8); margin.add_child(shell)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 6); shell.add_child(top)
	var brand := VBoxContainer.new(); brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(brand)
	brand.add_child(_label("GRIM SURVIVORS", 36, Color(0.92,0.89,0.82), HORIZONTAL_ALIGNMENT_LEFT))
	brand.add_child(_label("THE ASHEN ALTAR", 18, Color(0.62,0.56,0.5), HORIZONTAL_ALIGNMENT_LEFT))
	shard_label = _label("",22,Color(0.78,0.48,1)); shard_label.custom_minimum_size=Vector2(80,60); top.add_child(shard_label)
	sound_btn = _button("",86,60,14,_on_sound); top.add_child(sound_btn)
	top.add_child(_button("SETTINGS",96,60,14,func(): settings_pressed.emit()))
	root_page=VBoxContainer.new(); root_page.size_flags_vertical=Control.SIZE_EXPAND_FILL; root_page.add_theme_constant_override("separation",8); shell.add_child(root_page)
	progress_label=_label("",22,Color(0.88,0.7,0.36)); root_page.add_child(progress_label)
	altar = AltarStage.new(); altar.tapped.connect(func(): am.play("ui_click",-8); survivors_pressed.emit())
	root_page.add_child(altar); portrait = altar.portrait
	var change := _label("TAP THE ALTAR TO CHANGE SURVIVOR", 14, Color(0.5,0.48,0.56))
	change.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); change.offset_left=-260; change.offset_right=260; change.offset_top=-30; change.offset_bottom=-8
	change.mouse_filter = Control.MOUSE_FILTER_IGNORE; altar.add_child(change)
	hero_name=_label("",36,Color(0.94,0.9,0.8)); root_page.add_child(hero_name)
	hero_weapon=_label("",19,Color(0.65,0.62,0.68)); root_page.add_child(hero_weapon)
	continue_btn=_button("CONTINUE",0,92,35,_on_continue); continue_btn.add_theme_color_override("font_color",Color(1,0.79,0.34))
	_style_primary(continue_btn); root_page.add_child(continue_btn)
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",8); root_page.add_child(row)
	descent_btn=_button("",0,64,17,func(): _show_page(true)); descent_btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(descent_btn)
	daily_btn=_button("",220,64,16,_on_daily); daily_btn.add_theme_color_override("font_color",Color(0.95,0.55,0.4)); row.add_child(daily_btn)
	next_label=_label("",18,Color(0.62,0.55,0.72)); root_page.add_child(next_label)
	var nav:=HBoxContainer.new(); nav.alignment=BoxContainer.ALIGNMENT_CENTER; nav.add_theme_constant_override("separation",8); root_page.add_child(nav)
	for item in [["SURVIVORS",func(): survivors_pressed.emit()],["ARMOURY",func(): weapons_pressed.emit()],["UPGRADES",func(): upgrades_pressed.emit()],["UNLOCKS",func(): unlocks_pressed.emit()]]:
		nav.add_child(_button(item[0],154,72,17,item[1]))
	best_label=_label("",17,Color(0.48,0.5,0.58)); root_page.add_child(best_label)
	play_page=VBoxContainer.new(); play_page.visible=false; play_page.size_flags_vertical=Control.SIZE_EXPAND_FILL
	play_page.alignment=BoxContainer.ALIGNMENT_CENTER; play_page.add_theme_constant_override("separation",14); shell.add_child(play_page)
	play_page.add_child(_label("CHOOSE YOUR DESCENT",40,Color(0.92,0.86,0.72))); play_page.add_child(_stage_picker())
	var enter := _button("ENTER THE ASH",520,88,30,func(): start_pressed.emit()); _style_primary(enter)
	var ec := CenterContainer.new(); ec.add_child(enter); play_page.add_child(ec)
	play_page.add_child(_center_button("BACK TO ALTAR",520,78,25,func(): _show_page(false)))
	_refresh_stages(); _refresh_sound(); _refresh_root()

func _button(text:String,w:float,h:float,fs:int,action:Callable)->Button:
	var b:=Button.new(); b.text=text; b.custom_minimum_size=Vector2(w,h); b.add_theme_font_size_override("font_size",fs); b.pressed.connect(action); return b

# The one button that starts a run is the one that should look pressable.
func _style_primary(b:Button)->void:
	for st in ["normal","hover","pressed","focus"]:
		var s:=StyleBoxFlat.new(); s.set_corner_radius_all(10); s.set_border_width_all(2)
		s.bg_color={"normal":Color(0.16,0.07,0.04),"hover":Color(0.24,0.1,0.05),"pressed":Color(0.32,0.14,0.06),"focus":Color(0.2,0.09,0.05)}[st]
		s.border_color=Color(1,0.62,0.25) if st!="normal" else Color(0.75,0.42,0.18)
		s.shadow_color=Color(1,0.45,0.12,0.35); s.shadow_size=10 if st!="normal" else 6
		b.add_theme_stylebox_override(st,s)
	b.add_theme_color_override("font_color",Color(1,0.82,0.45)); b.add_theme_color_override("font_hover_color",Color(1,0.92,0.7))

func _center_button(text:String,w:float,h:float,fs:int,action:Callable)->Control:
	var c:=CenterContainer.new(); c.add_child(_button(text,w,h,fs,action)); return c

func _on_continue()->void:
	gm.daily=false; start_pressed.emit()

func _on_daily()->void:
	am.play("ui_click",-8); daily_pressed.emit()

func _refresh_root()->void:
	var c:Dictionary=gm.class_by_id(gm.selected_class); hero_name.text=str(c.get("name","WANDERER")).to_upper()
	var w:Dictionary=gm.WEAPONS.get(str(c.get("weapon","")),{}); hero_weapon.text="%s  •  %s"%[w.get("name","UNKNOWN ARM"),c.get("flavor","")]
	portrait.texture=load("res://assets/sprites/player_%s_portrait.png"%gm.selected_class); altar.accent=gm.sigil_color()
	progress_label.text="CAMPAIGN  %s     %s SIGIL"%[gm.campaign_progress(),gm.SIGILS[gm.selected_sigil]["name"]]; shard_label.text="%d SOULS"%gm.shards
	continue_btn.text="BEGIN THE DESCENT" if gm.lifetime_runs==0 else "CONTINUE"
	var sd:Dictionary=gm.STAGES[clampi(gm.selected_stage,0,gm.STAGES.size()-1)]
	descent_btn.text="STAGE %s  •  %s  •  %d MIN   ›"%[_numeral(gm.selected_stage),str(sd["name"]).to_upper(),gm.selected_minutes]
	var db:Dictionary=gm.daily_best_today(); var dt:=int(float(db.get("time",0.0)))
	var ds:Dictionary=gm.STAGES[gm.daily_stage()]
	daily_btn.text="DAILY RITE  •  %s\n%s"%[_numeral(gm.daily_stage()),("TODAY'S BEST %d:%02d"%[dt/60,dt%60]) if not db.is_empty() else str(ds["name"]).to_upper()]
	var a:Dictionary=gm.next_achievement()
	if a.is_empty(): next_label.text="ALL CHALLENGES CONQUERED"
	else:
		var p:Dictionary=gm.achievement_progress(a); next_label.text="NEXT UNLOCK  •  %s  %d/%d"%[a["name"],p["value"],p["goal"]]
	var b:Dictionary=gm.best; var t:=int(float(b.get("time",0)))
	best_label.text="BEST  %d:%02d     %d SLAIN     LEVEL %d     %d VICTORIES"%[t/60,t%60,b.get("kills",0),b.get("level",0),b.get("wins",0)]
	if gm.campaign_crowned: best_label.text += "     CROWNED"

func _stage_picker()->Control:
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",10)
	var modes:=HBoxContainer.new(); modes.alignment=BoxContainer.ALIGNMENT_CENTER
	for mode in [false,true]:
		var b:=_button("CAMPAIGN" if mode else "FREE PLAY",230,64,22,_on_mode.bind(mode)); mode_btns.append(b); modes.add_child(b)
	box.add_child(modes); mode_label=_label("",20,Color(0.62,0.66,0.78)); box.add_child(mode_label)
	var grid:=GridContainer.new(); grid.columns=4
	for i in gm.STAGES.size():
		var b:=_button(_numeral(i),130,68,24,_on_stage.bind(i)); stage_btns.append(b); grid.add_child(b)
	var gc:=CenterContainer.new(); gc.add_child(grid); box.add_child(gc); stage_label=_label("",22,Color(0.68,0.66,0.7)); box.add_child(stage_label)
	var lengths:=HBoxContainer.new(); lengths.alignment=BoxContainer.ALIGNMENT_CENTER
	for minutes in gm.RUN_LENGTHS:
		var b:=_button(str(minutes),100,60,22,_on_length.bind(int(minutes))); length_btns.append(b); lengths.add_child(b)
	box.add_child(lengths); length_label=_label("",20,Color(0.62,0.66,0.78)); box.add_child(length_label); return box

func _on_length(m:int)->void: am.play("ui_click",-8); gm.selected_minutes=m; _refresh_stages()
func _on_stage(i:int)->void:
	if not gm.campaign_stage_open(i): am.play("ui_click",-16); mode_label.text="LOCKED — CLEAR THE PREVIOUS STAGE"; return
	am.play("ui_click",-8); gm.selected_stage=i; _refresh_stages()
func _on_mode(on:bool)->void:
	am.play("ui_click",-8); gm.campaign=on
	if not gm.campaign_stage_open(gm.selected_stage): gm.selected_stage=maxi(0,gm.campaign_unlocked-1)
	_refresh_stages()
func _refresh_stages()->void:
	for i in stage_btns.size():
		var is_open: bool=gm.campaign_stage_open(i); stage_btns[i].text=("[ %s ]"%_numeral(i)) if is_open and i==gm.selected_stage else (_numeral(i) if is_open else "—"); stage_btns[i].disabled=not is_open
	for i in mode_btns.size(): mode_btns[i].add_theme_color_override("font_color",Color(1,0.79,0.34) if (i==1)==gm.campaign else Color(0.55,0.58,0.66))
	mode_label.text=gm.campaign_progress()+(" — PROGRESS SAVED" if gm.campaign else " — ALL STAGES OPEN")
	var sd:Dictionary=gm.STAGES[clampi(gm.selected_stage,0,gm.STAGES.size()-1)]; stage_label.text="%s  —  %s"%[sd["name"],sd["boss_name"]]
	for i in length_btns.size(): length_btns[i].text=("[ %d ]"%gm.RUN_LENGTHS[i]) if gm.RUN_LENGTHS[i]==gm.selected_minutes else str(gm.RUN_LENGTHS[i])
	length_label.text="%d MINUTES  •  %d STAGE%s"%[gm.selected_minutes,gm.stages_in_run(),"" if gm.stages_in_run()==1 else "S"]
func _numeral(i:int)->String:
	const N:=["I","II","III","IV","V","VI","VII","VIII"]; return N[i] if i<N.size() else str(i+1)
func _show_page(play:bool)->void: am.play("ui_click",-8); root_page.visible=not play; play_page.visible=play; _refresh_stages(); _refresh_root()
func _label(text:String,fs:int,color:Color,align:=HORIZONTAL_ALIGNMENT_CENTER)->Label:
	var l:=Label.new(); l.text=text; l.add_theme_font_size_override("font_size",fs); l.add_theme_color_override("font_color",color); l.add_theme_color_override("font_outline_color",Color.BLACK); l.add_theme_constant_override("outline_size",6); l.horizontal_alignment=align; return l
func show_screen()->void: root_page.visible=true; play_page.visible=false; _refresh_root(); _refresh_stages(); _refresh_sound(); visible=true; continue_btn.grab_focus()
func hide_screen()->void: visible=false
func _on_sound()->void: am.toggle_mute(); _refresh_sound(); am.play("ui_click",-8)
func _refresh_sound()->void: sound_btn.text="SOUND OFF" if am.is_muted() else "SOUND ON"
