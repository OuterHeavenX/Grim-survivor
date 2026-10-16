extends Node
# End to end: a 30-minute campaign run from the Throne of Cinders through the
# Last Bastion. Every stage plays its timeline (time is advanced in jumps but
# the game runs between them), every boss spawns and falls, every altar is
# taken, and the run ends in victory, campaign completion, a saved crown and
# a clean return to the title. Restores the save file afterwards.

const SAVE := "user://grim_survivors.cfg"

var _fails := 0
var _gm = null
var _main = null
var _snapshot := PackedByteArray()
var _had_save := false


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		print("FAIL: ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_gm = get_node("/root/GameManager")
	_main = get_tree().get_first_node_in_group("main")
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save:
		_snapshot = FileAccess.get_file_as_bytes(SAVE)
	var crowned0: bool = _gm.campaign_crowned
	_gm.campaign = true
	_gm.campaign_unlocked = 8
	_gm.campaign_crowned = false
	_gm.relics_discovered.erase("sovereign_seal")
	_gm.selected_minutes = 30
	_gm.selected_stage = 2
	_gm.forced_seed = 31337
	_check(_gm.stages_in_run() == 6, "a 30-minute run is six stages")
	_main.start_run()
	await _frames(3)
	var order := [2, 3, 4, 5, 6, 7]
	for i in order.size():
		await _play_stage(order[i], i == order.size() - 1)
	await _finish(crowned0)
	_restore()
	print("RUN TEST DONE fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _keep_alive() -> void:
	var p = _main.player
	if p and is_instance_valid(p):
		p.max_hp = 100000000.0
		p.hp = p.max_hp


func _play_stage(idx: int, last: bool) -> void:
	_check(_gm.stage == idx, "run: stage %d reached" % (idx + 1))
	_check(_main.director != null and _main.director.stage_index == idx, "run: stage %d director" % (idx + 1))
	_keep_alive()
	# Take the altar left by the previous boss, if any.
	var altars := get_tree().get_nodes_in_group("relic_altars")
	if _gm.stages_cleared > 0:
		_check(altars.size() == 1, "run: an altar waits in stage %d" % (idx + 1))
		_main.player.global_position = altars[0].global_position
		await _frames(3)
		if _gm.state == _gm.State.CHEST:
			(_main.loot_ui.panel.get_child(0) as Button).pressed.emit()
			await _frames(2)
		_check(_gm.state == _gm.State.RUNNING, "run: altar choice resumes play")
	var d = _main.director
	var t := 10.0
	while t < 295.0:
		_gm.run_time = t
		_main.intermission = 0.0
		_keep_alive()
		await _frames(6)
		t += 25.0
	if d and d.stage_data:
		for item in d.stage_data.events:
			_check(d.has_fired(String(item.id)), "run: stage %d event %s fired" % [idx + 1, item.id])
	_check(get_tree().get_nodes_in_group("hazards").size() <= _main.MAX_HAZARDS + 1, "run: hazard cap holds in stage %d" % (idx + 1))
	_check(_main._enemy_count() <= _main.MAX_ENEMIES + 6, "run: enemy cap holds in stage %d" % (idx + 1))
	_gm.run_time = _gm.RUN_DURATION - 0.05
	await _frames(4)
	_check(_gm.boss_spawned and _main.boss != null, "run: stage %d boss arrives on time" % (idx + 1))
	_keep_alive()
	await _frames(30)
	var b = _main.boss
	b.hp = 1.0
	b.take_damage(9999999999.0, b.global_position, 0.0, "dagger")
	await _frames(3)
	if not last:
		_check(_gm.state == _gm.State.RUNNING, "run: stage %d boss advances the run" % (idx + 1))


func _finish(crowned0: bool) -> void:
	_check(_gm.state == _gm.State.VICTORY, "run: victory after the Ashen Sovereign")
	_check(_main.end_screen.visible, "run: victory screen")
	var s: RunStats = _gm.run_stats
	_check(s.stages_cleared == 6 and s.victory, "report: six stages cleared")
	_check(s.run_seed == 31337, "report: seed recorded")
	_check(s.bosses_killed == 6, "report: six bosses killed")
	var timed := 0
	for st in s.stages:
		if float(st.get("boss_time", -1.0)) >= 0.0:
			timed += 1
	_check(timed == 6, "report: boss time per stage")
	_check(s.total_damage() > 0.0 and s.damage_by_source.has("dagger"), "report: damage by weapon")
	_check(s.relics.size() == 5, "report: five altar relics recorded")
	_check(is_equal_approx(s.completion_time, 1800.0), "report: completion time")
	var txt: String = _main.end_screen.report_label.text
	_check(txt.contains("RUN SEED 31337"), "report: shown on the end screen")
	_check(txt.contains("RELICS") and txt.contains("BOSS TIME") and txt.contains("DAMAGE"), "report: sections present")
	for line in txt.split("\n"):
		_check(line.length() <= 140, "report: line fits a phone (%d)" % line.length())
	_check(_gm.campaign_crowned, "campaign: crowned")
	_check(_gm.is_relic_discovered("sovereign_seal"), "campaign: the legendary relic is unlocked")
	_check(_gm.last_banked >= 100, "campaign: substantial shards banked (%d)" % _gm.last_banked)
	_gm.campaign_crowned = false
	_gm.load_meta()
	_check(_gm.campaign_crowned, "campaign: the crown is saved")
	_main.show_title()
	await _frames(2)
	_check(_gm.state == _gm.State.TITLE and _main.run == null, "title: run torn down")
	_check(_main.title_screen.visible, "title: title screen shown")
	_check(_main.title_screen.best_label.text.contains("CROWNED"), "title: crown marker shown")
	_check(get_tree().get_nodes_in_group("hazards").filter(func(h): return not h.is_queued_for_deletion()).is_empty(), "title: no hazards left")
	_check(_gm.mods.sources().is_empty(), "title: no run modifiers left")


func _restore() -> void:
	_gm.forced_seed = -1
	if _had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(_snapshot)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_gm.load_meta()
	_gm.load_best()
	_gm.load_settings()
