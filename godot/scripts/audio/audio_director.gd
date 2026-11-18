class_name AudioDirector
extends Node

## Small voice pool for the game's UI sounds. Streams are loaded defensively:
## a missing file disables that sound instead of breaking the scene.

const SOUND_PATHS := {
	"select": "res://assets/audio/select.wav",
	"pour": "res://assets/audio/pour.wav",
	"invalid": "res://assets/audio/invalid.wav",
	"undo": "res://assets/audio/undo.wav",
	"win": "res://assets/audio/win.wav",
	"ui": "res://assets/audio/ui.wav",
}

const VOICES := 8
const BASE_VOLUME_DB := -9.0

## Per-sound trim so the short ticks sit under the longer reward sound.
const GAINS := {
	"select": -12.0,
	"pour": -10.0,
	"invalid": -9.0,
	"undo": -13.0,
	"win": -8.0,
	"ui": -15.0,
}

var muted := false

## Music and effects levels, 0.0-1.0, saved with progress. They are applied as a
## dB offset on top of the authored gains, so 1.0 leaves the mix exactly as
## designed and 0.5 halves it.
var music_volume := 1.0
var sfx_volume := 1.0
## Separate from the global mute: a player may want the game silent but the music
## on, or the reverse. The phone speaker measured quiet, so the range runs to 2.0
## (+6 dB over the authored level) rather than stopping at 1.0.
var music_muted := false
var sfx_muted := false

var _streams := {}
var _players: Array = []

## Background music: three generated tracks played in sequence, reshuffled each
## cycle, so a session does not sit on one looping clip. They are far quieter
## than the effects so the liquid and interface sounds stay the loudest thing
## on screen. All three are original and CC0 (tools/make_music.py).
const MUSIC_TRACKS := [
	"res://assets/audio/music/amber_greenhouse.ogg",
	"res://assets/audio/music/still_water.ogg",
	"res://assets/audio/music/morning_prism.ogg",
	"res://assets/audio/music/glass_hour.ogg",
	"res://assets/audio/music/lantern_walk.ogg",
]
## The last track started, so a reshuffle never repeats it immediately. Five
## tracks at 2.5 minutes each is 12.5 minutes before the set begins again.
var _last_track := ""
const MUSIC_DB := -9.0

var _music: AudioStreamPlayer = null
var _idle_checks := 0
var _music_watchdog: Timer = null
var _music_order: Array = []
var _music_index := 0


func _ready() -> void:
	for key in SOUND_PATHS:
		if ResourceLoader.exists(SOUND_PATHS[key]):
			_streams[key] = load(SOUND_PATHS[key])
		else:
			push_warning("Missing sound: " + SOUND_PATHS[key])
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = BASE_VOLUME_DB
		add_child(player)
		_players.append(player)
	_setup_music()


func _setup_music() -> void:
	# Headless runs (the test suites) must stay silent and cheap.
	if DisplayServer.get_name() == "headless":
		return
	for path in MUSIC_TRACKS:
		if ResourceLoader.exists(path):
			_music_order.append(path)
	if _music_order.is_empty():
		return
	_shuffle_music()
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB + _volume_db(music_volume)
	_music.finished.connect(_next_track)
	add_child(_music)

	# A missed `finished` signal (a decode hiccup, a focus change, a stream that
	# failed to load) left the bed silent with nothing to retry it. This simply
	# checks that music is playing and restarts it if not.
	_music_watchdog = Timer.new()
	_music_watchdog.wait_time = 2.0
	_music_watchdog.autostart = true
	_music_watchdog.timeout.connect(_watch_music)
	add_child(_music_watchdog)

	_start_track()


func _shuffle_music() -> void:
	for i in range(_music_order.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = _music_order[i]
		_music_order[i] = _music_order[j]
		_music_order[j] = tmp
	# A shuffle can hand back the same track that just finished; swap it away so
	# the bed never plays the same piece twice in a row.
	if _music_order.size() > 1 and _music_order[0] == _last_track:
		var k := randi() % (_music_order.size() - 1) + 1
		var held = _music_order[0]
		_music_order[0] = _music_order[k]
		_music_order[k] = held


func _start_track() -> void:
	if _music == null or muted or music_muted or _music_order.is_empty():
		return
	# Walk the order until a stream actually loads. A single failed load used to
	# leave the bed silent forever, because nothing retried.
	for attempt in _music_order.size():
		var candidate: String = _music_order[_music_index % _music_order.size()]
		var stream := load(candidate) as AudioStream
		if stream != null:
			_last_track = candidate
			_music.stream = stream
			_music.play()
			_idle_checks = 0
			return
		push_warning("Music failed to load: " + candidate)
		_music_index += 1


## Next track starts the instant the previous ends, so the bed is continuous.
func _next_track() -> void:
	if _music == null or _music_order.is_empty():
		return
	_music_index += 1
	if _music_index % _music_order.size() == 0:
		_shuffle_music()   # a fresh order each time through the set
	_start_track()


## Restarts the bed if it has gone quiet when it should be playing. Two
## consecutive idle checks, so the gap between tracks is never mistaken for a stall.
func _watch_music() -> void:
	if _music == null:
		return
	if muted or music_muted:
		_idle_checks = 0
		return
	if _music.playing:
		_idle_checks = 0
		return
	_idle_checks += 1
	if _idle_checks >= 2:
		_idle_checks = 0
		_next_track()


func play(sound: String, volume_db: float = BASE_VOLUME_DB) -> void:
	if muted or sfx_muted or not _streams.has(sound):
		return
	var player: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _players[0]
	player.stream = _streams[sound]
	player.volume_db = GAINS.get(sound, volume_db) + _volume_db(sfx_volume)
	player.play()


## 1.0 keeps the authored level; 0.0 is silent. linear_to_db(0) is -inf, so the
## floor keeps it finite and lets the player actually stop.
static func _volume_db(v: float) -> float:
	return linear_to_db(maxf(0.0001, clampf(v, 0.0, 2.0)))


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 2.0)
	if _music != null:
		_music.volume_db = MUSIC_DB + _volume_db(music_volume)


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 2.0)


func set_music_muted(value: bool) -> void:
	music_muted = value
	if _music == null:
		return
	if music_muted:
		_music.stop()
	else:
		_start_track()


func set_sfx_muted(value: bool) -> void:
	sfx_muted = value
	if sfx_muted:
		for p in _players:
			p.stop()


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for p in _players:
			p.stop()
		if _music != null:
			_music.stop()
	else:
		_start_track()
