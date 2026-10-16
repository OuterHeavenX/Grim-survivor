extends Node


signal xp_changed
signal level_changed
signal kills_changed
signal time_changed
signal weapons_changed
signal run_started
signal run_ended(victory: bool)
signal shards_changed

enum State{TITLE, RUNNING, LEVELUP, PAUSED, GAMEOVER, VICTORY, CHEST}

const RUN_DURATION := 300.0
const MAX_WEAPONS := 4

const CONTENT: GameContentData = preload("res://data/game_content.tres")
# Compatibility dictionaries keep the rest of the game stable while systems are
# migrated to typed resources incrementally.
var WEAPONS: Dictionary = CONTENT.weapon_dictionary()
var PASSIVES: Dictionary = CONTENT.passive_dictionary()
var EVOLUTIONS: Dictionary = CONTENT.evolution_dictionary()



# Characters, stages and meta tracks are authored as Resources under data/;
# these views keep the dictionary shape the menus and tests were written
# against while the rest of the game reads the typed definitions directly.
var CHAR_CLASSES: Array = CONTENT.character_dictionaries()
var STAGES: Array = CONTENT.stage_dictionaries()
var META_TRACKS: Array = CONTENT.meta_track_dictionaries()
var META_BONUS: Dictionary = CONTENT.meta_bonus_dictionary()

const SAVE_PATH := "user://grim_survivors.cfg"
# Bumped when the save gains sections. Loading never requires it: every key
# has a default, and saving rewrites only the keys this build owns.
const SAVE_VERSION := 2

var shards := 0
var run_shards := 0
var last_banked := 0
var meta := {}
var revives_left := 0
var selected_class := "rogue"
var unlocked := {"rogue": 1}

# Campaign mode. Free play leaves every stage open, which is how the game has
# always behaved; the campaign is the structured path that hands out the
# characters, so the nine relic-only ones stop depending on finding a 26px
# pickup in a 3000x3000 arena.
var campaign := false
# How many stages the campaign has opened. Always at least 1: stage one is
# where a campaign starts.
var campaign_unlocked := 1

var state: int = State.TITLE
var run_time := 0.0
var kills := 0
var level := 1
var xp := 0
var pending_levelups := 0
var weapons := {}
var passives := {}
var evolved := {}
var stage := 0
# Stage picked on the title screen; a run starts there instead of the first.
var selected_stage := 0
# Weapons carried into a run. Empty means "just the class's own weapon", which
# is how the game behaved before loadouts existed.
const MAX_LOADOUT := 2
var loadout: Array[String] = []

# Relics: each stage hides a pair of a particular weapon's relics, and finding
# both unlocks the character who wields it. Which weapon a stage offers is the
# first of its candidates whose character is still locked, so a stage stops
# offering what you already have.
const RELICS_PER_STAGE := 2
var relic_weapon := ""
var relics_found := 0
# Total run length in minutes, chosen on the title screen. RUN_DURATION is one
# stage, so this is really "how many stages before victory".
const RUN_LENGTHS := [5, 10, 15, 20, 30]
var selected_minutes := 5
# Stages finished in the current run; victory once it reaches stages_in_run().
var stages_cleared := 0
var boss_spawned := false
var boss_alive := false

var best := {"time": 0.0, "kills": 0, "level": 0, "wins": 0}

# Seeds every stage's event placement, so a run can be replayed and a bug
# report can name the run it came from. -1 means "roll one"; tests pin it.
var run_seed := 0
var forced_seed := -1
var run_stats: RunStats = RunStats.new()
var mods: GameModifiers = GameModifiers.new()
# Run relics held this run (ids, in pick order) and the ones ever discovered.
var run_relics: Array[String] = []
var relics_discovered := {}
# A campaign completion marker: cosmetic, not power.
var campaign_crowned := false

