extends SceneTree
# Builds one tileable ground texture per stage theme into assets/ground/ from
# the CraftPix tilesets in assets/packs/.
#
#   godot --headless --path . --script res://tools/build_ground.gd
#
# Each tile set ships 13 variants, but only some are full tiles -- the rest are
# edges and corners that show a hard seam when repeated. Rather than pick by eye,
# every candidate is scored by how well it wraps (how closely its left column
# matches its right, and its top row its bottom) and the best few are mosaicked
# into one larger texture. Because each chosen tile is seamless on its own, any
# arrangement of them is seamless too, which breaks up the obvious repeat.

const PACKS := "res://assets/packs/"
const TILE := 64      # all sources are normalised to this before mosaicking
const GRID := 4       # 4x4 -> a 256x256 texture

# stage theme -> source directory of candidate tiles
const THEMES := {
	"ashen": PACKS + "tileset-pack-3/PNG/tiles/stones",
	"marsh": PACKS + "tileset-pack-3/PNG/tiles/water",
	"cinder": PACKS + "tileset/Tiles&Details/PNG_version_2/Asphalt_tiles",
}
# Other sets in the same pack, unused so far but available for new stages:
# Grass_tiles (jungle/overgrown), Ground_tiles (dirt), Water_tiles.
const NAME_FILTER := {}


func _wrap_error(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var err := 0.0
	for y in h:
		var a := img.get_pixel(0, y)
		var b := img.get_pixel(w - 1, y)
		err += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
	for x in w:
		var a := img.get_pixel(x, 0)
		var b := img.get_pixel(x, h - 1)
		err += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
	return err / float(w + h)


func _mean_color(img: Image) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var r := 0.0
	var g := 0.0
	var b := 0.0
	# Every 4th pixel is plenty for a mean and keeps this instant.
	var n := 0
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := img.get_pixel(x, y)
			r += c.r
			g += c.g
			b += c.b
			n += 1
	return Color(r / n, g / n, b / n)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ground"))
	var report := {}

	for theme in THEMES:
		var dir_path: String = THEMES[theme]
		var da := DirAccess.open(dir_path)
		if da == null:
			printerr("missing tile directory for ", theme, ": ", dir_path)
			continue
		var want: String = NAME_FILTER.get(theme, "")

		var scored := []
		for f in da.get_files():
			if not f.to_lower().ends_with(".png"):
				continue
			if want != "" and not f.begins_with(want):
				continue
			var img := Image.load_from_file(dir_path + "/" + f)
			if img == null:
				continue
			img.convert(Image.FORMAT_RGB8)
			if img.get_width() != TILE or img.get_height() != TILE:
				img.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
			scored.append({"name": f, "img": img, "err": _wrap_error(img)})

		if scored.is_empty():
			printerr("no candidate tiles for ", theme)
			continue
		scored.sort_custom(func(a, b): return a["err"] < b["err"])

		# A low wrap error alone is not enough. These sets mix materials -- the
		# asphalt set carries kerb pieces, the water set carries lighter shallows --
		# and mosaicking those together produces obvious blocks. Keep only tiles
		# that both wrap as cleanly as the best one and share its colour.
		var best: Dictionary = scored[0]
		var best_c: Color = _mean_color(best["img"])
		var picks := []
		for cand in scored:
			if picks.size() >= 4:
				break
			if cand["err"] > best["err"] * 3.0 + 0.05:
				continue
			var c: Color = _mean_color(cand["img"])
			var dist := absf(c.r - best_c.r) + absf(c.g - best_c.g) + absf(c.b - best_c.b)
			if dist > 0.09:
				continue
			picks.append(cand)
		if picks.is_empty():
			picks = [best]
		var sheet := Image.create(TILE * GRID, TILE * GRID, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(theme)
		for gy in GRID:
			for gx in GRID:
				var pick: Dictionary = picks[rng.randi_range(0, picks.size() - 1)]
				sheet.blit_rect(pick["img"], Rect2i(0, 0, TILE, TILE),
					Vector2i(gx * TILE, gy * TILE))

		var out := "res://assets/ground/%s.png" % theme
		sheet.save_png(out)
		var bytes := FileAccess.open(out, FileAccess.READ).get_length()
		report[theme] = bytes
		var names := []
		for p in picks:
			names.append("%s (%.3f)" % [p["name"], p["err"]])
		print("%-7s %d candidates -> %dx%d  %6.1f KB" % [theme, scored.size(), TILE * GRID, TILE * GRID, bytes / 1024.0])
		print("        picked: ", ", ".join(names))
		print("        worst rejected: %s (%.3f)" % [scored[-1]["name"], scored[-1]["err"]])

	var total := 0
	for k in report:
		total += report[k]
	print("TOTAL: %.1f KB across %d ground textures" % [total / 1024.0, report.size()])
	quit()
