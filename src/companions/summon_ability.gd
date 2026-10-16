class_name SummonAbility
extends Node
# The survivor's one active ability: call the selected companion for a few
# seconds, then wait out the cooldown. Space, Q or a controller's Y button
# summons, as does the sigil button on the HUD. Lives under the run node, so
# it resets with every run.

const CompanionScript := preload("res://src/companions/companion.gd")

signal summoned(kind: String)

var main = null
var gm = null
var cooldown_left := 0.0
var _hinted := false


func setup(p_main) -> void:
	main = p_main
	gm = main.gm
	name = "SummonAbility"
	# The first call is close at the start of a run: the ability is there
	# to be used, not saved.
	cooldown_left = 6.0


func cooldown() -> float:
	return gm.companion_cooldown()


func is_ready() -> bool:
	return cooldown_left <= 0.0


func frac_ready() -> float:
	return clampf(1.0 - cooldown_left / maxf(cooldown(), 0.01), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if gm.state != gm.State.RUNNING:
		return
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)
		if cooldown_left <= 0.0 and not _hinted and gm.lifetime_summons < 3 and main.hud:
			_hinted = true
			main.hud.show_hint("YOUR COMPANION IS READY\nTAP THE SIGIL OR PRESS SPACE", 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if gm.state != gm.State.RUNNING:
		return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		pressed = k == KEY_SPACE or k == KEY_Q or k == KEY_E
	elif event is InputEventJoypadButton and event.pressed:
		pressed = (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y
	if pressed and try_summon():
		get_viewport().set_input_as_handled()


func try_summon() -> bool:
	if not is_ready() or gm.state != gm.State.RUNNING:
		return false
	var p = main.player
	if p == null or not is_instance_valid(p) or not bool(p.get("alive")):
		return false
	var kind: String = gm.selected_companion if gm.is_companion_unlocked(gm.selected_companion) else "hound"
	var c: Dictionary = gm.COMPANIONS[kind]
	var n: int = gm.companion_count()
	for i in n:
		var comp = CompanionScript.new()
		var off := Vector2.from_angle(randf() * TAU) * 60.0 if n == 1 else Vector2(-70.0 + 140.0 * float(i), 40.0)
		comp.position = main.clamp_arena(p.global_position + off, 20.0)
		comp.orbit_phase = PI * float(i)
		comp.setup(main, kind, gm.companion_duration(), c["color"], gm.companion_damage_mult())
		main.run.add_child(comp)
	cooldown_left = cooldown()
	gm.lifetime_summons += 1
	if gm.run_stats:
		gm.run_stats.log_event("summon %s" % kind)
	var am = main.am
	am.play("levelup_chime", -8.0)
	am.play_ranged("raven_cry", -10.0, 0.6, 0.75)
	main.jm.add_trauma(0.12)
	main.lm.flash(p.global_position, c["color"], 2.2, 3.0, 0.35)
	summoned.emit(kind)
	return true
