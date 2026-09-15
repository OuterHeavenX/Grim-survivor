extends SceneTree
# Builds the enemy walk and death atlases in assets/sprites/ from the raw
# CraftPix animation frames in assets/packs/.
#
#   godot --headless --path . --script res://tools/build_sprites.gd
#
# The source frames are 384-2274 px tall, but enemies are drawn at roughly three
# times their body radius (38-180 px), so shipping them raw would put hundreds of
# megabytes of unused resolution into index.pck. Each frame is downscaled to the
# size it is actually drawn at and packed into one horizontal strip.
#
# Death frames are scaled by the SAME factor as that enemy's walk frames rather
# than to a fixed height: a death pose sprawls, so forcing it to the walk height
# would shrink the corpse relative to the living body.

const PACKS := "res://assets/packs/"
const ZOMBIES := PACKS + "top-down-zombies/Zombies/PNG Animations/"
const BOSSES := PACKS + "topdown-bosses/Monsters/PNG Animations/"
const SOLDIERS := PACKS + "top-down-soldiers/Characters/PNG_Bodyparts&Animations/PNG Animations/"

# Playable class -> [walk directory, drawn height]. The pack ships two bodies,
# so the four classes are told apart by the weapon animation each uses. This is
# placeholder art: the classes are a hooded rogue and a pyromancer, not
# soldiers. Swapping it is dropping four PNGs in and rerunning this tool.
const PLAYERS := {
	"rogue":  [SOLDIERS + "Man/Walk_knife", 78],
	"shadow": [SOLDIERS + "Girl/Walk_knife", 74],
	"pyro":   [SOLDIERS + "Girl/Walk_FireThrhrower", 76],
	"warden": [SOLDIERS + "Man/Walk_bat", 84],
	# The pack has ten body/weapon walk combinations and thirteen classes, so
	# three reuse one. They read apart anyway: player.gd tints every sprite by
	# its class palette.
	"flame": [SOLDIERS + "Man/Walk_firethrower", 76],
	"rime": [SOLDIERS + "Girl/Walk_riffle", 76],
	"dancer": [SOLDIERS + "Girl/Walk_bat", 74],
	"storm": [SOLDIERS + "Man/Walk_riffle", 78],
	"reaper": [SOLDIERS + "Man/Walk_bat", 80],
	"ravenmark": [SOLDIERS + "Girl/Walk_gun", 74],
	"bonewright": [SOLDIERS + "Man/Walk_gun", 84],
	"plague": [SOLDIERS + "Girl/Walk_FireThrhrower", 78],
	"starcaller": [SOLDIERS + "Man/Walk_knife", 76],
}

# enemy type -> [character directory, drawn walk height in px]
# Heights are body_radius * 3.2, matching how large the procedural art read.
const SETS := {
	"skeleton":   [ZOMBIES + "1LVL/Zombie3_male", 52],
	"husk":       [ZOMBIES + "1LVL/Zombie4_male", 78],
	"wisp":       [ZOMBIES + "1LVL/Zombie1_female", 42],
	"bogling":    [ZOMBIES + "1LVL/Zombie2_female", 42],
	"mire":       [ZOMBIES + "2LVL/Army_zombie", 90],
	"imp":        [ZOMBIES + "2LVL/Cop_Zombie", 38],
	"titan":      [BOSSES + "3LVL/Zombie_big_hands", 110],
	"herald":     [BOSSES + "4LVL/Boss1", 141],
	"maw":        [BOSSES + "4LVL/Boss2", 160],
	"cinderking": [BOSSES + "5LVL", 180],
}


func _frames_in(dir_path: String) -> Array:
	var da := DirAccess.open(dir_path)
	if da == null:
		return []
	var names := []
	for f in da.get_files():
		if f.to_lower().ends_with(".png"):
			names.append(f)
	names.sort()
	return names


