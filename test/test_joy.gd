extends Node



var _phase := 0
var _wait := 0
var _fails := 0
var _main = null
var _player = null
var _gm = null


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		print("FAIL: ", name)


func _touch(pressed: bool, idx: int, pos: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.pressed = pressed
	t.index = idx
	t.position = pos
	Input.parse_input_event(t)


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = idx
	d.position = pos
	d.relative = rel
	Input.parse_input_event(d)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_main = get_tree().get_first_node_in_group("main")
	_gm = get_node("/root/GameManager")
	_check(_main != null, "main found")
	_main.start_run()
	set_process(true)


func _process(_delta: float) -> void:
	_wait += 1
	match _phase:
		0:
			if _wait > 5:
				_player = _main.player
				_check(_player != null, "player spawned")
				_touch(true, 0, Vector2(300, 600))
				_drag(0, Vector2(420, 600), Vector2(120, 0))
				_phase = 1
				_wait = 0
		1:
			if _wait > 5:
				_check(_player._touch_id == 0, "touch captured id 0")
				_check(_player.move_vec.x > 0.5, "player moving right from drag")

				_gm.pending_levelups = 1
				_gm.level_changed.emit()
				_phase = 2
				_wait = 0
		2:
			if _wait > 5:
				_check(get_tree().paused, "tree paused by level-up modal")

				_touch(false, 0, Vector2(420, 600))
				_check(_player._touch_id == -1, "joystick released on level-up pause")

				_gm.pending_levelups = 0
				_main._on_upgrade_chosen()
				_phase = 3
				_wait = 0
		3:
			if _wait > 8:
				_check(not get_tree().paused, "tree unpaused after choice")
				_check(_player._touch_id == -1, "touch id still clear after resume")
				_check(_player.move_vec.length() < 0.01, "player not drifting after resume")

				_touch(true, 1, Vector2(300, 600))
				_drag(1, Vector2(300, 480), Vector2(0, -120))
				_phase = 4
				_wait = 0
		4:
			if _wait > 5:
				_check(_player.move_vec.y < -0.5, "player moving up from drag")
				_main._on_pause_button()
				_phase = 5
				_wait = 0
		5:
			if _wait > 5:
				_check(get_tree().paused, "tree paused by pause menu")
				_touch(false, 1, Vector2(300, 480))
				_check(_player._touch_id == -1, "joystick released on pause menu")
				_main._on_resume()
				_phase = 6
				_wait = 0
		6:
			if _wait > 8:
				_check(_player.move_vec.length() < 0.01, "player not drifting after pause resume")

				_touch(true, 2, Vector2(300, 600))
				_drag(2, Vector2(200, 600), Vector2(-100, 0))
				_phase = 7
				_wait = 0
		7:
			if _wait > 5:
				_touch(false, 2, Vector2(200, 600))
				_phase = 8
				_wait = 0
		8:
			if _wait > 5:
				_check(_player._touch_id == -1, "normal touch release clears joystick")
				_check(_player.move_vec.length() < 0.01, "player stopped after normal release")

				_touch(true, 5, Vector2(300, 600))
				_drag(5, Vector2(420, 600), Vector2(120, 0))
				_phase = 9
				_wait = 0
		9:
			if _wait > 5:
				_check(_player._touch_id == 5, "stuck touch captured")

				_player._touch_last_msec = Time.get_ticks_msec() - 10000
				_touch(true, 6, Vector2(300, 600))
				_phase = 10
				_wait = 0
		10:
			if _wait > 3:
				_check(_player._touch_id == 6, "stale stuck touch stolen by fresh press")
				_drag(6, Vector2(180, 600), Vector2(-120, 0))
				_phase = 11
				_wait = 0
		11:
			if _wait > 5:
				_check(_player.move_vec.x < -0.5, "recovered joystick steers again")

				_touch(true, 7, Vector2(600, 600))
				_phase = 12
				_wait = 0
		12:
			if _wait > 3:
				_check(_player._touch_id == 6, "active touch not hijacked by second finger")
				_touch(false, 7, Vector2(600, 600))
				_touch(false, 6, Vector2(180, 600))

				_touch(true, 8, Vector2(300, 600))
				_drag(8, Vector2(420, 600), Vector2(120, 0))
				_phase = 13
				_wait = 0
		13:
			if _wait > 5:
				_player.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
				_phase = 14
				_wait = 0
		14:
			if _wait > 3:
				_check(_player._touch_id == -1, "focus loss releases joystick")
				_check(_player.move_vec.length() < 0.01, "no drift after focus loss")
				print("RESULT: ", "ALL PASS" if _fails == 0 else str(_fails) + " FAILURES")
				get_tree().quit(1 if _fails > 0 else 0)
