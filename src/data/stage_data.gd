class_name StageData
extends Resource

@export var id: StringName
@export var display_name := ""
@export var theme := "ashen"
@export var boss: Resource
@export var enemy_pool: PackedStringArray = PackedStringArray()
@export var special_enemies: Array[Resource] = []
# Weapons whose unlock relics hide here (see the GameManager relic flow).
@export var relic_weapons: PackedStringArray = PackedStringArray()
# Tags that weight run-relic rewards after this stage's boss.
@export var relic_tags: PackedStringArray = PackedStringArray()
@export var rule: Resource
@export var events: Array[Resource] = []
@export var music_profile := "default"
@export var fog_tint := Color(0.35, 0.45, 0.65)
@export var boss_aura := Color(1, 0.5, 0.2)


func boss_data() -> BossData:
	return boss as BossData


func rule_data() -> StageRuleData:
	return rule as StageRuleData


func to_legacy_dictionary() -> Dictionary:
	var b := boss_data()
	return {
		"id": String(id), "name": display_name,
		"boss": String(b.base_enemy) if b else "",
		"boss_name": b.display_name if b else "",
		"boss_aura": boss_aura, "theme": theme,
		"relics": Array(relic_weapons), "pool": Array(enemy_pool),
	}