func _build(dir_path: String, names: Array, scale: float) -> Array:
	# Returns [Image sheet, frame_count, cell_w, cell_h], or [] on failure.
	var frames := []
	for n in names:
		var img := Image.load_from_file(dir_path + "/" + n)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w := maxi(1, int(round(img.get_width() * scale)))
		var h := maxi(1, int(round(img.get_height() * scale)))
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
		frames.append(img)
	if frames.is_empty():
		return []
	var fw := 0
	var fh := 0
	for img in frames:
		fw = maxi(fw, img.get_width())
		fh = maxi(fh, img.get_height())
	var sheet := Image.create(fw * frames.size(), fh, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for i in frames.size():
		var img: Image = frames[i]
		# Centre each frame in its cell so the character does not jitter.
		var x := i * fw + int((fw - img.get_width()) * 0.5)
		var y := int((fh - img.get_height()) * 0.5)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, y))
	return [sheet, frames.size(), fw, fh]


func _desaturate(img: Image) -> void:
	# The soldier art is uniformly olive, so tinting it at runtime just yields
	# a slightly different olive. Strip the hue here and the class palette in
	# player.gd becomes the thing that actually colours the survivor. Lifted a
	# little, since multiplying by a tint only ever darkens.
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var l := clampf((0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * 1.25, 0.0, 1.0)
			img.set_pixel(x, y, Color(l, l, l, c.a))


func _emit(sheet: Image, out: String) -> int:
	sheet.save_png(out)
	return FileAccess.open(out, FileAccess.READ).get_length()


func _initialize() -> void:
	var walk_counts := {}
	var death_counts := {}
	var total := 0

	for etype in SETS:
		var base: String = SETS[etype][0]
		var walk_h: int = SETS[etype][1]

		var walk_names := _frames_in(base + "/Walk")
		if walk_names.is_empty():
			printerr("no walk frames for ", etype, " in ", base)
			continue
		var probe := Image.load_from_file(base + "/Walk/" + walk_names[0])
		if probe == null:
			printerr("cannot read first walk frame for ", etype)
			continue
		var scale := float(walk_h) / float(probe.get_height())

		var walk := _build(base + "/Walk", walk_names, scale)
		if walk.is_empty():
			continue
		var bytes := _emit(walk[0], "res://assets/sprites/%s_walk.png" % etype)
		total += bytes
		walk_counts[etype] = walk[1]
		print("%-11s walk  %2d frames %4dx%-4d %7.1f KB" % [etype, walk[1], walk[2], walk[3], bytes / 1024.0])

		var death_names := _frames_in(base + "/Death")
		if death_names.is_empty():
			printerr("  no death frames for ", etype)
			continue
		var death := _build(base + "/Death", death_names, scale)
		if death.is_empty():
			continue
		bytes = _emit(death[0], "res://assets/sprites/%s_death.png" % etype)
		total += bytes
		death_counts[etype] = death[1]
		print("%-11s death %2d frames %4dx%-4d %7.1f KB" % ["", death[1], death[2], death[3], bytes / 1024.0])

	var player_counts := {}
	for cls in PLAYERS:
		var dir_path: String = PLAYERS[cls][0]
		var target_h: int = PLAYERS[cls][1]
		var names := _frames_in(dir_path)
		if names.is_empty():
			printerr("no walk frames for class ", cls, " in ", dir_path)
			continue
		var probe := Image.load_from_file(dir_path + "/" + names[0])
		if probe == null:
			continue
		var built := _build(dir_path, names, float(target_h) / float(probe.get_height()))
		if built.is_empty():
			continue
		_desaturate(built[0])
		var b := _emit(built[0], "res://assets/sprites/player_%s_walk.png" % cls)
		total += b
		player_counts[cls] = built[1]
		print("%-11s walk  %2d frames %4dx%-4d %7.1f KB" % ["player:" + cls, built[1], built[2], built[3], b / 1024.0])

	var f := FileAccess.open("res://assets/sprites/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"walk": walk_counts, "death": death_counts, "players": player_counts}, "\t"))
	f.close()
	print("TOTAL: %.2f MB  (%d walk sheets, %d death sheets)" % [total / 1048576.0, walk_counts.size(), death_counts.size()])
	print("WALK_SHEETS := ", walk_counts)
	print("DEATH_SHEETS := ", death_counts)
	print("PLAYER_SHEETS := ", player_counts)
	quit()
