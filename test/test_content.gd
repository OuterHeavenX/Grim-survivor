extends Node
# Content catalog, legacy adapters, save migration and settings persistence.
# Mutates the shared save file, so it snapshots the file's bytes first and
# restores them before quitting.

const SAVE := "user://grim_survivors.cfg"

var _fails := 0
var _gm = null
var _main = null
var _snapshot := PackedByteArray()
var _had_save := false


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		print("FAIL: ", name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_gm = get_node("/root/GameManager")
	_main = get_tree().get_first_node_in_group("main")
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save:
		_snapshot = FileAccess.get_file_as_bytes(SAVE)
	_catalog()
	_broken_catalogs()
	_adapters()
	_save_migration()
	_settings()
	_restore()
	print("CONTENT TEST DONE fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _restore() -> void:
	if _had_save:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(_snapshot)
		f.close()
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_gm.load_meta()
	_gm.load_best()
	_gm.load_settings()


func _catalog() -> void:
	var c: GameContentData = _gm.CONTENT
	var errs := c.validation_errors()
	for e in errs:
		print("  content error: ", e)
	_check(errs.is_empty(), "shipped catalog validates cleanly")
	_check(c.characters.size() == 13, "13 characters as resources")
	_check(c.stages.size() == 8, "8 stages as resources")
	_check(c.relics.size() >= 14 and c.relics.size() <= 21, "14-21 relics, got %d" % c.relics.size())
	_check(c.meta_upgrades.size() == 6, "6 meta upgrades as resources")
	for id in ["cultist_healer", "necromancer", "shield_bearer", "ranged_cultist", "burrower",
			"banner_carrier", "xp_leech", "mimic"]:
		var e := c.enemy(id)
		_check(e != null and e.behavior != null, "enemy role %s has data and behaviour" % id)
	# Every scoped stage has a rule, an event and a non-legacy boss.
	for sid in ["ashen_hollow", "weeping_marsh", "throne_of_cinders", "bone_desert",
			"sunken_road", "drowned_reach", "last_bastion"]:
		var s := c.stage(sid)
		_check(s != null, "stage %s exists" % sid)
		if s == null:
			continue
		_check(s.rule_data() != null and s.rule_data().impl != null, "%s has a stage rule" % sid)
		_check(not s.events.is_empty(), "%s has a scheduled event" % sid)
		var b := s.boss_data()
		_check(b != null and not b.legacy and b.phases.size() >= 2, "%s boss has 2+ phases" % sid)
		_check(not s.special_enemies.is_empty(), "%s fields a new enemy role" % sid)
		# At least two relics lean towards each stage.
		var leaning := 0
		for item in c.relics:
			var r := item as RelicData
			for t in r.tags:
				if s.relic_tags.has(t):
					leaning += 1
					break
		_check(leaning >= 2, "%s has 2+ associated relics, got %d" % [sid, leaning])
	# Each stage's boss is unique.
	var names := {}
	for item in c.stages:
		names[(item as StageData).boss_data().display_name] = true
	_check(names.size() == 8, "every stage has its own boss")


const BROKEN_CASES := ["duplicate id", "empty id", "empty enemy pool", "unknown pool enemy",
	"character without weapon", "broken evolution", "bad phase thresholds", "negative cooldown",
	"short warning", "unbounded spawn", "bad schedule", "missing boss", "unknown relic stat"]


func _break(c: GameContentData, base: GameContentData, name: String) -> void:
	match name:
		"duplicate id":
			c.enemies.append(base.enemy("skeleton"))
		"empty id":
			c.enemies.append(EnemyData.new())
		"empty enemy pool":
			var s: StageData = base.stage("ashen_hollow").duplicate()
			s.id = &"broken_stage"
			s.enemy_pool = PackedStringArray()
			c.stages.append(s)
		"unknown pool enemy":
			var s2: StageData = base.stage("ashen_hollow").duplicate()
			s2.id = &"broken_stage2"
			s2.enemy_pool = PackedStringArray(["nobody"])
			c.stages.append(s2)
		"character without weapon":
			var ch: CharacterData = base.character("rogue").duplicate()
			ch.id = &"ghost"
			ch.starting_weapon = &"nothing"
			c.characters.append(ch)
		"broken evolution":
			var w: WeaponData = base.weapon("dagger").duplicate()
			w.id = &"dagger2"
			w.evolution_passive_id = &"missing"
			c.weapons.append(w)
		"bad phase thresholds":
			var b: BossData = base.boss("herald_of_vorgath").duplicate(true)
			b.id = &"broken_boss"
			(b.phases[1] as BossPhaseData).threshold = 1.2
			c.bosses.append(b)
		"negative cooldown":
			var b2: BossData = base.boss("maw_of_the_mire").duplicate(true)
			b2.id = &"broken_boss2"
			((b2.phases[0] as BossPhaseData).attacks[0] as BossAttackData).cooldown = -1.0
			c.bosses.append(b2)
		"short warning":
			var b3: BossData = base.boss("the_cinder_king").duplicate(true)
			b3.id = &"broken_boss3"
			((b3.phases[0] as BossPhaseData).attacks[0] as BossAttackData).warn = 0.2
			c.bosses.append(b3)
		"unbounded spawn":
			var s3: StageData = base.stage("weeping_marsh").duplicate(true)
			s3.id = &"broken_stage3"
			(s3.special_enemies[0] as StageSpawnData).max_alive = 0
			c.stages.append(s3)
		"bad schedule":
			var s4: StageData = base.stage("bone_desert").duplicate(true)
			s4.id = &"broken_stage4"
			(s4.events[0] as StageEventData).time = 400.0
			c.stages.append(s4)
		"missing boss":
			var s5: StageData = base.stage("bone_desert").duplicate()
			s5.id = &"broken_stage5"
			s5.boss = null
			c.stages.append(s5)
		"unknown relic stat":
			var r: RelicData = base.relic("kings_brand").duplicate()
			r.id = &"broken_relic"
			r.modifiers = {"luck": 2.0}
			c.relics.append(r)


func _broken_catalogs() -> void:
	# The validator must catch each class of authoring mistake.
	var base: GameContentData = _gm.CONTENT
	for name in BROKEN_CASES:
		var c := GameContentData.new()
		for k in ["weapons", "passives", "characters", "enemies", "bosses", "stages", "relics", "meta_upgrades"]:
			(c.get(k) as Array).assign(base.get(k))
		_break(c, base, name)
		_check(not c.validation_errors().is_empty(), "validator catches: " + name)


func _adapters() -> void:
	# The dictionary views must say exactly what the resources say.
	var c: GameContentData = _gm.CONTENT
	_check(_gm.CHAR_CLASSES.size() == c.characters.size(), "CHAR_CLASSES adapter size")
	var rogue: Dictionary = _gm.class_by_id("rogue")
	_check(int(rogue["cost"]) == 0 and str(rogue["weapon"]) == "dagger", "rogue adapter")
	_check(int(_gm.class_by_id("flame")["cost"]) == -1, "relic characters keep cost -1")
	_check(str(_gm.STAGES[1]["boss"]) == "maw", "stage adapter keeps boss body id")
	_check(str(_gm.STAGES[1]["boss_name"]) == "MAW OF THE MIRE", "stage adapter keeps boss name")
	var E = load("res://src/enemy.gd")
	_check(E.TYPES.has("skeleton") and is_equal_approx(float(E.TYPES["skeleton"]["hp"]), 22.0),
		"enemy TYPES built from EnemyData")
	_check(E.TYPES.size() == c.enemies.size(), "every EnemyData appears in TYPES")
	_check(_gm.META_TRACKS.size() == 6 and is_equal_approx(float(_gm.META_BONUS["edge"]), 6.0),
		"meta tracks adapter")


func _write_cfg(sections: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for sec in sections:
		for k in sections[sec]:
			cfg.set_value(sec, k, sections[sec][k])
	cfg.save(SAVE)


func _save_migration() -> void:
	# A save written by the build before this expansion: no settings, no
	# relic discovery, no version, plus a key from some future build.
	_write_cfg({
		"meta": {"shards": 77, "rank_edge": 2, "char_rogue": 1, "char_shadow": 1,
			"char_selected": "shadow", "campaign_unlocked": 3, "campaign_mode": 1,
			"loadout": "dagger,frost"},
		"best": {"time": 120.0, "kills": 50, "level": 9, "wins": 1},
		"audio": {"muted": false},
		"future": {"mystery": "keep me"},
	})
	_gm.load_meta()
	_gm.load_best()
	_gm.load_settings()
	_check(_gm.shards == 77, "legacy save: shards load")
	_check(_gm.meta_rank("edge") == 2, "legacy save: meta ranks load")
	_check(_gm.selected_class == "shadow", "legacy save: selected class loads")
	_check(_gm.campaign_unlocked == 3 and _gm.campaign, "legacy save: campaign loads")
	_check(not _gm.campaign_crowned, "legacy save: crown defaults off")
	_check(_gm.relics_discovered.is_empty(), "legacy save: no relics discovered by default")
	_check(_gm.is_relic_discovered("ember_heart"), "default relics are discovered")
	_check(not _gm.is_relic_discovered("sovereign_seal"), "legendary relic starts undiscovered")
	_check(float(_gm.setting("shake")) == 1.0 and bool(_gm.setting("flashes")),
		"legacy save: settings default")
	# Saving must keep unknown and other-system keys.
	_gm.relics_discovered["sovereign_seal"] = true
	_gm.save_meta()
	_gm.save_settings()
	_gm.save_best()
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	_check(str(cfg.get_value("future", "mystery", "")) == "keep me", "unknown save keys preserved")
	_check(cfg.has_section_key("audio", "muted"), "audio section preserved")
	_check(int(cfg.get_value("meta", "save_version", 0)) == _gm.SAVE_VERSION, "save version written")
	_gm.relics_discovered = {}
	_gm.load_meta()
	_check(_gm.is_relic_discovered("sovereign_seal"), "relic discovery round-trips")
	# A corrupted settings value falls back instead of breaking.
	cfg.set_value("settings", "shake", "loud")
	cfg.set_value("settings", "hazard_opacity", 9.0)
	cfg.save(SAVE)
	_gm.load_settings()
	_check(float(_gm.setting("shake")) == 1.0, "bad settings type falls back to default")
	_check(float(_gm.setting("hazard_opacity")) <= 1.5, "settings values are clamped")


func _settings() -> void:
	# Settings screen: every row toggles and persists; buttons take focus so
	# controller/keyboard navigation works.
	var ui = _main.settings_ui
	ui.show_screen()
	_check(ui.visible, "settings screen opens")
	var focused = get_viewport().gui_get_focus_owner()
	_check(focused is Button, "settings screen focuses a button for controllers")
	var before := bool(_gm.setting("high_contrast"))
	(ui.buttons["high_contrast"] as Button).pressed.emit()
	_check(bool(_gm.setting("high_contrast")) != before, "toggle flips a setting")
	_gm.load_settings()
	_check(bool(_gm.setting("high_contrast")) != before, "setting persists to the save")
	var s0 := float(_gm.setting("shake"))
	(ui.buttons["shake"] as Button).pressed.emit()
	_check(float(_gm.setting("shake")) != s0, "shake cycles")
	_gm.set_setting("shake", 0.0)
	var jm = get_node("/root/JuiceMan")
	jm.trauma = 0.0
	jm.add_trauma(0.5)
	_check(jm.trauma == 0.0, "shake off means no trauma")
	_gm.set_setting("shake", 1.0)
	_gm.set_setting("damage_numbers", false)
	ui.hide_screen()
	_check(not ui.visible, "settings screen closes")
	for b in ui.buttons.values():
		_check((b as Button).custom_minimum_size.y >= 72.0, "settings rows are touch-sized")
