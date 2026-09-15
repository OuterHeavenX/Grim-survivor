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

const WEAPONS := {
	"dagger": {
		"name": "Dagger Throw", "max": 5,
		"desc": "Hurls daggers at the nearest foe.",
		"up": "More daggers, more damage.",
	},
	"fireball": {
		"name": "Fireball", "max": 5,
		"desc": "Lobs an exploding fireball at the horde.",
		"up": "Bigger blast, more damage.",
	},
	"frost": {
		"name": "Frost Nova", "max": 5,
		"desc": "A freezing ring that chills nearby foes.",
		"up": "Wider ring, longer chill.",
	},
	"blades": {
		"name": "Spinning Blades", "max": 5,
		"desc": "Blades orbit you, shredding on contact.",
		"up": "More blades, more damage.",
	},
	"lightning": {
		"name": "Chain Lightning", "max": 5,
		"desc": "Lightning arcs between nearby foes.",
		"up": "More chains, more damage.",
	},
	"scythe": {
		"name": "Scythe Whirl", "max": 5,
		"desc": "A giant spectral scythe orbits you, dragging foes inward.",
		"up": "Bigger scythe, harder hits, stronger pull.",
	},
	"raven": {
		"name": "Raven Swarm", "max": 5,
		"desc": "Spectral ravens hunt down your foes.",
		"up": "More ravens, more pierce, faster.",
	},
	"lance": {
		"name": "Bone Lance", "max": 5,
		"desc": "Hurls heavy spears that pierce through whole lines of foes.",
		"up": "More damage, more pierce.",
	},
	"miasma": {
		"name": "Plague Miasma", "max": 5,
		"desc": "Drops a toxic cloud on the horde that melts foes over time.",
		"up": "Bigger cloud, longer linger, harder ticks.",
	},
	"comet": {
		"name": "Comet Fall", "max": 5,
		"desc": "Calls down meteors on random foes after a warning flash.",
		"up": "More meteors, bigger blasts.",
	},
	"sdagger": {
		"name": "Shadow Daggers", "max": 5,
		"desc": "Throws fast shadow daggers at the nearest foe.",
		"up": "More daggers, faster, harder hits.",
	},
	"ember": {
		"name": "Ember Volley", "max": 5,
		"desc": "Lobs volatile embers that explode on impact.",
		"up": "More embers, bigger blasts.",
	},
	"bulwark": {
		"name": "Bulwark Slam", "max": 5,
		"desc": "A heavy shield-slam arc in your path. Huge damage, huge knockback.",
		"up": "Wider arc, bigger hits, harder shove.",
	},
}

const PASSIVES := {
	"might": {"name": "Might", "max": 5, "desc": "+12% all damage."},
	"haste": {"name": "Swiftness", "max": 5, "desc": "Attack 8% faster."},
	"boots": {"name": "Swift Boots", "max": 5, "desc": "+8% move speed."},
	"vitality": {"name": "Vitality", "max": 5, "desc": "+20 max HP and heal 20."},
	"magnet": {"name": "Greed Charm", "max": 5, "desc": "+40% pickup radius."},
	"siphon": {"name": "Soul Siphon", "max": 5, "desc": "Killing a foe restores 2 HP."},
	"armor": {"name": "Stone Skin", "max": 5, "desc": "Block 2 damage from every hit."},
}



const EVOLUTIONS := {
	"dagger": {"passive": "might", "name": "Fang Barrage",
		"desc": "Hurls five massive spectral fangs that shred whole lines."},
	"fireball": {"passive": "might", "name": "Hellfire Bloom",
		"desc": "A cataclysmic blast with a huge burning radius."},
	"frost": {"passive": "haste", "name": "Glacial Tempest",
		"desc": "A vast freezing storm that never lets foes escape."},
	"blades": {"passive": "haste", "name": "Cyclone Shred",
		"desc": "A screaming cyclone of blades orbiting you."},
	"lightning": {"passive": "magnet", "name": "Storm Sovereign",
		"desc": "Lightning hunts every nearby foe at once."},
	"scythe": {"passive": "siphon", "name": "Reaper's Due",
		"desc": "A colossal scythe that harvests the horde's souls."},
	"raven": {"passive": "boots", "name": "Murder Unkind",
		"desc": "A relentless flock of spectral hunters."},
	"lance": {"passive": "armor", "name": "Impaler",
		"desc": "A siege spear that skewers everything in its path."},
	"miasma": {"passive": "haste", "name": "Blight Epidemic",
		"desc": "A vast plague cloud that consumes the horde."},
	"comet": {"passive": "might", "name": "Starfall",
		"desc": "The sky itself falls on your enemies."},
	"sdagger": {"passive": "haste", "name": "Umbral Fan",
		"desc": "A storm of void-forged blades."},
	"ember": {"passive": "might", "name": "Inferno Requiem",
		"desc": "The sky rains burning ruin."},
	"bulwark": {"passive": "armor", "name": "Bastion's Wrath",
		"desc": "The earth itself recoils from your slam."},
}



