extends SceneTree
## Visual review: run without --headless; screenshots go to art/civilians/.

func _initialize() -> void:
	call_deferred("run")

func shot(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://art/civilians/" + filename)
	print("CAPTURE ", filename, " error=", error)

func run() -> void:
	root.size = Vector2i(720, 1280)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gm = root.get_node("GameManager")
	root.get_node("AudioMan")._music.stop()
	root.get_node("AudioMan")._music.stream = null
	var original_class: String = gm.selected_class
	main.title_screen.hide_screen()
	main.char_select.show_screen()
	await shot("selection_in_game.png")
	main.char_select.hide_screen()
	gm.selected_class = "shadow"
	main.start_run()
	await create_timer(.3).timeout
	await shot("woman_in_game.png")
	gm.selected_class = "rogue"
	main.start_run()
	await create_timer(.3).timeout
	await shot("man_in_game.png")
	gm.selected_class = original_class
	call_deferred("quit")
