class_name GameContentData
extends Resource
# The content catalog: every authored definition in one place, plus the
# validation that keeps broken references from reaching a run. Legacy
# *_dictionary() adapters feed the parts of the game still written against
# the old const tables.

@export var weapons: Array[Resource] = []
@export var passives: Array[Resource] = []
@export var characters: Array[Resource] = []
@export var enemies: Array[Resource] = []
@export var bosses: Array[Resource] = []
@export var stages: Array[Resource] = []
@export var relics: Array[Resource] = []
@export var meta_upgrades: Array[Resource] = []

# Wider than any one stage needs; a stage timeline lives inside this window.
const STAGE_LENGTH := 300.0
const MIN_WARN := 0.65
# Shared with main.gd's MAX_HAZARDS: a budget above it could never be honoured.
const HAZARD_CEILING := 90

var _index := {}


func _lookup(kind: String, list: Array, id: String) -> Resource:
	if not _index.has(kind):
		var m := {}
		for r in list:
			if r != null and r.get("id") != null:
				m[String(r.get("id"))] = r
		_index[kind] = m
	return _index[kind].get(id)


func weapon(id: String) -> WeaponData:
	return _lookup("weapon", weapons, id) as WeaponData


func passive(id: String) -> PassiveData:
	return _lookup("passive", passives, id) as PassiveData


func character(id: String) -> CharacterData:
	return _lookup("character", characters, id) as CharacterData


func enemy(id: String) -> EnemyData:
	return _lookup("enemy", enemies, id) as EnemyData


func boss(id: String) -> BossData:
	return _lookup("boss", bosses, id) as BossData


func stage(id: String) -> StageData:
	return _lookup("stage", stages, id) as StageData


func relic(id: String) -> RelicData:
	return _lookup("relic", relics, id) as RelicData


func stage_at(i: int) -> StageData:
	if stages.is_empty():
		return null
	return stages[clampi(i, 0, stages.size() - 1)] as StageData


# --- legacy adapters -----------------------------------------------------

func weapon_dictionary() -> Dictionary:
	var result := {}
	for item in weapons:
		var w := item as WeaponData
		if w != null:
			result[String(w.id)] = w.to_legacy_weapon()
	return result


func evolution_dictionary() -> Dictionary:
	var result := {}
	for item in weapons:
		var w := item as WeaponData
		if w != null:
			result[String(w.id)] = w.to_legacy_evolution()
	return result


func passive_dictionary() -> Dictionary:
	var result := {}
	for item in passives:
		var p := item as PassiveData
		if p != null:
			result[String(p.id)] = p.to_legacy_dictionary()
	return result


func character_dictionaries() -> Array:
	var out: Array = []
	for item in characters:
		var c := item as CharacterData
		if c != null:
			out.append(c.to_legacy_dictionary())
	return out


func stage_dictionaries() -> Array:
	var out: Array = []
	for item in stages:
		var s := item as StageData
		if s != null:
			out.append(s.to_legacy_dictionary())
	return out


func enemy_dictionary() -> Dictionary:
	var out := {}
	for item in enemies:
		var e := item as EnemyData
		if e != null:
			out[String(e.id)] = e.to_legacy_dictionary()
	return out


func meta_track_dictionaries() -> Array:
	var out: Array = []
	for item in meta_upgrades:
		var m := item as MetaUpgradeData
		if m != null:
			out.append(m.to_legacy_dictionary())
	return out


func meta_bonus_dictionary() -> Dictionary:
	var out := {}
	for item in meta_upgrades:
		var m := item as MetaUpgradeData
		if m != null:
			out[String(m.id)] = m.per_rank
	return out


# --- validation ----------------------------------------------------------

