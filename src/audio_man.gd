extends Node




const SFX_NAMES := [
	"dagger_throw", "hit_flesh", "gem_pickup", "levelup_chime", "explosion",
	"lightning_crack", "frost_shimmer", "player_hurt", "enemy_die", "boss_roar",
	"boss_warning_horn", "victory_sting", "gameover_drone", "ui_click", "heartbeat",
	"shard_pickup", "elite_horn", "chest_open", "scythe_swing", "raven_cry",
]
const POOL_SIZE := 10
const MUSIC_DB := -16.0
const DUCK_DB := -24.0
const AUDIO_DIR := "res://assets/audio/"


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
var _ducked := false
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
	var mpath := AUDIO_DIR + "music_ambient_loop.wav"
	if ResourceLoader.exists(mpath):
		var stream: AudioStreamWAV = load(mpath)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.data.size() / 2)
		_music.stream = stream
		_music.volume_db = MUSIC_DB
		_music.play()
	_apply_mute()


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



func play_gem() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _gem_last > 2.0:
		_gem_streak = 0
	_gem_last = now
	_gem_streak = mini(_gem_streak + 1, 10)
	play("gem_pickup", -6.0, 1.0 + float(_gem_streak) * 0.06)



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
	if _music.playing:
		var tw := create_tween()
		tw.tween_property(_music, "volume_db", DUCK_DB if on else MUSIC_DB, 0.4)


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
	cfg.load("user://grim_survivors.cfg")
	cfg.set_value("audio", "muted", muted)
	cfg.save("user://grim_survivors.cfg")