const CHAR_CLASSES := [
	{
		"id": "rogue", "name": "Hooded Rogue", "cost": 0,
		"flavor": "A balanced survivor of the Hollow.",
		"hp": 100.0, "dmg": 1.0, "speed": 1.0, "magnet": 1.0, "xp": 1.0,
		"weapon": "dagger",
		"palette": {
			"cloak": Color(0.07, 0.08, 0.15), "tunic": Color(0.32, 0.18, 0.48),
			"lining": Color(0.55, 0.08, 0.14), "eyes": Color(1.0, 0.25, 0.25),
		},
	},
	{
		"id": "shadow", "name": "Shadowblade", "cost": 100,
		"flavor": "Fast and fragile. Daggers from the dark.",
		"hp": 80.0, "dmg": 0.85, "speed": 1.25, "magnet": 1.0, "xp": 1.1,
		"weapon": "sdagger",
		"palette": {
			"cloak": Color(0.02, 0.03, 0.08), "tunic": Color(0.08, 0.14, 0.3),
			"lining": Color(0.25, 0.35, 0.7), "eyes": Color(0.55, 0.75, 1.0),
		},
	},
	{
		"id": "pyro", "name": "Pyromancer", "cost": 200,
		"flavor": "Frail, but everything burns.",
		"hp": 75.0, "dmg": 1.35, "speed": 0.95, "magnet": 1.0, "xp": 1.0,
		"weapon": "ember",
		"palette": {
			"cloak": Color(0.16, 0.05, 0.04), "tunic": Color(0.55, 0.16, 0.05),
			"lining": Color(0.95, 0.45, 0.1), "eyes": Color(1.0, 0.65, 0.15),
		},
	},
	{
		"id": "warden", "name": "Iron Warden", "cost": 300,
		"flavor": "A walking wall of steel.",
		"hp": 160.0, "dmg": 1.0, "speed": 0.85, "magnet": 1.2, "xp": 0.95,
		"weapon": "bulwark",
		"palette": {
			"cloak": Color(0.1, 0.11, 0.13), "tunic": Color(0.38, 0.38, 0.42),
			"lining": Color(0.85, 0.65, 0.25), "eyes": Color(1.0, 0.85, 0.4),
		},
	},
	{
		"id": "flame", "name": "Flamecaller", "cost": -1,
		"flavor": "Answers the horde with falling fire.",
		"hp": 85.0, "dmg": 1.1, "speed": 0.95, "magnet": 1.0, "xp": 1.0,
		"weapon": "fireball",
		"palette": {
			"cloak": Color(0.16, 0.06, 0.04), "tunic": Color(0.6, 0.22, 0.08),
			"lining": Color(0.95, 0.5, 0.12), "eyes": Color(1.0, 0.7, 0.2),
		},
	},
	{
		"id": "rime", "name": "Rimewarden", "cost": -1,
		"flavor": "Stills the marsh with killing cold.",
		"hp": 110.0, "dmg": 0.9, "speed": 0.92, "magnet": 1.1, "xp": 1.0,
		"weapon": "frost",
		"palette": {
			"cloak": Color(0.05, 0.1, 0.16), "tunic": Color(0.2, 0.45, 0.6),
			"lining": Color(0.6, 0.9, 1.0), "eyes": Color(0.7, 0.95, 1.0),
		},
	},
	{
		"id": "dancer", "name": "Bladedancer", "cost": -1,
		"flavor": "Never still, never unarmed.",
		"hp": 85.0, "dmg": 0.95, "speed": 1.2, "magnet": 1.0, "xp": 1.0,
		"weapon": "blades",
		"palette": {
			"cloak": Color(0.08, 0.08, 0.1), "tunic": Color(0.45, 0.45, 0.5),
			"lining": Color(0.85, 0.85, 0.9), "eyes": Color(0.9, 0.95, 1.0),
		},
	},
	{
		"id": "storm", "name": "Stormbound", "cost": -1,
		"flavor": "The arc finds every throat in turn.",
		"hp": 90.0, "dmg": 1.0, "speed": 1.05, "magnet": 1.0, "xp": 1.1,
		"weapon": "lightning",
		"palette": {
			"cloak": Color(0.06, 0.07, 0.14), "tunic": Color(0.3, 0.32, 0.7),
			"lining": Color(0.7, 0.8, 1.0), "eyes": Color(0.85, 0.9, 1.0),
		},
	},
	{
		"id": "reaper", "name": "The Reaper", "cost": -1,
		"flavor": "Harvests in a wide, patient circle.",
		"hp": 105.0, "dmg": 1.05, "speed": 0.9, "magnet": 1.0, "xp": 1.0,
		"weapon": "scythe",
		"palette": {
			"cloak": Color(0.04, 0.05, 0.06), "tunic": Color(0.18, 0.2, 0.22),
			"lining": Color(0.5, 0.6, 0.55), "eyes": Color(0.6, 1.0, 0.7),
		},
	},
	{
		"id": "ravenmark", "name": "Ravenmark", "cost": -1,
		"flavor": "Sends the flock ahead to feed.",
		"hp": 85.0, "dmg": 0.95, "speed": 1.1, "magnet": 1.2, "xp": 1.0,
		"weapon": "raven",
		"palette": {
			"cloak": Color(0.05, 0.05, 0.08), "tunic": Color(0.22, 0.2, 0.3),
			"lining": Color(0.5, 0.45, 0.6), "eyes": Color(0.9, 0.85, 0.4),
		},
	},
	{
		"id": "bonewright", "name": "Bonewright", "cost": -1,
		"flavor": "Drives a spear through whole ranks.",
		"hp": 115.0, "dmg": 1.15, "speed": 0.88, "magnet": 0.95, "xp": 1.0,
		"weapon": "lance",
		"palette": {
			"cloak": Color(0.1, 0.09, 0.07), "tunic": Color(0.5, 0.46, 0.36),
			"lining": Color(0.85, 0.82, 0.7), "eyes": Color(1.0, 0.95, 0.75),
		},
	},
	{
		"id": "plague", "name": "Plaguebearer", "cost": -1,
		"flavor": "Leaves a trail the horde chokes on.",
		"hp": 100.0, "dmg": 0.9, "speed": 0.98, "magnet": 1.0, "xp": 1.15,
		"weapon": "miasma",
		"palette": {
			"cloak": Color(0.05, 0.1, 0.05), "tunic": Color(0.28, 0.45, 0.18),
			"lining": Color(0.6, 0.9, 0.3), "eyes": Color(0.8, 1.0, 0.4),
		},
	},
	{
		"id": "starcaller", "name": "Starcaller", "cost": -1,
		"flavor": "Marks the ground, then the sky answers.",
		"hp": 90.0, "dmg": 1.2, "speed": 0.95, "magnet": 1.0, "xp": 1.0,
		"weapon": "comet",
		"palette": {
			"cloak": Color(0.06, 0.05, 0.12), "tunic": Color(0.35, 0.25, 0.6),
			"lining": Color(0.8, 0.7, 1.0), "eyes": Color(1.0, 0.9, 0.6),
		},
	},
]



