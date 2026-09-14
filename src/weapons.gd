extends Node


const ProjectileScript := preload("res://src/projectile.gd")

var player = null
var gm = null
var am = null
var timers := {}
var blades_root: Node2D
var scythe_root: Node2D

var facing := Vector2.RIGHT


func _ready() -> void:
	player = get_parent()
	gm = get_node("/root/GameManager")
	am = get_node("/root/AudioMan")
	blades_root = Node2D.new()
	blades_root.name = "Blades"
	player.add_child(blades_root)
	scythe_root = Node2D.new()
	scythe_root.name = "Scythe"
	player.add_child(scythe_root)
	for id in gm.weapons.keys():
		timers[id] = randf_range(0.1, 0.5)
	gm.weapons_changed.connect(_on_weapons_changed)
	_sync_blades()
	_sync_scythe()


func _on_weapons_changed() -> void:
	for id in gm.weapons.keys():
		if not timers.has(id):
			timers[id] = 0.1
	_sync_blades()
	_sync_scythe()


func _physics_process(delta: float) -> void:
	if not player.alive:
		return
	if player.move_vec.length() > 0.15:
		facing = player.move_vec.normalized()
	for id in gm.weapons.keys():
		var lvl := int(gm.weapons[id])
		if id == "blades" or id == "scythe":
			continue
		var t := float(timers.get(id, 0.0)) - delta
		if t <= 0.0:
			_fire(id, lvl)
			t = _cooldown(id) * gm.haste_mult()
		timers[id] = t


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func _nearest(from: Vector2, max_dist: float):
	var best = null
	var bd := max_dist
	for e in _enemies():
		var en = e
		var d := from.distance_to(en.global_position)
		if d < bd:
			bd = d
			best = en
	return best


func _nearest_except(from: Vector2, max_dist: float, skip: Dictionary):
	var best = null
	var bd := max_dist
	for e in _enemies():
		var en = e
		if skip.has(en.get_instance_id()):
			continue
		var d := from.distance_to(en.global_position)
		if d < bd:
			bd = d
			best = en
	return best


func _dmg(base: float) -> float:
	return base * gm.might_mult()


func _fire(id: String, lvl: int) -> void:
	match id:
		"dagger":
			_fire_dagger(lvl)
		"fireball":
			_fire_fireball(lvl)
		"frost":
			_fire_frost(lvl)
		"lightning":
			_fire_lightning(lvl)
		"raven":
			_fire_raven(lvl)
		"lance":
			_fire_lance(lvl)
		"miasma":
			_fire_miasma(lvl)
		"comet":
			_fire_comet(lvl)
		"sdagger":
			_fire_sdagger(lvl)
		"ember":
			_fire_ember(lvl)
		"bulwark":
			_fire_bulwark(lvl)


func _cooldown(id: String) -> float:
	match id:
		"dagger":
			return 0.95
		"fireball":
			return 2.3
		"frost":
			return 3.2
		"lightning":
			return 2.6
		"raven":
			return 3.0
		"lance":
			return 2.0
		"miasma":
			return 4.6
		"comet":
			return 3.4
		"sdagger":
			return 0.7
		"ember":
			return 2.0
		"bulwark":
			return 2.8
	return 1.0


func _main():
	return get_tree().get_first_node_in_group("main")


func _fire_dagger(lvl: int) -> void:
	var evo: bool = gm.is_evolved("dagger")
	var target = _nearest(player.global_position, 950.0)
	if target == null:
		return
	am.play_ranged("dagger_throw", -10.0, 0.95, 1.1)
	var n := 1 + lvl / 2 + (2 if evo else 0)
	var base_ang: float = (target.global_position - player.global_position).angle()
	for i in n:
		var p = ProjectileScript.new()
		p.setup("dagger", _dmg(11.0 * (1.0 + 0.3 * float(lvl - 1)) * (2.2 if evo else 1.0)), player.global_position)
		var ang := base_ang + (float(i) - float(n - 1) / 2.0) * 0.14
		p.set("vel", Vector2.from_angle(ang) * 640.0)
		p.set("pierce", 1 + lvl / 3 + (4 if evo else 0))
		p.set("evo", evo)
		p.set("life", 1.6)
		_main().run.add_child(p)


