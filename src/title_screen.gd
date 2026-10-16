extends CanvasLayer

signal start_pressed
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
var hero_panel: PanelContainer
var hero_name: Label
var hero_weapon: Label
var progress_label: Label
var next_label: Label
var shard_label: Label
var best_label: Label
var sound_btn: Button
var continue_btn: Button
var stage_label: Label
var length_label: Label
var mode_label: Label
var stage_btns: Array[Button] = []
var length_btns: Array[Button] = []
var mode_btns: Array[Button] = []

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
	var top := HBoxContainer.new(); shell.add_child(top)
	var brand := VBoxContainer.new(); brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(brand)
	brand.add_child(_label("GRIM SURVIVORS", 38, Color(0.92,0.89,0.82), HORIZONTAL_ALIGNMENT_LEFT))
	brand.add_child(_label("THE ASHEN ALTAR", 18, Color(0.62,0.56,0.5), HORIZONTAL_ALIGNMENT_LEFT))
	shard_label = _label("",22,Color(0.78,0.48,1)); shard_label.custom_minimum_size=Vector2(90,60); top.add_child(shard_label)
	sound_btn = _button("",86,60,14,_on_sound); top.add_child(sound_btn)
	top.add_child(_button("SET",72,60,14,func(): settings_pressed.emit()))
	root_page=VBoxContainer.new(); root_page.size_flags_vertical=Control.SIZE_EXPAND_FILL; root_page.add_theme_constant_override("separation",8); shell.add_child(root_page)
	progress_label=_label("",22,Color(0.88,0.7,0.36)); root_page.add_child(progress_label)
	hero_panel=PanelContainer.new(); hero_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL; root_page.add_child(hero_panel)
	var hero:=VBoxContainer.new(); hero.alignment=BoxContainer.ALIGNMENT_CENTER; hero_panel.add_child(hero)
	hero.add_child(_label("SELECTED SURVIVOR",18,Color(0.55,0.57,0.65)))
	var pc:=CenterContainer.new(); portrait=TextureRect.new(); portrait.custom_minimum_size=Vector2(300,300)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pc.add_child(portrait); hero.add_child(pc)
	hero_name=_label("",36,Color(0.94,0.9,0.8)); hero.add_child(hero_name)
	hero_weapon=_label("",19,Color(0.65,0.62,0.68)); hero.add_child(hero_weapon)
	continue_btn=_button("CONTINUE",0,92,35,func(): _show_page(true)); continue_btn.add_theme_color_override("font_color",Color(1,0.79,0.34)); root_page.add_child(continue_btn)
	next_label=_label("",18,Color(0.62,0.55,0.72)); root_page.add_child(next_label)
	var nav:=HBoxContainer.new(); nav.alignment=BoxContainer.ALIGNMENT_CENTER; nav.add_theme_constant_override("separation",8); root_page.add_child(nav)
	for item in [["SURVIVORS",func(): survivors_pressed.emit()],["ARMOURY",func(): weapons_pressed.emit()],["UPGRADES",func(): upgrades_pressed.emit()],["UNLOCKS",func(): unlocks_pressed.emit()]]:
		nav.add_child(_button(item[0],154,72,17,item[1]))
	best_label=_label("",17,Color(0.48,0.5,0.58)); root_page.add_child(best_label)
	play_page=VBoxContainer.new(); play_page.visible=false; play_page.size_flags_vertical=Control.SIZE_EXPAND_FILL
	play_page.alignment=BoxContainer.ALIGNMENT_CENTER; play_page.add_theme_constant_override("separation",14); shell.add_child(play_page)
	play_page.add_child(_label("CHOOSE YOUR DESCENT",40,Color(0.92,0.86,0.72))); play_page.add_child(_stage_picker())
	play_page.add_child(_center_button("ENTER THE ASH",520,88,30,func(): start_pressed.emit()))
	play_page.add_child(_center_button("BACK TO ALTAR",520,78,25,func(): _show_page(false)))
	_refresh_stages(); _refresh_sound(); _refresh_root()

func _button(text:String,w:float,h:float,fs:int,action:Callable)->Button:
	var b:=Button.new(); b.text=text; b.custom_minimum_size=Vector2(w,h); b.add_theme_font_size_override("font_size",fs); b.pressed.connect(action); return b

func _center_button(text:String,w:float,h:float,fs:int,action:Callable)->Control:
	var c:=CenterContainer.new(); c.add_child(_button(text,w,h,fs,action)); return c

func _style(color:Color)->StyleBoxFlat:
	var s:=StyleBoxFlat.new(); s.bg_color=Color(0.035,0.038,0.06,0.94); s.border_color=color; s.set_border_width_all(3); s.set_corner_radius_all(12)
	s.content_margin_left=12; s.content_margin_right=12; s.content_margin_top=12; s.content_margin_bottom=12; return s

func _refresh_root()->void:
	var c:Dictionary=gm.class_by_id(gm.selected_class); hero_name.text=str(c.get("name","WANDERER")).to_upper()
	var w:Dictionary=gm.WEAPONS.get(str(c.get("weapon","")),{}); hero_weapon.text="%s  •  %s"%[w.get("name","UNKNOWN ARM"),c.get("flavor","")]
	portrait.texture=load("res://assets/sprites/player_%s_portrait.png"%gm.selected_class); hero_panel.add_theme_stylebox_override("panel",_style(gm.sigil_color()))
	progress_label.text="CAMPAIGN  %s     %s SIGIL"%[gm.campaign_progress(),gm.SIGILS[gm.selected_sigil]["name"]]; shard_label.text="%d SOULS"%gm.shards
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
func _show_page(play:bool)->void: am.play("ui_click",-8); root_page.visible=not play; play_page.visible=play; _refresh_stages()
func _label(text:String,fs:int,color:Color,align:=HORIZONTAL_ALIGNMENT_CENTER)->Label:
	var l:=Label.new(); l.text=text; l.add_theme_font_size_override("font_size",fs); l.add_theme_color_override("font_color",color); l.add_theme_color_override("font_outline_color",Color.BLACK); l.add_theme_constant_override("outline_size",6); l.horizontal_alignment=align; return l
func show_screen()->void: root_page.visible=true; play_page.visible=false; _refresh_root(); _refresh_stages(); _refresh_sound(); visible=true; continue_btn.grab_focus()
func hide_screen()->void: visible=false
func _on_sound()->void: am.toggle_mute(); _refresh_sound(); am.play("ui_click",-8)
func _refresh_sound()->void: sound_btn.text="SOUND OFF" if am.is_muted() else "SOUND ON"
