extends Node
# Visual probe, not a test: captures the title altar, the opening seconds of a
# run and the end screen to /tmp/gs_flow_*.png. Run with a display:
#   add Probe="*res://test/shot_flow.gd" under [autoload], run without --headless

var _main = null
var _gm = null


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.save_png("/tmp/gs_flow_%s.png" % name)
	print("SHOT ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	get_tree().root.size = Vector2i(720, 1280)
	_main = get_tree().get_first_node_in_group("main")
	_gm = get_node("/root/GameManager")
	await _wait(1.5)
	await _shot("title")
	_main.title_screen._show_page(true)
	await _wait(0.4)
	await _shot("descent")
	_main.title_screen._show_page(false)
	_main._on_start()
	await _wait(0.4)
	await _shot("survivors")
	_main.start_run()
	Input.action_press("ui_left")
	await _wait(1.0)
	await _shot("run_1s")
	await _wait(4.0)
	Input.action_release("ui_left")
	await _shot("run_5s")
	await _wait(6.0)
	await _shot("run_11s")
	_gm.end_run(false)
	await _wait(0.6)
	await _shot("end")
	get_tree().quit(0)
