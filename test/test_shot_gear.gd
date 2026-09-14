extends Node


var _frames := 0
var _main = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_main = get_tree().get_first_node_in_group("main")
	get_tree().root.size = Vector2i(720, 1280)
	_main.start_run()
	set_process(true)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 8:
		var p = _main.player
		p.set("max_hp", 100000.0)
		p.set("hp", 100000.0)

		for i in 14:
			var a := TAU * float(i) / 14.0
			_main._spawn_enemy("skeleton", p.global_position + Vector2(cos(a), sin(a)) * 260.0)
		var w = p.get_node("Weapons")
		w._fire_lance(4)
		w._fire_miasma(4)
		w._fire_comet(4)
		w._fire_lance(4)
	if _frames == 30:
		var img := get_tree().root.get_texture().get_image()
		var err := img.save_png("/tmp/gs_newgear.png")
		print("SHOT saved err=", err, " size=", img.get_size())
		get_tree().quit(0)
