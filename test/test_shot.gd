extends Node


var _frames := 0
var _main = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_main = get_tree().get_first_node_in_group("main")
	get_tree().root.size = Vector2i(720, 1280)
	await get_tree().process_frame
	await get_tree().process_frame
	var gm = get_node("/root/GameManager")
	gm.shards = 500
	_main._on_upgrades_open()
	set_process(true)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > 40:
		var img := get_tree().root.get_texture().get_image()
		var err := img.save_png("/tmp/gs_upgrades.png")
		print("SHOT saved err=", err, " size=", img.get_size())
		get_tree().quit(0)
