extends Node
## Crossfades level/menu music and provides reusable sound effects.

var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var active_player: AudioStreamPlayer
var sfx: Dictionary = {}

const GAME_A_SFX := {
	"jump": "res://audio/game_a/go.wav", "hit": "res://audio/game_a/collision.wav",
	"collect": "res://audio/game_a/powerup.wav", "ui": "res://audio/game_a/click.wav"
}
const GAME_B_SFX := {
	"jump_b": "res://audio/game_b/jump.wav", "hit_b": "res://audio/game_b/crate_impact.wav",
	"collect_b": "res://audio/game_b/reactor_activate.wav", "ui_b": "res://audio/game_b/ui_click.wav"
}

func _ready() -> void:
	music_a = _make_player()
	music_b = _make_player()
	active_player = music_a
	_load_sfx(GAME_A_SFX)
	_load_sfx(GAME_B_SFX)

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	return p

func _load_sfx(table: Dictionary) -> void:
	for key in table:
		sfx[key] = load(table[key])

func play_sfx(name: String) -> void:
	if not sfx.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = sfx[name]
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()

func play_music(stream: AudioStream, fade_time := 1.0) -> void:
	var incoming := music_b if active_player == music_a else music_a
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(incoming, "volume_db", -8.0, fade_time)
	tween.tween_property(active_player, "volume_db", -80.0, fade_time)
	tween.finished.connect(func(): active_player.stop())
	active_player = incoming

func set_master_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(linear) if linear > 0.001 else -80.0)
