extends Node
# Visual probe, not a test: captures the companion, missions, stage layouts
# and new screens to /tmp/gs_feat_*.png. Autoload it and run with a display.

var _main = null
var _gm = null


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("/tmp/gs_feat_%s.png" % name)
	print("SHOT ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _run_on(stage: int) -> void:
	_gm.selected_stage = stage
	_gm.daily = false
	_main.start_run()
	await _wait(0.6)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	get_tree().root.size = Vector2i(720, 1280)
	_main = get_tree().get_first_node_in_group("main")
	_gm = get_node("/root/GameManager")
	_gm.lifetime_runs = maxi(_gm.lifetime_runs, 1)
	await _wait(1.0)
	_main._on_pacts_open()
	await _wait(0.5)
	await _shot("pacts")
	_main._on_pacts_closed()
	_main._on_upgrades_open()
	await _wait(0.4)
	await _shot("upgrades")
	_main._on_upgrades_closed()
	await _shot("title")
	for i in 4:
		_gm.selected_companion = ["hound", "archer", "wisp", "knight"][i]
		await _run_on(0)
		Input.action_press("ui_up")
		await _wait(1.2)
		Input.action_release("ui_up")
		_main.summon.cooldown_left = 0.0
		_main.summon.try_summon()
		await _wait(2.5)
		await _shot("companion_" + _gm.selected_companion)
	_main.director.missions.start("totems")
	await _wait(1.0)
	await _shot("mission_totems")
	_main.director.missions._finish(_main.director.missions.current.get("obj"), false)
	_main.director.missions.start("thief")
	await _wait(1.5)
	await _shot("mission_thief")
	_main.director.missions._finish(_main.director.missions.current.get("obj"), false)
	_main.director.missions.start("hold")
	await _wait(0.5)
	await _shot("mission_hold")
	_main.director.missions.start_surge(60.0)
	await _wait(2.5)
	await _shot("surge")
	_gm.pending_levelups = 1
	_gm.pact_level = 0
	_gm.rerolls_left = 2
	_main._on_level_changed()
	await _wait(0.5)
	await _shot("levelup")
	_main.levelup_ui.hide_screen()
	get_tree().paused = false
	_gm.state = _gm.State.RUNNING
	for st in [2, 4, 6]:
		await _run_on(st)
		var cam = get_tree().get_first_node_in_group("shake_camera")
		if cam:
			cam.zoom = Vector2(0.42, 0.42)
		await _wait(1.0)
		await _shot("layout_%d" % st)
		if cam:
			cam.zoom = Vector2.ONE
	get_tree().quit(0)