func _ids(list: Array, kind: String, script_class: String, errors: PackedStringArray) -> Dictionary:
	var seen := {}
	for item in list:
		if item == null or not item.is_class("Resource"):
			errors.append("%s catalog has an empty entry." % kind)
			continue
		var sc: Script = item.get_script()
		if sc == null or sc.get_global_name() != script_class:
			errors.append("%s catalog holds a non-%s entry." % [kind, script_class])
			continue
		var id := String(item.get("id"))
		if id.is_empty():
			errors.append("A %s is missing its id." % kind)
		elif seen.has(id):
			errors.append("Duplicate %s id: %s" % [kind, id])
		seen[id] = item
	return seen


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var weapon_ids := _ids(weapons, "weapon", "WeaponData", errors)
	var passive_ids := _ids(passives, "passive", "PassiveData", errors)
	var char_ids := _ids(characters, "character", "CharacterData", errors)
	var enemy_ids := _ids(enemies, "enemy", "EnemyData", errors)
	var boss_ids := _ids(bosses, "boss", "BossData", errors)
	_ids(stages, "stage", "StageData", errors)
	_ids(relics, "relic", "RelicData", errors)
	_ids(meta_upgrades, "meta upgrade", "MetaUpgradeData", errors)

	for id in weapon_ids:
		var w: WeaponData = weapon_ids[id]
		if not passive_ids.has(String(w.evolution_passive_id)):
			errors.append("Weapon %s requires unknown passive %s." % [id, w.evolution_passive_id])
		if w.max_level < 1:
			errors.append("Weapon %s has max level below 1." % id)

	for id in char_ids:
		var c: CharacterData = char_ids[id]
		if not weapon_ids.has(String(c.starting_weapon)):
			errors.append("Character %s starts with unknown weapon %s." % [id, c.starting_weapon])
		if c.base_hp <= 0.0 or c.speed_mult <= 0.0 or c.damage_mult <= 0.0:
			errors.append("Character %s has a non-positive stat." % id)
		if not ["default", "shards", "relic"].has(c.unlock_rule):
			errors.append("Character %s has unknown unlock rule %s." % [id, c.unlock_rule])

	for id in enemy_ids:
		var e: EnemyData = enemy_ids[id]
		if e.base_hp <= 0.0 or e.radius <= 0.0 or e.speed < 0.0 or e.base_damage < 0.0:
			errors.append("Enemy %s has an invalid stat range." % id)
		if not ["normal", "resist", "ignore"].has(e.water_response):
			errors.append("Enemy %s has unknown water response %s." % [id, e.water_response])

	for id in boss_ids:
		_validate_boss(boss_ids[id], enemy_ids, errors)

	for item in stages:
		var s := item as StageData
		if s != null:
			_validate_stage(s, enemy_ids, boss_ids, weapon_ids, errors)

	for item in relics:
		var r := item as RelicData
		if r == null:
			continue
		if r.description.is_empty():
			errors.append("Relic %s has no description." % r.id)
		if r.tags.is_empty():
			errors.append("Relic %s has no tags." % r.id)
		for w in r.requires_weapons:
			if not weapon_ids.has(w):
				errors.append("Relic %s requires unknown weapon %s." % [r.id, w])
		for k in r.modifiers:
			if not GameModifiers.KNOWN_STATS.has(String(k)):
				errors.append("Relic %s modifies unknown stat %s." % [r.id, k])

	for item in meta_upgrades:
		var m := item as MetaUpgradeData
		if m == null:
			continue
		if m.costs.size() != m.max_rank:
			errors.append("Meta upgrade %s lists %d costs for %d ranks." % [m.id, m.costs.size(), m.max_rank])
		for cost in m.costs:
			if cost <= 0:
				errors.append("Meta upgrade %s has a non-positive cost." % m.id)
		if m.hook.is_empty():
			errors.append("Meta upgrade %s has no behaviour hook." % m.id)
	return errors


func _validate_boss(b: BossData, enemy_ids: Dictionary, errors: PackedStringArray) -> void:
	var id := String(b.id)
	if not enemy_ids.has(String(b.base_enemy)):
		errors.append("Boss %s uses unknown body %s." % [id, b.base_enemy])
	if not enemy_ids.has(String(b.summon_enemy)):
		errors.append("Boss %s summons unknown enemy %s." % [id, b.summon_enemy])
	if b.summon_count < 0 or b.summon_count > 6 or b.summon_interval <= 0.0:
		errors.append("Boss %s has an unbounded summon." % id)
	if b.max_hazards <= 0 or b.max_hazards > HAZARD_CEILING:
		errors.append("Boss %s hazard budget %d is out of range." % [id, b.max_hazards])
	if b.min_warn < MIN_WARN:
		errors.append("Boss %s min warning %.2f is below %.2f." % [id, b.min_warn, MIN_WARN])
	if b.cast_gap <= 0.0 or b.min_cast_gap <= 0.0 or b.min_cast_gap > b.cast_gap:
		errors.append("Boss %s has invalid cast gaps." % id)
	if b.legacy:
		return
	if b.phases.size() < 2:
		errors.append("Boss %s needs at least two phases." % id)
	var prev := 2.0
	for i in b.phases.size():
		var ph := b.phases[i] as BossPhaseData
		if ph == null:
			errors.append("Boss %s phase %d is not BossPhaseData." % [id, i + 1])
			continue
		if i == 0 and not is_equal_approx(ph.threshold, 1.0):
			errors.append("Boss %s phase 1 must start at full health." % id)
		if ph.threshold <= 0.0 or ph.threshold > 1.0 or ph.threshold >= prev:
			errors.append("Boss %s phase %d threshold %.2f is invalid." % [id, i + 1, ph.threshold])
		prev = ph.threshold
		if ph.attacks.is_empty():
			errors.append("Boss %s phase %d has no attacks." % [id, i + 1])
		if ph.cadence <= 0.0:
			errors.append("Boss %s phase %d has non-positive cadence." % [id, i + 1])
	var n_attacks := 0
	var moving := false
	var positional := false
	for a in b.all_attacks():
		var ad := a as BossAttackData
		if ad == null:
			errors.append("Boss %s has a non-BossAttackData attack." % id)
			continue
		if ad.impl == null:
			errors.append("Boss %s attack %s has no implementation." % [id, ad.id])
		if ad.cooldown < 0.0 or ad.budget_cost < 0 or ad.weight < 0.0:
			errors.append("Boss %s attack %s has a negative value." % [id, ad.id])
		if not ad.passive:
			n_attacks += 1
			if ad.warn < b.min_warn:
				errors.append("Boss %s attack %s warns for %.2fs, under %.2fs." % [id, ad.id, ad.warn, b.min_warn])
			if ad.budget_cost > b.max_hazards:
				errors.append("Boss %s attack %s alone exceeds the hazard budget." % [id, ad.id])
		moving = moving or ad.movement_pressure
		positional = positional or ad.positional
	if n_attacks < 3:
		errors.append("Boss %s has %d attacks; it needs at least three." % [id, n_attacks])
	if not moving:
		errors.append("Boss %s has no movement-pressure attack." % id)
	if not positional:
		errors.append("Boss %s has no positional attack." % id)


