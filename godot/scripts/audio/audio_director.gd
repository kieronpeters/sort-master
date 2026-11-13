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

var muted := false

var _streams := {}
var _players: Array = []


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


func play(sound: String, volume_db: float = BASE_VOLUME_DB) -> void:
	if muted or not _streams.has(sound):
		return
	var player: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _players[0]
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.play()


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for p in _players:
			p.stop()
