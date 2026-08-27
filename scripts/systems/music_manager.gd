extends Node
class_name MusicManager

@export var music_pool: Array[AudioStream] = [
	preload("res://assets/Audio/Main_theme.mp3"),
	preload("res://assets/Audio/Steel_Feathers_Theme5.mp3"),
	preload("res://assets/Audio/Theme1.mp3"),
	preload("res://assets/Audio/Theme2.mp3"),
	preload("res://assets/Audio/Theme3.mp3"),
	preload("res://assets/Audio/Theme4.mp3")
]

var ufo_theme: AudioStream = preload("res://assets/Audio/Theme4.mp3")

@onready var audio_player: AudioStreamPlayer = $AudioPlayer if has_node("AudioPlayer") else null

var current_track_index: int = -1

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		audio_player.name = "AudioPlayer"
		audio_player.bus = &"Master"
		add_child(audio_player)

	audio_player.finished.connect(_on_song_finished)
	play_next_song()

func play_next_song() -> void:
	if music_pool.size() == 0 or not audio_player:
		return

	var next_idx = randi() % music_pool.size()
	if music_pool.size() > 1 and next_idx == current_track_index:
		next_idx = (next_idx + 1) % music_pool.size()

	current_track_index = next_idx
	var stream = music_pool[current_track_index]
	if stream:
		audio_player.stream = stream
		audio_player.volume_db = -6.0
		audio_player.play()

func play_ufo_tension_theme() -> void:
	if audio_player and ufo_theme:
		audio_player.stream = ufo_theme
		audio_player.volume_db = -4.0
		audio_player.play()

func _on_song_finished() -> void:
	play_next_song()

func stop_music() -> void:
	if audio_player:
		audio_player.stop()
