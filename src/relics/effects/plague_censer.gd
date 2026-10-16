extends RelicEffect
# A foe dying inside a miasma cloud leaves a small cloud of its own.
# Generation limit: offspring clouds are flagged and never spawn more, and no
# more than MAX_CHILDREN live at once.

const MAX_CHILDREN := 3


func on_kill(e, _src: String) -> void:
	var tree: SceneTree = main().get_tree()
	if tree.get_nodes_in_group("censer_clouds").size() >= MAX_CHILDREN:
		return
	for c in tree.get_nodes_in_group("miasma_clouds"):
		if c.is_in_group("censer_clouds"):
			continue
		if c.global_position.distance_to(e.global_position) <= float(c.get("cloud_radius")):
			var p = load("res://src/projectile.gd").new()
			p.setup("miasma", float(c.get("damage")) * 0.5, e.global_position)
			p.set("cloud_radius", float(c.get("cloud_radius")) * 0.5)
			p.set("life", 2.5)
			p.set("slow_dur", 1.0)
			p.set("source_id", source())
			p.add_to_group("censer_clouds")
			main().run.add_child(p)
			return