func _validate_stage(s: StageData, enemy_ids: Dictionary, boss_ids: Dictionary,
		weapon_ids: Dictionary, errors: PackedStringArray) -> void:
	var id := String(s.id)
	if s.enemy_pool.is_empty():
		errors.append("Stage %s has an empty enemy pool." % id)
	for e in s.enemy_pool:
		if not enemy_ids.has(e):
			errors.append("Stage %s pool names unknown enemy %s." % [id, e])
	var b := s.boss_data()
	if b == null:
		errors.append("Stage %s has no boss." % id)
	elif not boss_ids.has(String(b.id)):
		errors.append("Stage %s boss %s is not in the catalog." % [id, b.id])
	for w in s.relic_weapons:
		if not weapon_ids.has(w):
			errors.append("Stage %s hides relics for unknown weapon %s." % [id, w])
	for item in s.special_enemies:
		var sp := item as StageSpawnData
		if sp == null:
			errors.append("Stage %s has a non-StageSpawnData special spawn." % id)
			continue
		if not enemy_ids.has(String(sp.enemy_id)):
			errors.append("Stage %s spawns unknown enemy %s." % [id, sp.enemy_id])
		if sp.interval <= 0.0 or sp.max_alive <= 0 or sp.max_alive > 8:
			errors.append("Stage %s spawn of %s is unbounded." % [id, sp.enemy_id])
		if sp.start_time < 0.0 or sp.end_time <= sp.start_time:
			errors.append("Stage %s spawn of %s has an empty window." % [id, sp.enemy_id])
	var rd := s.rule_data()
	if rd != null:
		if rd.impl == null:
			errors.append("Stage %s rule has no implementation." % id)
		if rd.max_hazards <= 0 or rd.max_hazards > HAZARD_CEILING:
			errors.append("Stage %s rule hazard cap %d is out of range." % [id, rd.max_hazards])
		if rd.warn_time < MIN_WARN:
			errors.append("Stage %s rule warns for %.2fs, under %.2fs." % [id, rd.warn_time, MIN_WARN])
		if rd.min_safe_fraction <= 0.0 or rd.min_safe_fraction >= 1.0:
			errors.append("Stage %s rule safe fraction is out of range." % id)
		var prev := -1.0
		for t in rd.phase_times:
			if t <= prev or t < 0.0 or t > STAGE_LENGTH:
				errors.append("Stage %s rule timeline is not increasing within the stage." % id)
			prev = t
		if rd.intro.is_empty() or rd.intro.length() > 48:
			errors.append("Stage %s rule intro must be one short sentence." % id)
	var seen := {}
	var last := -1.0
	for item in s.events:
		var ev := item as StageEventData
		if ev == null:
			errors.append("Stage %s has a non-StageEventData event." % id)
			continue
		if seen.has(String(ev.id)):
			errors.append("Stage %s repeats event %s." % [id, ev.id])
		seen[String(ev.id)] = true
		if ev.time < 0.0 or ev.time >= STAGE_LENGTH or ev.time < last:
			errors.append("Stage %s event %s is out of order or outside the stage." % [id, ev.id])
		if ev.duration <= 0.0 or ev.time + ev.duration > STAGE_LENGTH + 0.01:
			errors.append("Stage %s event %s would run past the boss." % [id, ev.id])
		if ev.banner.length() > 28:
			errors.append("Stage %s event %s banner is too long for mobile." % [id, ev.id])
		last = ev.time
