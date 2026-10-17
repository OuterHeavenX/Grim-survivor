extends Node
# Soak probe, not a test: plays real runs at speed through stage clears,
# victories and deaths with a bot, printing a heartbeat. A hang shows as the
# heartbeat stopping; the last MARK names where. Restores the save file.
#
#   add Probe="*res://test/soak.gd" under [autoload], run --headless

var _m = null
var _gm = null
var _beat := 0.0
var _phase := ""
var _ang := 0.0


func _mark(s: String) -> void:
	_phase = s
	print("MARK ", s, " t=", snappedf(_gm.run_time, 0.1), " stage=", _gm.stage, " enemies=", _m._enemy_count())


func _process(delta: float) -> void:
	if _gm == null:
		return
	_beat += delta / maxf(Engine.time_scale, 0.01)
	if _beat > 2.0:
		_beat = 0.0
		print("BEAT ", _phase, " state=", _gm.state, " t=", snappedf(_gm.run_time, 0.1), " lvl=", _gm.level)
	# Bot: answer every menu, walk in a circle, summon when ready.
	if _gm.state == _gm.State.LEVELUP and _m.levelup_ui.visible and not _m.levelup_ui.buttons.is_empty():
		var b = _m.levelup_ui.buttons[randi() % _m.levelup_ui.buttons.size()]
		if is_instance_valid(b):
			b.pressed.emit()
	if _m.loot_ui.visible:
		for c in _m.loot_ui.find_children("*", "Button", true, false):
			if c.visible and not c.disabled:
				c.pressed.emit()
				break
	if _gm.state == _gm.State.RUNNING and _m.player and is_instance_valid(_m.player):
		_ang += delta * 0.8
		var p = _m.player
		p.global_position = _m.clamp_arena(p.global_position + Vector2.from_angle(_ang) * 240.0 * delta, 60.0)
		if _m.summon and is_instance_valid(_m.summon) and _m.summon.is_ready():
			_m.summon.try_summon()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_m = get_tree().get_first_node_in_group("main")
	_gm = get_node("/root/GameManager")
	var save := "user://grim_survivors.cfg"
	var backup := FileAccess.get_file_as_string(save) if FileAccess.file_exists(save) else ""
	_gm.achievements["first_victory"] = true
	_gm.achievements["oathkeeper"] = true
	_gm.companions_unlocked = {"hound": true, "archer": true}
	var classes := ["rogue", "dancer", "reaper", "warden", "pyro", "storm", "plague", "ravenmark"]
	var comps := ["hound", "archer", "wisp", "knight"]
	for i in 8:
		_gm.selected_stage = i
		_gm.selected_minutes = 10
		_gm.unlocked[classes[i]] = 1
		_gm.selected_class = classes[i]
		_gm.selected_companion = comps[i % 4]
		_mark("start %d %s %s" % [i, classes[i], comps[i % 4]])
		_m.start_run()
		Engine.time_scale = 6.0
		await _play_stage(true)
		_mark("cleared, next stage")
		await _play_stage(false)
		_mark("dying")
		Engine.time_scale = 1.0
		await _die()
		_mark("dead end=%s" % _m.end_screen.visible)
		await _wait(0.5)
		_mark("restart from end screen")
		_m.end_screen._restart_btn.pressed.emit()
		Engine.time_scale = 6.0
		await _wait(3.0)
		_gm.run_time = _gm.RUN_DURATION - 1.0
		await _kill_boss()
		_mark("victory or advance end=%s" % _m.end_screen.visible)
		Engine.time_scale = 1.0
		_m.show_title()
		await _wait(0.3)
	print("SOAK DONE")
	if backup != "":
		FileAccess.open(save, FileAccess.WRITE).store_string(backup)
	elif FileAccess.file_exists(save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	get_tree().quit()


func _play_stage(kill_boss: bool) -> void:
	var start_stage: int = _gm.stage
	while _gm.state != _gm.State.GAMEOVER and _gm.run_time < _gm.RUN_DURATION + 1.0 and _gm.stage == start_stage:
		if _m.player and is_instance_valid(_m.player):
			_m.player.hp = _m.player.max_hp
		await _wait(0.25)
	if kill_boss:
		await _kill_boss()


func _kill_boss() -> void:
	for i in 200:
		if _gm.state == _gm.State.GAMEOVER or _gm.state == _gm.State.VICTORY:
			return
		if _m.player and is_instance_valid(_m.player):
			_m.player.hp = _m.player.max_hp
		var b = _m.boss
		if b and is_instance_valid(b) and not b.dead:
			b.take_damage(b.max_hp * 0.2, b.global_position, 0.0, "dagger")
		elif not _gm.boss_alive and _gm.boss_spawned:
			return
		await _wait(0.1)


func _die() -> void:
	for i in 100:
		if _gm.state == _gm.State.GAMEOVER:
			return
		if _m.player and is_instance_valid(_m.player) and _m.player.alive:
			_m.player.take_damage(99999.0, "soak")
		await _wait(0.1)
