extends Node
# Freezes and stuck states: the blade/scythe sync loop, menus resuming a
# finished run, the end screen's ordering, and the watchdog's recoveries.

var _fails := 0
var _gm = null
var _main = null


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		print("FAIL: ", name)


func _real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_gm = get_node("/root/GameManager")
	_main = get_tree().get_first_node_in_group("main")
	await _weapon_sync()
	await _menus_after_end()
	await _watchdog()
	_main.show_title()
	print("RECOVERY TEST DONE fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _start() -> void:
	_gm.selected_stage = 0
	_gm.selected_minutes = 5
	_gm.daily = false
	_main.start_run()
	await _real(0.2)
	_main.intermission = 99999.0
	_main.player.max_hp = 1e9
	_main.player.hp = 1e9


func _weapon_sync() -> void:
	await _start()
	var wn = _main.player.weapons_node
	_gm.weapons = {"blades": 4, "scythe": 3}
	_gm.weapons_changed.emit()
	_check(wn.blades_root.get_child_count() == 5 and wn.scythe_root.get_child_count() == 1, "weapons: blades and scythe sync up")
	# Shrinking used to spin forever: queue_free() leaves the child count
	# unchanged until the frame ends.
	_gm.weapons = {"dagger": 1}
	_gm.weapons_changed.emit()
	_check(wn.blades_root.get_child_count() == 0 and wn.scythe_root.get_child_count() == 0, "weapons: shrinking returns at once")
	_main.show_title()


func _menus_after_end() -> void:
	# A level-up and a death in the same frame.
	await _start()
	_gm.pending_levelups = 1
	_main._on_level_changed()
	_check(_gm.state == _gm.State.LEVELUP and _main.levelup_ui.visible, "menus: level-up open")
	_gm.end_run(false)
	_check(_main.end_screen.visible and not _main.levelup_ui.visible, "menus: the end screen replaces the level-up")
	_main._on_upgrade_chosen()
	_check(_gm.state == _gm.State.GAMEOVER and get_tree().paused, "menus: a late upgrade pick cannot resume a finished run")
	_main.show_title()
	# A chest and a victory together.
	await _start()
	_gm.state = _gm.State.CHEST
	get_tree().paused = true
	_main.loot_ui.show_screen([{"kind": "heal", "name": "x", "desc": "y"}])
	_gm.end_run(true)
	_main._on_loot_chosen({"kind": "heal"})
	_check(_gm.state == _gm.State.VICTORY and get_tree().paused and _main.end_screen.visible, "menus: a late loot pick cannot resume a won run")
	_main.show_title()


func _watchdog() -> void:
	var wd = _main.watchdog
	_check(wd != null, "watchdog: present")
	# Dead player, no end screen.
	await _start()
	var r0: int = wd.recoveries
	_main.player.alive = false
	await _real(2.0)
	_check(_main.end_screen.visible and _gm.state == _gm.State.GAMEOVER and wd.recoveries > r0, "watchdog: a dead player always gets the end screen")
	_check(_main.end_screen.report_label.text.contains("SAFETY NET  DEAD_NO_END"), "watchdog: the end screen names the recovery")
	_main.show_title()
	# Run over but the end screen hidden.
	await _start()
	_gm.end_run(true)
	_main.end_screen.hide_screen()
	await _real(2.0)
	_check(_main.end_screen.visible, "watchdog: an ended run always shows its end screen")
	_main.show_title()
	# A pause with no menu.
	await _start()
	get_tree().paused = true
	await _real(2.0)
	_check(not get_tree().paused and _gm.state == _gm.State.RUNNING, "watchdog: a pause with nothing open is lifted")
	# Slow motion that never lifts.
	Engine.time_scale = 0.05
	await _real(2.0)
	_check(is_equal_approx(Engine.time_scale, 1.0), "watchdog: stuck slow motion is restored")
	# Ordinary menus are left alone.
	_gm.pending_levelups = 1
	_main._on_level_changed()
	var r1: int = wd.recoveries
	await _real(2.5)
	_check(_main.levelup_ui.visible and get_tree().paused and wd.recoveries == r1, "watchdog: an open level-up is not touched")
	_main.show_title()
	await _real(0.2)
	_check(not get_tree().paused, "watchdog: title is unpaused")
