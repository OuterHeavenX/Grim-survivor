extends CanvasLayer
# Accessibility and comfort settings. Big buttons for touch; each grabs focus
# so a controller or keyboard can move through them with the ui_* actions.

signal closed

var gm = null
var buttons := {}
var _first: Button = null

# key, label, kind (toggle | cycle), cycle values
const ROWS := [
	["shake", "SCREEN SHAKE", "cycle", [1.0, 0.5, 0.0]],
	["flashes", "FLASHES", "toggle", []],
	["damage_numbers", "DAMAGE NUMBERS", "toggle", []],
	["hazard_opacity", "HAZARD OPACITY", "cycle", [1.0, 1.3, 0.7]],
	["high_contrast", "HIGH-CONTRAST WARNINGS", "toggle", []],
	["reduced_effects", "REDUCED EFFECTS", "toggle", []],
]


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	gm = get_node("/root/GameManager")
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	for row in ROWS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(560, 80)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_on_row.bind(row))
		vb.add_child(b)
		buttons[row[0]] = b
		if _first == null:
			_first = b

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(560, 84)
	back.add_theme_font_size_override("font_size", 30)
	back.pressed.connect(func() -> void: closed.emit())
	vb.add_child(back)
	refresh()


func _on_row(row: Array) -> void:
	var key: String = row[0]
	if row[2] == "toggle":
		gm.set_setting(key, not bool(gm.setting(key)))
	else:
		var vals: Array = row[3]
		var cur := float(gm.setting(key))
		var idx := 0
		for i in vals.size():
			if is_equal_approx(float(vals[i]), cur):
				idx = i
		gm.set_setting(key, float(vals[(idx + 1) % vals.size()]))
	refresh()


func value_text(key: String) -> String:
	var v = gm.setting(key)
	if typeof(v) == TYPE_BOOL:
		return "ON" if v else "OFF"
	return "%d%%" % int(round(float(v) * 100.0))


func refresh() -> void:
	for row in ROWS:
		var b: Button = buttons[row[0]]
		b.text = "%s:  %s" % [row[1], value_text(row[0])]


func show_screen() -> void:
	refresh()
	visible = true
	if _first:
		_first.grab_focus()


func hide_screen() -> void:
	visible = false