const DEFAULT_SETTINGS := {
	"shake": 1.0, "flashes": true, "damage_numbers": true,
	"hazard_opacity": 1.0, "high_contrast": false, "reduced_effects": false,
}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var content_errors := CONTENT.validation_errors()
	assert(content_errors.is_empty(), "Invalid game content:\n%s" % "\n".join(content_errors))
	if not content_errors.is_empty():
		push_error("Invalid game content:\n%s" % "\n".join(content_errors))
	load_best()
	load_meta()
	load_settings()


func meta_rank(track_id: String) -> int:
	return int(meta.get(track_id, 0))


func track_by_id(track_id: String) -> Dictionary:
	for t in META_TRACKS:
		if t["id"] == track_id:
			return t
	return {}


func track_cost(track_id: String) -> int:

	var t := track_by_id(track_id)
	var costs: Array = t["costs"]
	var r := meta_rank(track_id)
	if r >= costs.size():
		return -1
	return int(costs[r])


func buy_track(track_id: String) -> bool:
	var cost := track_cost(track_id)
	if cost < 0 or shards < cost:
		return false
	shards -= cost
	meta[track_id] = meta_rank(track_id) + 1
	save_meta()
	return true


func track_bonus_text(track_id: String) -> String:
	var t := track_by_id(track_id)
	var per: float = META_BONUS[track_id]
	var cur := int(round(per * float(meta_rank(track_id))))
	return t["fmt"] % cur


func track_next_text(track_id: String) -> String:
	var t := track_by_id(track_id)
	var per: float = META_BONUS[track_id]
	var nxt := int(round(per * float(meta_rank(track_id) + 1)))
	return t["fmt"] % nxt

func track_short_text(track_id: String) -> String:
	var t := track_by_id(track_id)
	var per: float = META_BONUS[track_id]
	var cur := int(round(per * float(meta_rank(track_id))))
	return t["short"] % cur


func track_short_next_text(track_id: String) -> String:
	var t := track_by_id(track_id)
	var per: float = META_BONUS[track_id]
	var nxt := int(round(per * float(meta_rank(track_id) + 1)))
	return t["short"] % nxt



func class_by_id(id: String) -> Dictionary:
	for c in CHAR_CLASSES:
		if str(c["id"]) == id:
			return c
	return CHAR_CLASSES[0]


# Shards for clearing a campaign stage. The last two stages reuse earlier
# stages' relic weapons, so they have no new character to hand over; they pay
# out instead rather than being a reward-less wall at the end of the campaign.
const CAMPAIGN_SHARDS := [15, 20, 25, 35, 45, 60, 90, 140]


# Enemy scaling. These live here rather than inline in main.gd so the balance
# probe measures the same curve the game runs, instead of a copy of it that can
# drift.
func enemy_hp_mult(stage_idx: int, t: float) -> float:
	return (1.0 + t / 60.0 * 0.35) * (1.0 + float(stage_idx) * 0.45)


func enemy_dmg_mult(stage_idx: int, t: float) -> float:
	# 0.2 per stage stacked with the time curve reached 3.6x by the last stage,
	# where three touching foes killed a fully upgraded player in 0.7s.
	return (1.0 + t / 120.0 * 0.2) * (1.0 + float(stage_idx) * 0.14)


func campaign_stage_open(i: int) -> bool:
	# Free play was always open to every stage and stays that way.
	if not campaign:
		return true
	return i < campaign_unlocked


func campaign_progress() -> String:
	return "%d / %d STAGES" % [campaign_unlocked, STAGES.size()]


func chars_for_stage(i: int) -> Array:
	# The campaign hands over the characters whose weapon is hidden in that
	# stage as a relic, so the two paths agree on which stage owns which
	# character -- the campaign is just the one that cannot be missed.
	var out: Array = []
	if i < 0 or i >= STAGES.size():
		return out
	var want: Array = STAGES[i].get("relics", [])
	for c in CHAR_CLASSES:
		if want.has(str(c.get("weapon", ""))):
			out.append(c)
	return out


