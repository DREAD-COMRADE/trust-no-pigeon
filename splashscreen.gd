extends Control

@onready var video: VideoStreamPlayer = %VideoStreamPlayer if has_node("%VideoStreamPlayer") else null
@onready var title_panel: Control = $TitlePanel if has_node("TitlePanel") else null
@onready var title_texture: TextureRect = $TitlePanel/TitleTexture if has_node("TitlePanel/TitleTexture") else null
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer if has_node("AudioStreamPlayer") else null

var phase: int = 0 # 0 = Video, 1 = Title Screen (game_title_screen.png), 2 = Transitioning

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if video:
		video.finished.connect(_on_video_finished)

	if title_panel:
		title_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if phase == 0:
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			_on_video_finished()
			get_viewport().set_input_as_handled()
	elif phase == 1:
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			_go_to_main_menu()
			get_viewport().set_input_as_handled()

func _on_video_finished() -> void:
	if phase != 0:
		return
	phase = 1

	if video:
		video.stop()
		video.visible = false

	if title_panel:
		title_panel.visible = true
		title_panel.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(title_panel, "modulate:a", 1.0, 0.6)

	if audio_player:
		audio_player.play()

func _go_to_main_menu() -> void:
	if phase == 2:
		return
	phase = 2

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)
