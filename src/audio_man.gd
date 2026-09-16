extends Node
## AudioMan autoload: creepy music (base loop + intense boss layer) + pooled SFX.
## Music starts on title and keeps playing through runs; ducks under modals.
## Boss fights crossfade to the intense layer; it fades back after.
## Tracks (all CC0, no attribution required):
##   music_base.ogg — "Ambient Horror Track 01" by Cleyton Kauffman (opengameart.org)
##   music_boss.ogg — "Paranoid Truth" (opengameart.org), made loopable in-house.
## Mute via M key or speaker buttons. Muted state persists in the save file.

const SFX_NAMES := [
	"dagger_throw", "hit_flesh", "gem_pickup", "levelup_chime", "explosion",
	"lightning_crack", "frost_shimmer", "player_hurt", "enemy_die", "boss_roar",
	"boss_warning_horn", "victory_sting", "gameover_drone", "ui_click", "heartbeat",
	"shard_pickup", "elite_horn", "chest_open", "scythe_swing", "raven_cry",
]
const POOL_SIZE := 10
const MUSIC_DB := -16.0   # music sits quietly under combat
const INTENSE_DB := -13.0 # boss layer runs a touch hotter
const SILENT_DB := -60.0
const DUCK_DB := -24.0    # ducked when a modal is open
const AUDIO_DIR := "res://assets/audio/"

# per-sound minimum gap between plays (seconds) to avoid machine-gun stacking
const THROTTLE := {
	"hit_flesh": 0.07,
	"enemy_die": 0.05,
	"dagger_throw": 0.05,
	"gem_pickup": 0.03,
	"shard_pickup": 0.03,
	"scythe_swing": 0.4,
	"raven_cry": 0.5,
}

var muted := false
var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _music: AudioStreamPlayer
var _intense: AudioStreamPlayer  # boss-fight layer, silent until set_intense(true)
var _ducked := false
var _intense_on := false
var _last_play := {}
var _gem_streak := 0
var _gem_last := -99.0
var _shard_streak := 0
var _shard_last := -99.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_muted()
	for n in SFX_NAMES:
		var path: String = AUDIO_DIR + n + ".wav"
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)
		else:
			push_warning("AudioMan: missing " + path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Master"
	add_child(_music)
	_intense = AudioStreamPlayer.new()
	_intense.bus = &"Master"
	add_child(_intense)
	_start_loop(_music, AUDIO_DIR + "music_base.ogg", MUSIC_DB)
	_start_loop(_intense, AUDIO_DIR + "music_boss.ogg", SILENT_DB)
	_apply_mute()


## Starts a seamless OGG music loop on the given player.
func _start_loop(p: AudioStreamPlayer, path: String, vol_db: float) -> void:
	if ResourceLoader.exists(path):
		var stream: AudioStreamOggVorbis = load(path)
		stream.loop = true
		p.stream = stream
		p.volume_db = vol_db
		p.play()
	else:
		push_warning("AudioMan: missing " + path)


## Crossfades between the creepy base loop and the intense boss layer.
func set_intense(on: bool) -> void:
	if _intense_on == on:
		return
	_intense_on = on
	_apply_music_volumes(2.5)


## Recomputes music volumes from intense/ducked state and tweens to them.
func _apply_music_volumes(fade: float = 0.4) -> void:
	var base_db := DUCK_DB if _ducked else MUSIC_DB
	var int_db := SILENT_DB
	if _intense_on:
		base_db = SILENT_DB
		int_db = (DUCK_DB + 3.0) if _ducked else INTENSE_DB
	if _music.playing:
		var tw := create_tween()
		tw.tween_property(_music, "volume_db", base_db, fade)
	if _intense.playing:
		var tw2 := create_tween()
		tw2.tween_property(_intense, "volume_db", int_db, fade)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_M:
			toggle_mute()


func play(sfx_name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted or not _sfx.has(sfx_name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap: float = THROTTLE.get(sfx_name, 0.0)
	if gap > 0.0 and now - float(_last_play.get(sfx_name, -99.0)) < gap:
		return
	_last_play[sfx_name] = now
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL_SIZE
	p.stream = _sfx[sfx_name]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func play_ranged(sfx_name: String, vol_db: float, p0: float, p1: float) -> void:
	play(sfx_name, vol_db, randf_range(p0, p1))


## Gem pickup with combo pitch: chains within 2s rise in pitch.
func play_gem() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _gem_last > 2.0:
		_gem_streak = 0
	_gem_last = now
	_gem_streak = mini(_gem_streak + 1, 10)
	play("gem_pickup", -6.0, 1.0 + float(_gem_streak) * 0.06)


## Shard pickup with its own combo pitch (independent of gems).
func play_shard() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _shard_last > 2.0:
		_shard_streak = 0
	_shard_last = now
	_shard_streak = mini(_shard_streak + 1, 10)
	play("shard_pickup", -6.0, 1.0 + float(_shard_streak) * 0.05)


func duck(on: bool) -> void:
	if _ducked == on:
		return
	_ducked = on
	_apply_music_volumes(0.4)


func is_ducked() -> bool:
	return _ducked


func toggle_mute() -> void:
	muted = not muted
	_apply_mute()
	_save_muted()


func is_muted() -> bool:
	return muted


func music_playing() -> bool:
	return _music.playing


func _apply_mute() -> void:
	AudioServer.set_bus_mute(0, muted)


func _load_muted() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://grim_survivors.cfg") == OK:
		muted = bool(cfg.get_value("audio", "muted", false))


func _save_muted() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://grim_survivors.cfg")  # keep existing sections
	cfg.set_value("audio", "muted", muted)
	cfg.save("user://grim_survivors.cfg")