func _fire_fireball(lvl: int) -> void:
	var evo: bool = gm.is_evolved("fireball")
	var target = _nearest(player.global_position, 1000.0)
	am.play("dagger_throw", -14.0, 0.65)
	var n := 1 + (1 if lvl >= 3 else 0) + (1 if lvl >= 5 else 0) + (2 if evo else 0)
	for i in n:
		var aim := Vector2.from_angle(randf() * TAU)
		if target:
			aim = (target.global_position - player.global_position).normalized()
			aim = aim.rotated(randf_range(-0.15, 0.15) * float(i))
		var p = ProjectileScript.new()
		p.setup("fireball", _dmg(26.0 * (1.0 + 0.35 * float(lvl - 1)) * (2.0 if evo else 1.0)), player.global_position)
		p.set("vel", aim * 380.0)
		p.set("aoe", (105.0 + 18.0 * float(lvl)) * (1.8 if evo else 1.0))
		p.set("evo", evo)
		p.set("life", 2.2)
		_main().run.add_child(p)


func _fire_frost(lvl: int) -> void:
	var evo: bool = gm.is_evolved("frost")
	am.play_ranged("frost_shimmer", -8.0, 0.9, 1.1)
	var p = ProjectileScript.new()
	p.setup("frost", _dmg(14.0 * (1.0 + 0.3 * float(lvl - 1)) * (2.0 if evo else 1.0)), player.global_position)
	p.set("ring_max", (120.0 + 22.0 * float(lvl)) * (1.7 if evo else 1.0))
	p.set("slow_dur", (1.5 + 0.4 * float(lvl)) * (2.0 if evo else 1.0))
	p.set("evo", evo)
	_main().run.add_child(p)


func _fire_lightning(lvl: int) -> void:
	var evo: bool = gm.is_evolved("lightning")
	var chains := (2 + lvl) * (2 if evo else 1)
	var dmg := _dmg(20.0 * (1.0 + 0.3 * float(lvl - 1)) * (2.0 if evo else 1.0))
	var reach := 420.0 if evo else 300.0
	var from: Vector2 = player.global_position
	var skip := {}
	var pts := PackedVector2Array([from])
	for c in chains:
		var cur = _nearest_except(from, reach, skip)
		if cur == null:
			break
		skip[cur.get_instance_id()] = true
		pts.append(cur.global_position)
		cur.take_damage(dmg, from, 40.0)
		from = cur.global_position
	if pts.size() > 1:
		am.play_ranged("lightning_crack", -6.0, 0.9, 1.15)
		var zap = ProjectileScript.new()
		zap.setup("zap", 0.0, Vector2.ZERO)
		zap.set("zap_points", pts)
		_main().run.add_child(zap)


func _fire_raven(lvl: int) -> void:
	var evo: bool = gm.is_evolved("raven")
	var n := 2 + lvl / 2 + (3 if evo else 0)
	var pierce := 1 + lvl / 2 + (3 if evo else 0)
	var dmg := _dmg(16.0 * (1.0 + 0.3 * float(lvl - 1)) * (2.0 if evo else 1.0))
	am.play_ranged("raven_cry", -8.0, 0.9, 1.15)
	for i in n:
		var r = ProjectileScript.new()
		r.setup_raven(dmg, player.global_position + Vector2.from_angle(randf() * TAU) * 24.0, pierce)
		r.set("weapon_lvl", lvl)
		r.set("evo", evo)
		_main().run.add_child(r)




func _fire_lance(lvl: int) -> void:
	var evo: bool = gm.is_evolved("lance")
	var target = _nearest(player.global_position, 950.0)
	if target == null:
		return
	am.play_ranged("dagger_throw", -8.0, 0.55, 0.7)
	var ang: float = (target.global_position - player.global_position).angle()
	var p = ProjectileScript.new()
	p.setup("lance", _dmg(30.0 * (1.0 + 0.35 * float(lvl - 1)) * (2.4 if evo else 1.0)), player.global_position)
	p.set("vel", Vector2.from_angle(ang) * (900.0 if evo else 720.0))
	p.set("pierce", (3 + lvl * 2) * (2 if evo else 1))
	p.set("evo", evo)
	p.set("life", 1.8)
	_main().run.add_child(p)




func _fire_miasma(lvl: int) -> void:
	var evo: bool = gm.is_evolved("miasma")
	var anchor = null
	var best_n := -1
	for e in _enemies():
		var n := 0
		for o in _enemies():
			if o != e and o.global_position.distance_to(e.global_position) < 220.0:
				n += 1
		if n > best_n:
			best_n = n
			anchor = e
	var pos: Vector2 = player.global_position + Vector2(140, 0)
	if anchor != null:
		pos = anchor.global_position
	am.play_ranged("frost_shimmer", -6.0, 0.6, 0.8)
	var p = ProjectileScript.new()
	p.setup("miasma", _dmg(9.0 * (1.0 + 0.3 * float(lvl - 1)) * (2.2 if evo else 1.0)), pos)
	p.set("cloud_radius", (120.0 + 20.0 * float(lvl)) * (1.8 if evo else 1.0))
	p.set("life", (3.2 + 0.5 * float(lvl)) * (1.6 if evo else 1.0))
	p.set("slow_dur", 1.2)
	p.set("evo", evo)
	_main().run.add_child(p)



