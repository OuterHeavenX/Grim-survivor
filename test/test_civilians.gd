extends SceneTree
## godot --headless --path . --script res://test/test_civilians.gd
## Uses live Player nodes; never writes save data or changes unlocks.

var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var gm = root.get_node("GameManager")
	# This fast headless harness must release the autoload's looping audio before exit.
	root.get_node("AudioMan")._music.stop()
	root.get_node("AudioMan")._music.stream = null
	var original_class: String = gm.selected_class
	var script = load("res://src/player.gd")
	var cs_script = load("res://src/char_select.gd")
	for c in gm.CHAR_CLASSES:
		var id: String = c["id"]
		gm.selected_class = id
		var p = script.new()
		root.add_child(p)
		p.set_physics_process(false)
		p.weapons_node.set_physics_process(false)
		check(p._spr != null, id + " has sprite")
		check(p._spr.hframes == 1 and p._spr.texture.resource_path.ends_with("_idle.png"), id + " starts idle")
		check(p._spr.modulate == Color.WHITE, id + " preserves skin and clothing colours")
		var walk: Image = p._walk_texture.get_image()
		check(walk.get_width() == walk.get_height() * 6, id + " six square frames")
		var pose_hashes := {}
		for frame in 6:
			var crop := walk.get_region(Rect2i(frame * walk.get_height(), 0, walk.get_height(), walk.get_height()))
			pose_hashes[crop.get_data().hex_encode().sha256_text()] = true
			check(crop.get_used_rect().has_area(), id + " nonempty frame %d" % frame)
		check(pose_hashes.size() == 6, id + " six distinct walk poses")
		var portrait = cs_script.PortraitIcon.new(id)
		check(portrait.portrait != null, id + " matching selection portrait")
		portrait.free()
		key(KEY_D, true)
		p._physics_process(0.12)
		check(p._spr.hframes == 6 and p._spr.frame == 1, id + " movement advances walk")
		check(absf(p._spr.rotation + PI * .5) < .001, id + " faces right while moving right")
		key(KEY_D, false)
		p._physics_process(0.12)
		check(p._spr.hframes == 1 and p._spr.frame == 0, id + " stopping restores idle")
		p._hurt_flash = .12
		p._physics_process(.02)
		check(p._spr.modulate != Color.WHITE, id + " damage flash works")
		p._physics_process(.2)
		check(p._spr.modulate == Color.WHITE, id + " damage flash clears")
		p.queue_free()
		await process_frame
	gm.selected_class = original_class
	print("CIVILIANS TEST DONE fails=", failures)
	call_deferred("quit", 1 if failures else 0)