func clear_campaign_stage(i: int) -> Array:
	# Returns the characters this clear actually unlocked, so the HUD can name
	# them. Already-owned ones are dropped: telling the player they unlocked
	# something they have had for an hour is noise.
	var freshly: Array = []
	if not campaign:
		return freshly
	if i < 0 or i >= STAGES.size():
		return freshly
	for c in chars_for_stage(i):
		var cid: String = str(c["id"])
		if not is_class_unlocked(cid):
			unlocked[cid] = 1
			freshly.append(str(c["name"]))
	if i < CAMPAIGN_SHARDS.size():
		shards += int(CAMPAIGN_SHARDS[i])
	# Opening the next stage is what makes this a campaign; clearing stage 3 a
	# second time must not push the frontier past stage 4.
	campaign_unlocked = clampi(maxi(campaign_unlocked, i + 2), 1, STAGES.size())
	save_meta()
	return freshly


func is_class_unlocked(id: String) -> bool:
	return bool(unlocked.get(id, 0))


func unlock_class(id: String) -> bool:
	var c := class_by_id(id)
	var cost := int(c["cost"])
	# A negative cost marks a class that shards cannot buy: it is found in the
	# world, not purchased.
	if cost < 0 or is_class_unlocked(id) or shards < cost:
		return false
	shards -= cost
	unlocked[id] = 1
	save_meta()
	return true



func select_class(id: String) -> bool:
	if not is_class_unlocked(id):
		return false
	selected_class = id
	save_meta()
	return true


func class_hp() -> float:
	return float(class_by_id(selected_class)["hp"])


func class_damage_mult() -> float:
	return float(class_by_id(selected_class)["dmg"])


func class_speed_mult() -> float:
	return float(class_by_id(selected_class)["speed"])


func class_magnet_mult() -> float:
	return float(class_by_id(selected_class)["magnet"])


func class_xp_mult() -> float:
	return float(class_by_id(selected_class)["xp"])


func class_start_weapon() -> String:
	return str(class_by_id(selected_class)["weapon"])





func setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_settings()


func meta_damage_mult() -> float:
	return (1.0 + 0.06 * float(meta_rank("edge"))) * class_damage_mult()


func meta_hp_bonus() -> float:
	return 12.0 * float(meta_rank("vitality"))


func meta_speed_mult() -> float:
	return (1.0 + 0.04 * float(meta_rank("boots"))) * class_speed_mult()


func meta_magnet_mult() -> float:
	return (1.0 + 0.08 * float(meta_rank("greed"))) * class_magnet_mult()


func meta_xp_mult() -> float:
	return (1.0 + 0.05 * float(meta_rank("scholar"))) * class_xp_mult()


func meta_revives() -> int:
	return meta_rank("wind")


func add_shards(v: int) -> void:
	run_shards += v
	shards_changed.emit()


func bank_run_shards() -> void:
	last_banked = run_shards
	shards += run_shards
	run_shards = 0
	save_meta()


func consume_revive() -> bool:
	if revives_left > 0:
		revives_left -= 1
		return true
	return false


func xp_needed() -> int:
	return 5 + (level - 1) * 6


func stages_in_run() -> int:
	return maxi(1, int(round(float(selected_minutes) * 60.0 / RUN_DURATION)))


func class_for_weapon(w: String) -> String:
	for c in CHAR_CLASSES:
		if str(c["weapon"]) == w:
			return str(c["id"])
	return ""


func stage_relic_weapon(stage_idx: int) -> String:
	if stage_idx < 0 or stage_idx >= STAGES.size():
		return ""
	for w in STAGES[stage_idx].get("relics", []):
		var cid := class_for_weapon(str(w))
		if cid != "" and not is_class_unlocked(cid):
			return str(w)
	return ""


func relic_stage_for_class(id: String) -> int:
	var c := class_by_id(id)
	if c.is_empty():
		return -1
	var w := str(c["weapon"])
	for i in STAGES.size():
		if STAGES[i].get("relics", []).has(w):
			return i
	return -1


func begin_stage_relics(stage_idx: int) -> void:
	relic_weapon = stage_relic_weapon(stage_idx)
	relics_found = 0


