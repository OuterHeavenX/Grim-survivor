extends Node




var _phase := 0
var _wait := 0
var _fails := 0
var _main = null
var _gm = null
var _meta_before := 0
var _shards_before := 0
var _cost_before := 0

const TOFU := ["◆", "●", "○", "→"]


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		print("FAIL: ", name)


func _walk(n: Node, bad: Array) -> void:
	var txt := ""
	if n is Label:
		txt = (n as Label).text
	elif n is Button:
		txt = (n as Button).text
	for g in TOFU:
		if g in txt:
			bad.append(txt)
	for c in n.get_children():
		_walk(c, bad)


func _panels(n: Node, out: Array) -> void:
	if n is PanelContainer:
		out.append(n)
	for c in n.get_children():
		_panels(c, out)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_main = get_tree().get_first_node_in_group("main")
	_gm = get_node("/root/GameManager")

	get_tree().root.size = Vector2i(720, 1280)
	await get_tree().process_frame
	await get_tree().process_frame
	_gm.shards = 500
	_main._on_upgrades_open()
	set_process(true)


func _process(_delta: float) -> void:
	_wait += 1
	match _phase:
		0:
			if _wait > 10:
				var ui = _main.upgrades_ui
				_check(ui.visible, "upgrades screen visible")
				var bad: Array = []
				_walk(ui, bad)
				_check(bad.is_empty(), "no tofu glyphs in upgrades UI")
				var panels: Array = []
				_panels(ui, panels)
				_check(panels.size() == 6, "six track cards built")
				var ok := true
				for p in panels:
					if (p as PanelContainer).size.x > 680.0:
						ok = false
						print("wide panel: ", (p as PanelContainer).size.x)
				_check(ok, "all track cards fit viewport width")
				var bad2: Array = []
				_walk(_main.title_screen, bad2)
				_check(bad2.is_empty(), "no tofu glyphs in title screen")
				_main.end_screen.show_screen(false, 61.0, 10, 3, 7)
				_phase = 1
				_wait = 0
		1:
			if _wait > 5:
				var bad3: Array = []
				_walk(_main.end_screen, bad3)
				_check(bad3.is_empty(), "no tofu glyphs in end screen")
				_main.end_screen.hide_screen()
				var ui2 = _main.upgrades_ui
				_gm.meta["edge"] = 0
				_gm.shards = 500
				ui2.refresh()
				_meta_before = 0
				_shards_before = 500
				_cost_before = _gm.track_cost("edge")
				var btn: Button = ui2.rows["edge"]["buy"]
				_check(not btn.disabled, "buy button enabled with shards")
				_check(btn.icon != null, "buy button has shard icon")
				btn.pressed.emit()
				_phase = 2
				_wait = 0
		2:
			if _wait > 5:
				var ui3 = _main.upgrades_ui
				_check(_gm.meta_rank("edge") == _meta_before + 1, "rank increased after buy")
				_check((ui3.rows["edge"]["pips"] as UIBits.PipsRow).rank == _meta_before + 1, "pips show new rank")
				_check(_gm.shards == _shards_before - _cost_before, "shards deducted")
				var bonus: String = (ui3.rows["edge"]["bonus"] as Label).text
				_check("Next:" in bonus, "next-rank preview shown")
				print("RESULT: ", "ALL PASS" if _fails == 0 else str(_fails) + " FAILURES")
				get_tree().quit(1 if _fails > 0 else 0)
