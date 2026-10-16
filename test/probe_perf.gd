extends Node
# Probe, not a test: measures the script-side cost of a worst-case late
# encounter (the enemy cap, the Ashen Sovereign casting back to back, a full
# stage rule) by timing physics frames. Headless runs skip rendering, so this
# bounds CPU work only; it says nothing about GPU or web performance.
#
#   godot --headless --path . (with this autoloaded as TestRunner)

var _gm = null
var _main = null
var _frames := 0
var _times: Array = []
var _last := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_gm = get_node("/root/GameManager")
	_main = get_tree().get_first_node_in_group("main")
	# Rotgrove (index 4) has no stage rule and a legacy boss: the baseline.
	for idx in [4, 0, 1, 2, 3, 5, 6, 7]:
		await _measure(idx)
	get_tree().quit(0)


func _measure(idx: int) -> void:
	_gm.selected_minutes = 30
	_gm.selected_stage = idx
	_main.start_run()
	await get_tree().physics_frame
	_main.intermission = 0.0
	var p = _main.player
	p.max_hp = 1.0e9
	p.hp = p.max_hp
	_gm.weapons = {"dagger": 5, "blades": 5, "lightning": 5, "miasma": 5}
	_gm.weapons_changed.emit()
	_gm.run_time = 250.0
	_main.director.debug_trigger_event()
	var pool: Array = _gm.stage_data()["pool"]
	while _main._enemy_count() < _main.MAX_ENEMIES:
		_main._spawn_enemy(str(pool[randi() % pool.size()]), _main._ring_pos())
	_gm.run_time = _gm.RUN_DURATION - 0.02
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ctl = _main.boss.controller if _main.boss else null
	if ctl == null:
		print("PERF stage %d: no boss controller, state %d, boss_spawned %s" % [idx + 1, _gm.state, str(_gm.boss_spawned)])
	_times.clear()
	var peak_h := 0
	for f in 240:
		if ctl and f % 20 == 0:
			if ctl.begin_cast(Vector2.LEFT) >= 0.0:
				ctl.commit_cast()
		while _main._enemy_count() < _main.MAX_ENEMIES:
			_main._spawn_enemy(str(pool[randi() % pool.size()]), _main._ring_pos())
		await get_tree().physics_frame
		# Engine-measured work, in microseconds: physics + idle processing.
		_times.append(int((Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PROCESS)) * 1000000.0))
		peak_h = maxi(peak_h, get_tree().get_nodes_in_group("hazards").size())
		p.hp = p.max_hp
	_times.sort()
	var avg := 0.0
	for t in _times:
		avg += float(t)
	avg /= float(_times.size())
	print("PERF stage %d: script+physics avg %.2f ms, p95 %.2f ms, max %.2f ms, enemies %d, peak hazards %d" % [
		idx + 1, avg / 1000.0, float(_times[int(_times.size() * 0.95)]) / 1000.0,
		float(_times[-1]) / 1000.0, _main._enemy_count(), peak_h])