const STAGES := [
	{
		"name": "ASHEN HOLLOW", "boss": "herald", "boss_name": "HERALD OF VORGATH",
		"boss_aura": Color(0.55, 0.3, 1.0), "theme": "ashen",
		"relics": ["lance", "frost"],
		"pool": ["skeleton", "wisp", "husk"],
	},
	{
		"name": "THE WEEPING MARSH", "boss": "maw", "boss_name": "MAW OF THE MIRE",
		"boss_aura": Color(0.35, 1.0, 0.45), "theme": "marsh",
		"relics": ["sdagger", "miasma"],
		"pool": ["bogling", "wisp", "husk"],
	},
	{
		"name": "THRONE OF CINDERS", "boss": "cinderking", "boss_name": "THE CINDER KING",
		"boss_aura": Color(1.0, 0.45, 0.15), "theme": "cinder",
		"relics": ["ember", "fireball"],
		"pool": ["imp", "bogling", "husk"],
	},
	{
		"name": "THE BONE DESERT", "boss": "herald", "boss_name": "THE PALE HERALD",
		"boss_aura": Color(1.0, 0.85, 0.5), "theme": "desert",
		"relics": ["comet", "scythe"],
		"pool": ["skeleton", "imp", "mire"],
	},
	{
		"name": "ROTGROVE", "boss": "maw", "boss_name": "THE ROTGROVE MAW",
		"boss_aura": Color(0.5, 1.0, 0.35), "theme": "grove",
		"relics": ["raven", "blades"],
		"pool": ["bogling", "mire", "imp"],
	},
	{
		"name": "THE SUNKEN ROAD", "boss": "cinderking", "boss_name": "WARDEN OF THE ROAD",
		"boss_aura": Color(0.9, 0.5, 0.25), "theme": "barrens",
		"relics": ["bulwark", "lightning"],
		"pool": ["husk", "mire", "titan"],
	},
	{
		"name": "THE DROWNED REACH", "boss": "maw", "boss_name": "THE DROWNED MAW",
		"boss_aura": Color(0.4, 0.75, 1.0), "theme": "drowned",
		"relics": ["frost", "miasma"],
		"pool": ["mire", "wisp", "titan"],
	},
	{
		"name": "THE LAST BASTION", "boss": "cinderking", "boss_name": "THE ASHEN SOVEREIGN",
		"boss_aura": Color(1.0, 0.35, 0.12), "theme": "bastion",
		"relics": ["fireball", "comet"],
		"pool": ["titan", "imp", "mire"],
	},
]