func collect_relic() -> String:
	# Returns the class id unlocked by this pickup, or "" if more are needed.
	relics_found += 1
	if relics_found < RELICS_PER_STAGE or relic_weapon == "":
		return ""
	var cid := class_for_weapon(relic_weapon)
	if cid == "" or is_class_unlocked(cid):
		return ""
	unlocked[cid] = 1
	save_meta()
	return cid


func loadout_has(id: String) -> bool:
	return loadout.has(id)


func toggle_loadout(id: String) -> bool:
	# Returns true if the weapon ended up in the loadout.
	if not WEAPONS.has(id):
		return false
	if loadout.has(id):
		loadout.erase(id)
		save_meta()
		return false
	if loadout.size() >= MAX_LOADOUT:
		return false
	loadout.append(id)
	save_meta()
	return true


func run_start_weapons() -> Dictionary:
	var out := {}
	for id in loadout:
		if WEAPONS.has(id) and out.size() < MAX_WEAPONS:
			out[id] = 1
	if out.is_empty():
		out[class_start_weapon()] = 1
	return out


func reset_run() -> void:
	run_seed = forced_seed if forced_seed >= 0 else randi() % 1000000
	run_stats = RunStats.new()
	run_stats.run_seed = run_seed
	mods.clear_all()
	run_relics.clear()
	stages_cleared = 0
	run_time = 0.0
	kills = 0
	level = 1
	xp = 0
	pending_levelups = 0
	weapons = run_start_weapons()
	passives = {}
	evolved = {}
	stage = clampi(selected_stage, 0, STAGES.size() - 1)
	boss_spawned = false
	boss_alive = false
	run_shards = 0
	revives_left = meta_revives()
	state = State.RUNNING
	run_started.emit()


func stage_data() -> Dictionary:
	return STAGES[clampi(stage, 0, STAGES.size() - 1)]


func stage_def() -> StageData:
	return CONTENT.stage_at(stage)


func stage_rule_seed(stage_idx: int) -> int:
	# Distinct per stage and per run, stable for a given run seed.
	return abs(hash("%d:%d" % [run_seed, stage_idx])) % 2147483647


# --- run modifiers and relics --------------------------------------------

func clear_stage_mods() -> void:
	mods.clear_prefix("stage:")


func has_relic(id: String) -> bool:
	return run_relics.has(id)


func add_run_relic(id: String) -> bool:
	var r := CONTENT.relic(id)
	if r == null or run_relics.has(id):
		return false
	run_relics.append(id)
	if not r.modifiers.is_empty():
		mods.set_mods("relic:" + id, r.modifiers)
	weapons_changed.emit()
	return true


func is_relic_discovered(id: String) -> bool:
	var r := CONTENT.relic(id)
	if r == null:
		return false
	return r.discovered_by_default or bool(relics_discovered.get(id, false))


func discover_stage_relics(stage_id: String) -> Array:
	# Returns the relics this stage's first clear revealed.
	var found: Array = []
	for item in CONTENT.relics:
		var r := item as RelicData
		if r and String(r.discover_stage) == stage_id and not is_relic_discovered(String(r.id)):
			relics_discovered[String(r.id)] = true
			found.append(String(r.id))
	if not found.is_empty():
		save_meta()
	return found


func roll_relics(tags: PackedStringArray, count := 3, rng: RandomNumberGenerator = null) -> Array:
	# Weighted, not filtered: each matching stage tag adds weight, so a stage
	# leans towards its theme without ever offering only that.
	var pool: Array = []
	for item in CONTENT.relics:
		var r := item as RelicData
		if r == null or run_relics.has(String(r.id)) or not is_relic_discovered(String(r.id)):
			continue
		if not r.requires_weapons.is_empty():
			var ok := false
			for w in r.requires_weapons:
				if weapons.has(w):
					ok = true
			if not ok:
				continue
		var wgt := 1.0
		for t in r.tags:
			if tags.has(t):
				wgt += 2.0
		pool.append([r, wgt])
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var total := 0.0
		for e in pool:
			total += float(e[1])
		var roll := (rng.randf() if rng else randf()) * total
		var pick := pool.size() - 1
		for i in pool.size():
			roll -= float(pool[i][1])
			if roll <= 0.0:
				pick = i
				break
		out.append(pool[pick][0])
		pool.remove_at(pick)
	return out


