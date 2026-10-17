extends Node
# A safety net for stuck runs. A few combinations of state can leave a run
# looking frozen (dead player with no end screen, a pause with no menu,
# slow motion that never lifts) if anything upstream ever goes wrong. This
# checks twice a second, waits out a short grace period so ordinary
# transitions are never touched, and puts the game back on its feet.
# Every recovery is logged, so a report from the field names the state.

const GRACE := 1.0
const CHECK_EVERY := 0.5

var main = null
var gm = null
var recoveries := 0
var _since := {}
var _check := 0.0


func setup(p_main) -> void:
	main = p_main
	gm = main.gm
	name = "Watchdog"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	# Real time, not game time: slow motion is one of the things it watches.
	var real := delta / maxf(Engine.time_scale, 0.001)
	_check -= real
	if _check > 0.0:
		return
	_check = CHECK_EVERY
	_watch("slowmo", Engine.time_scale < 0.99 and not main.jm.is_hitstop(), CHECK_EVERY, _fix_slowmo)
	if main.run == null or not is_instance_valid(main.run):
		_since.clear()
		return
	var p = main.player
	var dead: bool = p != null and is_instance_valid(p) and not bool(p.get("alive"))
	var ended: bool = gm.state == gm.State.GAMEOVER or gm.state == gm.State.VICTORY
	_watch("dead_no_end", dead and not ended, CHECK_EVERY, _fix_dead)
	_watch("ended_hidden", ended and not main.end_screen.visible, CHECK_EVERY, _fix_end_screen)
	var modal: bool = main.levelup_ui.visible or main.loot_ui.visible or main.pause_menu.visible \
		or main.end_screen.visible or main.settings_ui.visible
	_watch("paused_no_menu", get_tree().paused and not modal, CHECK_EVERY, _fix_unpause)
	_watch("levelup_hidden", gm.state == gm.State.LEVELUP and not main.levelup_ui.visible, CHECK_EVERY, _fix_levelup)
	_watch("chest_hidden", gm.state == gm.State.CHEST and not main.loot_ui.visible, CHECK_EVERY, _fix_unpause)


func _watch(key: String, bad: bool, step: float, fix: Callable) -> void:
	if not bad:
		_since.erase(key)
		return
	_since[key] = float(_since.get(key, 0.0)) + step
	if float(_since[key]) >= GRACE:
		_since.erase(key)
		recoveries += 1
		push_warning("Watchdog recovered from '%s' (state %d, stage %d, t %.1f)" % [key, gm.state, gm.stage, gm.run_time])
		if gm.run_stats:
			gm.run_stats.log_event("watchdog %s" % key)
			if not gm.run_stats.recoveries.has(key):
				gm.run_stats.recoveries.append(key)
		fix.call()


func _fix_slowmo() -> void:
	Engine.time_scale = 1.0


func _fix_dead() -> void:
	main.levelup_ui.hide_screen()
	main.loot_ui.hide_screen()
	main.pause_menu.hide_screen()
	gm.state = gm.State.RUNNING
	gm.end_run(false)


func _fix_end_screen() -> void:
	main._on_run_ended(gm.state == gm.State.VICTORY)


func _fix_unpause() -> void:
	get_tree().paused = false
	main.am.duck(false)
	if gm.state != gm.State.GAMEOVER and gm.state != gm.State.VICTORY:
		gm.state = gm.State.RUNNING


func _fix_levelup() -> void:
	if gm.pending_levelups > 0:
		get_tree().paused = true
		main.levelup_ui.show_screen(gm.roll_upgrades())
	else:
		_fix_unpause()