const SAVE_PATH := "user://grim_survivors.cfg"


const META_TRACKS := [
	{"id": "edge", "name": "Sharpened Edge", "desc": "+6% damage per rank.",
		"costs": [10, 25, 50, 100, 180], "fmt": "+%d%% damage", "short": "+%d%%"},
	{"id": "vitality", "name": "Iron Vitality", "desc": "+12 max HP per rank.",
		"costs": [10, 25, 50, 100, 180], "fmt": "+%d max HP", "short": "+%d HP"},
	{"id": "boots", "name": "Swift Boots", "desc": "+4% move speed per rank.",
		"costs": [10, 25, 50, 100, 180], "fmt": "+%d%% move speed", "short": "+%d%%"},
	{"id": "greed", "name": "Greed Charm", "desc": "+8% pickup radius per rank.",
		"costs": [10, 25, 50, 100, 180], "fmt": "+%d%% pickup radius", "short": "+%d%%"},
	{"id": "wind", "name": "Second Wind", "desc": "+1 revive per run. Revive at 50% HP with a knockback nova.",
		"costs": [10, 25, 50, 100, 180], "fmt": "%d revive(s) per run", "short": "%d revive"},
	{"id": "scholar", "name": "Scholar's Mind", "desc": "+5% XP gain per rank.",
		"costs": [10, 25, 50, 100, 180], "fmt": "+%d%% XP gain", "short": "+%d%%"},
]
const META_BONUS := {
	"edge": 6.0, "vitality": 12.0, "boots": 4.0,
	"greed": 8.0, "wind": 1.0, "scholar": 5.0,
}

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_best()
	load_meta()


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


func is_evolved(id: String) -> bool:
	return bool(evolved.get(id, false))


func add_xp(v: int) -> void:
	if state != State.RUNNING and state != State.LEVELUP:
		return
	xp += int(round(float(v) * meta_xp_mult()))
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
	return (1.0 + 0.12 * float(passives.get("might", 0))) * meta_damage_mult()


func haste_mult() -> float:
	return pow(0.92, float(passives.get("haste", 0)))


func speed_mult() -> float:
	return (1.0 + 0.08 * float(passives.get("boots", 0))) * meta_speed_mult()


func magnet_mult() -> float:
	return (1.0 + 0.4 * float(passives.get("magnet", 0))) * meta_magnet_mult()


func siphon_heal() -> float:
	return 2.0 * float(passives.get("siphon", 0))


func armor_block() -> float:
	return 2.0 * float(passives.get("armor", 0))


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
