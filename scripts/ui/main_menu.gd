extends Control

@onready var btn_play: Button = $Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnPlay if has_node("Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnPlay") else null
@onready var btn_high_scores: Button = $Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnHighScores if has_node("Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnHighScores") else null
@onready var btn_achievements: Button = $Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnAchievements if has_node("Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnAchievements") else null
@onready var btn_settings: Button = $Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnSettings if has_node("Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnSettings") else null
@onready var btn_credits: Button = $Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnCredits if has_node("Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnCredits") else null
@onready var btn_quit: Button = $Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnQuit if has_node("Margin/VBoxMain/ContentHBox/LeftMenu/VBox/BtnQuit") else null

@onready var best_score_value: Label = $Margin/VBoxMain/HeaderHBox/BestScoreBox/VBox/ScoreValue if has_node("Margin/VBoxMain/HeaderHBox/BestScoreBox/VBox/ScoreValue") else null
@onready var settings_panel: Control = $SettingsPanel if has_node("SettingsPanel") else null
@onready var modal_dialog: Control = $ModalDialog if has_node("ModalDialog") else null
@onready var modal_title: Label = $ModalDialog/Card/VBox/Title if has_node("ModalDialog/Card/VBox/Title") else null
@onready var modal_body: Label = $ModalDialog/Card/VBox/Body if has_node("ModalDialog/Card/VBox/Body") else null
@onready var modal_close: Button = $ModalDialog/Card/VBox/CloseBtn if has_node("ModalDialog/Card/VBox/CloseBtn") else null
@onready var credits_screen: Control = $CreditsScreen if has_node("CreditsScreen") else null
@onready var credits_viewport: Control = $CreditsScreen/CreditsViewport if has_node("CreditsScreen/CreditsViewport") else null
@onready var credits_roll: Control = $CreditsScreen/CreditsViewport/CreditsRoll if has_node("CreditsScreen/CreditsViewport/CreditsRoll") else null

# Menu Music Playlist
@export var menu_music_playlist: Array[AudioStream] = [
	preload("res://assets/Audio/Steel_Feathers_Theme5.mp3"),
	preload("res://assets/Audio/Main_theme.mp3"),
	preload("res://assets/Audio/Theme1.mp3"),
	preload("res://assets/Audio/Theme2.mp3"),
	preload("res://assets/Audio/Theme3.mp3")
]

@onready var menu_music_player: AudioStreamPlayer = $MenuMusicPlayer if has_node("MenuMusicPlayer") else null
var _current_music_idx: int = -1

const CREDITS_SCROLL_SPEED := 42.0
const CREDITS_END_DELAY := 2.5

var credits_scrolling := false
var credits_end_time := -1.0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	SettingsManager.init_settings()
	SettingsManager.register_listener(_update_music_volume)

	if modal_dialog:
		modal_dialog.visible = false
		if modal_close:
			modal_close.pressed.connect(func(): modal_dialog.visible = false)
	if credits_screen:
		credits_screen.visible = false

	if settings_panel:
		settings_panel.visible = false
		settings_panel.back_pressed.connect(func(): settings_panel.visible = false)

	if btn_play and not btn_play.pressed.is_connected(_on_play_pressed):
		btn_play.pressed.connect(_on_play_pressed)
	if btn_high_scores and not btn_high_scores.pressed.is_connected(_on_high_scores_pressed):
		btn_high_scores.pressed.connect(_on_high_scores_pressed)
	if btn_achievements and not btn_achievements.pressed.is_connected(_on_achievements_pressed):
		btn_achievements.pressed.connect(_on_achievements_pressed)
	if btn_settings and not btn_settings.pressed.is_connected(_on_settings_pressed):
		btn_settings.pressed.connect(_on_settings_pressed)
	if btn_credits and not btn_credits.pressed.is_connected(_on_credits_pressed):
		btn_credits.pressed.connect(_on_credits_pressed)
	if btn_quit and not btn_quit.pressed.is_connected(_on_quit_pressed):
		btn_quit.pressed.connect(_on_quit_pressed)

	_update_best_score()
	_start_menu_music()

	UIAudioHelper.setup_ui_audio(self)

func _exit_tree() -> void:
	SettingsManager.unregister_listener(_update_music_volume)

func _start_menu_music() -> void:
	if not menu_music_player or menu_music_playlist.is_empty():
		return
	if not menu_music_player.finished.is_connected(_play_next_menu_theme):
		menu_music_player.finished.connect(_play_next_menu_theme)
	_play_next_menu_theme()

func _play_next_menu_theme() -> void:
	if not menu_music_player or not menu_music_player.is_inside_tree() or menu_music_playlist.is_empty():
		return

	var next_idx = randi() % menu_music_playlist.size()
	if menu_music_playlist.size() > 1 and next_idx == _current_music_idx:
		next_idx = (next_idx + 1) % menu_music_playlist.size()

	_current_music_idx = next_idx
	menu_music_player.stream = menu_music_playlist[_current_music_idx]
	_update_music_volume()
	menu_music_player.play()

func _update_music_volume() -> void:
	if not menu_music_player:
		return
	var music_ratio = (SettingsManager.music_volume / 100.0) if not SettingsManager.is_muted else 0.0
	if music_ratio <= 0.0:
		menu_music_player.volume_db = -80.0
	else:
		menu_music_player.volume_db = -6.0 + linear_to_db(music_ratio)


func _update_best_score() -> void:
	var high_score = 0
	if FileAccess.file_exists("user://highscore.save"):
		var file = FileAccess.open("user://highscore.save", FileAccess.READ)
		if file:
			high_score = file.get_32()
			file.close()

	if best_score_value:
		best_score_value.text = str(high_score)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_high_scores_pressed() -> void:
	_show_modal("", "")

func _on_achievements_pressed() -> void:
	_show_modal("", "")

func _on_settings_pressed() -> void:
	if settings_panel:
		settings_panel.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_credits_pressed() -> void:
	_start_credits()

func _start_credits() -> void:
	if not credits_screen or not credits_viewport or not credits_roll:
		return

	credits_screen.visible = true
	credits_end_time = -1.0
	await get_tree().process_frame
	credits_roll.position = Vector2(0.0, credits_viewport.size.y)
	credits_scrolling = true

func _close_credits() -> void:
	if credits_screen:
		credits_screen.visible = false
	credits_scrolling = false
	credits_end_time = -1.0

func _process(delta: float) -> void:
	if credits_scrolling and credits_roll and credits_viewport:
		credits_roll.position.y -= CREDITS_SCROLL_SPEED * delta
		if credits_roll.position.y + credits_roll.size.y < 0.0:
			credits_scrolling = false
			credits_end_time = Time.get_ticks_msec() / 1000.0 + CREDITS_END_DELAY

	if credits_end_time >= 0.0 and Time.get_ticks_msec() / 1000.0 >= credits_end_time:
		_close_credits()

func _input(event: InputEvent) -> void:
	if not credits_screen or not credits_screen.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_close_credits()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_credits()
		get_viewport().set_input_as_handled()

func _show_modal(title_text: String, body_text: String) -> void:
	if modal_dialog:
		if modal_title:
			modal_title.text = title_text
			modal_title.visible = (title_text != "")
		if modal_body:
			modal_body.text = body_text
			modal_body.visible = (body_text != "")
		var sep = modal_dialog.get_node_or_null("Card/VBox/HSeparator")
		if sep:
			sep.visible = (title_text != "" and body_text != "")
		modal_dialog.visible = true