func is_evolved(id: String) -> bool:
	return bool(evolved.get(id, false))


func add_xp(v: int) -> void:
	if state != State.RUNNING and state != State.LEVELUP:
		return
	xp += int(round(float(v) * meta_xp_mult() * mods.mult("xp")))
	var need := xp_needed()
	while xp >= need:
		xp -= need
		level += 1
		pending_levelups += 1
		need = xp_needed()
	xp_changed.emit()
	level_changed.emit()


func add_kill() -> void:
	kills += 1
	kills_changed.emit()


func might_mult() -> float:
	return (1.0 + 0.12 * float(passives.get("might", 0))) * meta_damage_mult() * mods.mult("damage")


func haste_mult() -> float:
	return pow(0.92, float(passives.get("haste", 0))) * mods.mult("cooldown")


func speed_mult() -> float:
	return (1.0 + 0.08 * float(passives.get("boots", 0))) * meta_speed_mult() * mods.mult("speed")


func magnet_mult() -> float:
	return (1.0 + 0.4 * float(passives.get("magnet", 0))) * meta_magnet_mult() * mods.mult("magnet")


func siphon_heal() -> float:
	return 2.0 * float(passives.get("siphon", 0))


func armor_block() -> float:
	return 2.0 * float(passives.get("armor", 0)) + mods.add("armor")


func roll_upgrades(count := 3) -> Array:

	var evos: Array = []
	for id in EVOLUTIONS:
		if int(weapons.get(id, 0)) >= int(WEAPONS[id]["max"]) and not is_evolved(id):
			var req: String = str(EVOLUTIONS[id]["passive"])
			if int(passives.get(req, 0)) >= 1:
				evos.append({"kind": "evolve", "id": id})
	var pool: Array = []
	for id in WEAPONS:
		var lvl := int(weapons.get(id, 0))
		if lvl == 0 and weapons.size() < MAX_WEAPONS:
			pool.append({"kind": "weapon", "id": id, "to": 1, "is_new": true})
		elif lvl > 0 and lvl < int(WEAPONS[id]["max"]):
			pool.append({"kind": "weapon", "id": id, "to": lvl + 1, "is_new": false})
	for id in PASSIVES:
		var lvl := int(passives.get(id, 0))
		if lvl < int(PASSIVES[id]["max"]):
			pool.append({"kind": "passive", "id": id, "to": lvl + 1, "is_new": lvl == 0})
	pool.shuffle()
	var out := evos.slice(0, 2)
	out.append_array(pool.slice(0, maxi(count - out.size(), 0)))
	return out


func apply_upgrade(choice: Dictionary) -> void:
	if choice["kind"] == "evolve":
		evolved[choice["id"]] = true
	elif choice["kind"] == "weapon":
		weapons[choice["id"]] = choice["to"]
	else:
		passives[choice["id"]] = choice["to"]
		if choice["id"] == "vitality":
			var p := get_tree().get_first_node_in_group("player")
			if p and p.has_method("on_vitality"):
				p.on_vitality()
	pending_levelups = maxi(0, pending_levelups - 1)
	weapons_changed.emit()


func end_run(victory: bool) -> void:
	state = State.VICTORY if victory else State.GAMEOVER
	# run_time restarts each stage, so a run's length is the stages already
	# finished plus however far into the current one it ended.
	var survived := float(selected_minutes) * 60.0 if victory \
		else RUN_DURATION * float(stages_cleared) + run_time
	best["time"] = maxf(float(best["time"]), survived)
	best["kills"] = maxi(int(best["kills"]), kills)
	best["level"] = maxi(int(best["level"]), level)
	run_stats.finish(survived, victory, stages_cleared, evolved)
	if victory:
		best["wins"] = int(best["wins"]) + 1
		run_shards += 10
	bank_run_shards()
	save_best()
	run_ended.emit(victory)


