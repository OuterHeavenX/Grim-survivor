extends SceneTree
# Builds the per-stage scatter art in assets/decor/ from the CraftPix tilesets.
#
#   godot --headless --path . --script res://tools/build_decor.gd
#
# Two pools per stage. "s" is small ground scatter -- stones, pebbles, grass --
# placed densely. "p" is large props: wrecks, ruined columns, buildings, trees,
# placed sparsely. Sources are 128-512 px; each is resized at build time to the
# size it is drawn at in world units, so ground.gd can just draw them 1:1.

const P3 := "res://assets/packs/tileset-pack-3/PNG/"
const OBJ := P3 + "objects/512/"

# The detail sets are split into per-resolution subdirectories (16/32/64/128/256),
# which hold *different* details rather than copies of the same one, so every
# bucket is listed. A height of 0 keeps the source size: these are already
# authored at the scale they should sit at on the ground.
# theme -> { "s": [[dir, height], ...], "p": [[file, height], ...] }
const DECOR := {
	"ashen": {
		"s": [[P3 + "details/stones/64", 0], [P3 + "details/stones/128", 0]],
		"p": [[OBJ + "object_0014_column1.png", 124], [OBJ + "object_0013_column2.png", 124]],
	},
	"marsh": {
		"s": [[P3 + "details/pebbles_water/64", 0], [P3 + "details/pebbles_water/128", 0],
			[P3 + "details/grass/64", 0], [P3 + "details/grass/32", 0]],
		"p": [[OBJ + "object_0007_tree.png", 190], [OBJ + "object_0006_tree2.png", 190],
			[OBJ + "object_0005_tree3.png", 170]],
	},
	"cinder": {
		"s": [[P3 + "details/ground/64", 0], [P3 + "details/ground/128", 0], [P3 + "details/ground/256", 0]],
		"p": [[OBJ + "object_0012_car1.png", 150], [OBJ + "object_0011_car2.png", 150],
			[OBJ + "object_0010_car3.png", 150], [OBJ + "object_0008_house.png", 270],
			[OBJ + "object_0009_garage.png", 240], [OBJ + "object_0014_column1.png", 124]],
	},
	"desert": {
		"s": [[P3 + "details/sand/64", 0], [P3 + "details/sand/128", 0]],
		"p": [[OBJ + "object_0014_column1.png", 124], [OBJ + "object_0013_column2.png", 124],
			[OBJ + "object_0003_tree5.png", 150]],
	},
	"barrens": {
		"s": [[P3 + "details/ground/64", 0], [P3 + "details/ground/128", 0]],
		"p": [[OBJ + "object_0013_column2.png", 124], [OBJ + "object_0010_car3.png", 150],
			[OBJ + "object_0004_tree4.png", 160]],
	},
	"grove": {
		"s": [[P3 + "details/grass/64", 0], [P3 + "details/grass/32", 0],
			[P3 + "details/ground/64", 0]],
		"p": [[OBJ + "object_0007_tree.png", 200], [OBJ + "object_0006_tree2.png", 200],
			[OBJ + "object_0005_tree3.png", 180]],
	},
	"drowned": {
		"s": [[P3 + "details/pebbles_water/64", 0], [P3 + "details/pebbles_water/128", 0]],
		"p": [[OBJ + "object_0005_tree3.png", 170], [OBJ + "object_0014_column1.png", 124],
			[OBJ + "object_0008_house.png", 250]],
	},
	"bastion": {
		"s": [[P3 + "details/ground/64", 0], [P3 + "details/ground/128", 0],
			[P3 + "details/ground/256", 0]],
		"p": [[OBJ + "object_0008_house.png", 270], [OBJ + "object_0009_garage.png", 240],
			[OBJ + "object_0012_car1.png", 150], [OBJ + "object_0011_car2.png", 150],
			[OBJ + "object_0014_column1.png", 124]],
	},
}


func _save(img: Image, height: int, out: String) -> int:
	img.convert(Image.FORMAT_RGBA8)
	if height > 0:
		var scale := float(height) / float(img.get_height())
		img.resize(maxi(1, int(round(img.get_width() * scale))), height, Image.INTERPOLATE_LANCZOS)
	img.save_png(out)
	return FileAccess.open(out, FileAccess.READ).get_length()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/decor"))
	var counts := {}
	var total := 0

	for theme in DECOR:
		var spec: Dictionary = DECOR[theme]
		for kind in ["s", "p"]:
			var i := 0
			for entry in spec[kind]:
				var path: String = entry[0]
				var height: int = entry[1]
				var files := []
				if path.ends_with(".png"):
					files.append(path)
				else:
					var da := DirAccess.open(path)
					if da == null:
						printerr("missing decor dir: ", path)
						continue
					for f in da.get_files():
						if f.to_lower().ends_with(".png"):
							files.append(path + "/" + f)
					files.sort()
				for f in files:
					var img := Image.load_from_file(f)
					if img == null:
						printerr("cannot read ", f)
						continue
					total += _save(img, height, "res://assets/decor/%s_%s%02d.png" % [theme, kind, i])
					i += 1
			counts["%s_%s" % [theme, kind]] = i
		print("%-7s  %2d scatter, %2d props" % [theme, counts[theme + "_s"], counts[theme + "_p"]])

	var f := FileAccess.open("res://assets/decor/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(counts, "\t"))
	f.close()
	print("TOTAL: %.1f KB" % [total / 1024.0])
	print("DECOR_COUNTS := ", counts)
	quit()
