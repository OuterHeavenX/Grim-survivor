extends SceneTree
# Builds the enemy walk-cycle atlases in assets/sprites/ from the raw CraftPix
# animation frames in assets/packs/.
#
#   godot --headless --path . --script res://tools/build_sprites.gd
#
# The source frames are 384-2274 px tall, but enemies are drawn at roughly three
# times their body radius (52-180 px), so shipping them raw would put hundreds of
# megabytes of unused resolution into index.pck. Each frame is downscaled to the
# size it is actually drawn at and packed into one horizontal strip per enemy.

const PACKS := "res://assets/packs/"
const ZOMBIES := PACKS + "top-down-zombies/Zombies/PNG Animations/"
const BOSSES := PACKS + "topdown-bosses/Monsters/PNG Animations/"

# enemy type -> [source walk directory, drawn height in pixels]
# Heights are body_radius * 3.2, matching how large the procedural art read.
const SETS := {
	"skeleton":   [ZOMBIES + "1LVL/Zombie3_male/Walk", 52],
	"husk":       [ZOMBIES + "1LVL/Zombie4_male/Walk", 78],
	"wisp":       [ZOMBIES + "1LVL/Zombie1_female/Walk", 42],
	"bogling":    [ZOMBIES + "1LVL/Zombie2_female/Walk", 42],
	"mire":       [ZOMBIES + "2LVL/Army_zombie/Walk", 90],
	"imp":        [ZOMBIES + "2LVL/Cop_Zombie/Walk", 38],
	"titan":      [BOSSES + "3LVL/Zombie_big_hands/Walk", 110],
	"herald":     [BOSSES + "4LVL/Boss1/Walk", 141],
	"maw":        [BOSSES + "4LVL/Boss2/Walk", 160],
	"cinderking": [BOSSES + "5LVL/Walk", 180],
}

func _initialize() -> void:
	var manifest := {}
	var total := 0
	for etype in SETS:
		var dir_path: String = SETS[etype][0]
		var target_h: int = SETS[etype][1]
		var da := DirAccess.open(dir_path)
		if da == null:
			printerr("missing: ", dir_path)
			continue
		var names := []
		for f in da.get_files():
			if f.to_lower().ends_with(".png"):
				names.append(f)
		names.sort()
		if names.is_empty():
			printerr("no frames in ", dir_path)
			continue

		var frames := []
		for n in names:
			var img := Image.load_from_file(dir_path + "/" + n)
			if img == null:
				printerr("load failed: ", n)
				continue
			img.convert(Image.FORMAT_RGBA8)
			var scale := float(target_h) / float(img.get_height())
			var w := maxi(1, int(round(img.get_width() * scale)))
			img.resize(w, target_h, Image.INTERPOLATE_LANCZOS)
			frames.append(img)

		var fw := 0
		for img in frames:
			fw = maxi(fw, img.get_width())
		var sheet := Image.create(fw * frames.size(), target_h, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0, 0, 0, 0))
		for i in frames.size():
			var img: Image = frames[i]
			# Centre each frame in its cell so the character does not jitter.
			var x := i * fw + int((fw - img.get_width()) * 0.5)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, 0))

		var out := "res://assets/sprites/%s_walk.png" % etype
		sheet.save_png(out)
		var bytes := FileAccess.open(out, FileAccess.READ).get_length()
		total += bytes
		manifest[etype] = {"frames": frames.size(), "frame_w": fw, "frame_h": target_h}
		print("%-11s %2d frames  %4dx%-4d cell  %6.1f KB" % [etype, frames.size(), fw, target_h, bytes / 1024.0])

	var f := FileAccess.open("res://assets/sprites/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	print("TOTAL: %.2f MB across %d sheets" % [total / 1048576.0, manifest.size()])
	quit()