func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		shards = int(cfg.get_value("meta", "shards", 0))
		for t in META_TRACKS:
			var id: String = t["id"]
			meta[id] = clampi(int(cfg.get_value("meta", "rank_" + id, 0)), 0, 5)

		unlocked = {"rogue": 1}
		for c in CHAR_CLASSES:
			var cid: String = str(c["id"])
			if int(cfg.get_value("meta", "char_" + cid, 0)) > 0 or cid == "rogue":
				unlocked[cid] = 1
		campaign_unlocked = clampi(
			int(cfg.get_value("meta", "campaign_unlocked", 1)), 1, STAGES.size())
		campaign = int(cfg.get_value("meta", "campaign_mode", 0)) > 0
		campaign_crowned = int(cfg.get_value("meta", "campaign_crowned", 0)) > 0
		relics_discovered = {}
		for item in CONTENT.relics:
			var r := item as RelicData
			if r and int(cfg.get_value("relics", "found_" + String(r.id), 0)) > 0:
				relics_discovered[String(r.id)] = true
		var sel := str(cfg.get_value("meta", "char_selected", "rogue"))
		selected_class = sel if is_class_unlocked(sel) else "rogue"
		_load_loadout(cfg)
	else:
		shards = 0
		meta = {}
		unlocked = {"rogue": 1}
		selected_class = "rogue"
		campaign_unlocked = 1
		campaign = false
		campaign_crowned = false
		relics_discovered = {}


func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("meta", "shards", shards)
	for t in META_TRACKS:
		var id: String = t["id"]
		cfg.set_value("meta", "rank_" + id, meta_rank(id))
	for c in CHAR_CLASSES:
		var cid: String = str(c["id"])
		cfg.set_value("meta", "char_" + cid, 1 if is_class_unlocked(cid) else 0)
	cfg.set_value("meta", "char_selected", selected_class)
	cfg.set_value("meta", "campaign_unlocked", campaign_unlocked)
	cfg.set_value("meta", "campaign_mode", 1 if campaign else 0)
	cfg.set_value("meta", "loadout", ",".join(loadout))
	cfg.set_value("meta", "campaign_crowned", 1 if campaign_crowned else 0)
	cfg.set_value("meta", "save_version", SAVE_VERSION)
	for rid in relics_discovered:
		cfg.set_value("relics", "found_" + String(rid), 1)
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in DEFAULT_SETTINGS:
		var def: Variant = DEFAULT_SETTINGS[k]
		var v: Variant = cfg.get_value("settings", k, def)
		# A hand-edited or future save may hold the wrong type; fall back
		# rather than let a string reach the shake maths.
		if typeof(v) == TYPE_INT and typeof(def) == TYPE_FLOAT:
			v = float(v)
		settings[k] = v if typeof(v) == typeof(def) else def
	settings["shake"] = clampf(float(settings["shake"]), 0.0, 1.0)
	settings["hazard_opacity"] = clampf(float(settings["hazard_opacity"]), 0.5, 1.5)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SAVE_PATH)


func _load_loadout(cfg: ConfigFile) -> void:
	loadout.clear()
	var raw := str(cfg.get_value("meta", "loadout", ""))
	if raw == "":
		return
	for id in raw.split(",", false):
		var w := str(id).strip_edges()
		if WEAPONS.has(w) and not loadout.has(w) and loadout.size() < MAX_LOADOUT:
			loadout.append(w)


func load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best["time"] = float(cfg.get_value("best", "time", 0.0))
		best["kills"] = int(cfg.get_value("best", "kills", 0))
		best["level"] = int(cfg.get_value("best", "level", 0))
		best["wins"] = int(cfg.get_value("best", "wins", 0))


func save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("best", "time", best["time"])
	cfg.set_value("best", "kills", best["kills"])
	cfg.set_value("best", "level", best["level"])
	cfg.set_value("best", "wins", best["wins"])
	cfg.save(SAVE_PATH)