func _fire_comet(lvl: int) -> void:
	var evo: bool = gm.is_evolved("comet")
	var foes := _enemies()
	if foes.is_empty():
		return
	var n := (2 + lvl / 2) * (2 if evo else 1)
	am.play_ranged("boss_warning_horn", -12.0, 1.3, 1.5)
	for i in n:
		var e = foes[randi() % foes.size()]
		var p = ProjectileScript.new()
		p.setup("comet", _dmg(42.0 * (1.0 + 0.35 * float(lvl - 1)) * (2.0 if evo else 1.0)), e.global_position)
		p.set("aoe", (105.0 + 15.0 * float(lvl)) * (1.6 if evo else 1.0))
		p.set("evo", evo)
		p.set("life", 0.7)
		_main().run.add_child(p)



func _fire_sdagger(lvl: int) -> void:
	var evo: bool = gm.is_evolved("sdagger")
	var target = _nearest(player.global_position, 950.0)
	if target == null:
		return
	am.play_ranged("dagger_throw", -11.0, 1.15, 1.3)
	var n := 2 + lvl / 2 + (3 if evo else 0)
	var base_ang: float = (target.global_position - player.global_position).angle()
	for i in n:
		var p = ProjectileScript.new()
		p.setup("sdagger", _dmg(8.0 * (1.0 + 0.3 * float(lvl - 1)) * (2.2 if evo else 1.0)), player.global_position)
		var ang := base_ang + (float(i) - float(n - 1) / 2.0) * 0.16
		p.set("vel", Vector2.from_angle(ang) * 700.0)
		p.set("pierce", lvl / 3 + (2 if evo else 0))
		p.set("evo", evo)
		p.set("life", 1.4)
		_main().run.add_child(p)




func _fire_ember(lvl: int) -> void:
	var evo: bool = gm.is_evolved("ember")
	var target = _nearest(player.global_position, 1000.0)
	am.play("dagger_throw", -14.0, 0.7)
	var n := 1 + (1 if lvl >= 2 else 0) + (1 if lvl >= 4 else 0) + (2 if evo else 0)
	for i in n:
		var aim := Vector2.from_angle(randf() * TAU)
		if target:
			aim = (target.global_position - player.global_position).normalized()
			aim = aim.rotated(randf_range(-0.2, 0.2) * float(i))
		var p = ProjectileScript.new()
		p.setup("fireball", _dmg(16.0 * (1.0 + 0.35 * float(lvl - 1)) * (2.0 if evo else 1.0)), player.global_position)
		p.set("vel", aim * 420.0)
		p.set("aoe", (75.0 + 14.0 * float(lvl)) * (1.7 if evo else 1.0))
		p.set("evo", evo)
		p.set("life", 2.0)
		_main().run.add_child(p)




func _fire_bulwark(lvl: int) -> void:
	var evo: bool = gm.is_evolved("bulwark")
	var p = ProjectileScript.new()
	p.setup("bulwark", _dmg(45.0 * (1.0 + 0.35 * float(lvl - 1)) * (2.2 if evo else 1.0)), player.global_position)
	p.set("facing", facing)
	p.set("bulwark_radius", (150.0 + 18.0 * float(lvl)) * (1.5 if evo else 1.0))
	p.set("evo", evo)
	p.set("life", 0.32)
	_main().run.add_child(p)


func _sync_scythe() -> void:
	var want := 1 if gm.weapons.has("scythe") else 0
	while scythe_root.get_child_count() < want:
		var s = ProjectileScript.new()
		s.set("weapon_lvl", int(gm.weapons.get("scythe", 1)))
		s.call("setup_scythe")
		scythe_root.add_child(s)
	while scythe_root.get_child_count() > want:
		scythe_root.get_child(scythe_root.get_child_count() - 1).queue_free()
	for s in scythe_root.get_children():
		s.set("weapon_lvl", int(gm.weapons.get("scythe", 1)))
		s.set("evo", gm.is_evolved("scythe"))


func _sync_blades() -> void:
	var want := 0
	var lvl := 1
	if gm.weapons.has("blades"):
		lvl = int(gm.weapons["blades"])
		want = 1 + lvl
	var evo: bool = gm.is_evolved("blades")
	if evo:
		want += 3
	while blades_root.get_child_count() < want:
		blades_root.add_child(ProjectileScript.new())
	while blades_root.get_child_count() > want:
		blades_root.get_child(blades_root.get_child_count() - 1).queue_free()
	var kids := blades_root.get_children()
	for i in kids.size():
		var b = kids[i]
		b.set("weapon_lvl", lvl)
		b.set("evo", evo)
		b.call("setup_blade", i, want)
