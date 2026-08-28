extends CanvasLayer

signal resume_requested
@warning_ignore("unused_signal")
signal restart_requested
@warning_ignore("unused_signal")
signal main_menu_requested


@onready var pause_overlay: Control = $PauseOverlay
@onready var btn_resume: Button = $PauseOverlay/CenterVBox/MenuVBox/BtnResume
@onready var btn_restart: Button = $PauseOverlay/CenterVBox/MenuVBox/BtnRestart
@onready var btn_settings: Button = $PauseOverlay/CenterVBox/MenuVBox/BtnSettings
@onready var btn_main_menu: Button = $PauseOverlay/CenterVBox/MenuVBox/BtnMainMenu

@onready var settings_panel: Control = $SettingsPanel
@onready var restart_confirmation: Control = $RestartConfirmation

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	pause_overlay.visible = false
	if settings_panel:
		settings_panel.visible = false
		settings_panel.back_pressed.connect(func(): settings_panel.visible = false)
	if restart_confirmation:
		restart_confirmation.visible = false
		restart_confirmation.confirmed.connect(_on_restart_confirmed)

	if btn_resume:
		btn_resume.pressed.connect(_on_resume_pressed)
	if btn_restart:
		btn_restart.pressed.connect(_on_restart_pressed)
	if btn_settings:
		btn_settings.pressed.connect(func(): if settings_panel: settings_panel.visible = true)
	if btn_main_menu:
		btn_main_menu.pressed.connect(_on_main_menu_pressed)

	var helper_script = load("res://scripts/ui/ui_audio_helper.gd")
	if helper_script:
		helper_script.setup_ui_audio(self)


func _unhandled_input(event: InputEvent) -> void:
	# Backquote ( ` ) or F1 key opens DebugPanel while in Pause Menu
	if event is InputEventKey and (event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE or event.keycode == KEY_F1) and event.pressed and not event.echo:
		var main = get_tree().current_scene
		if main:
			var hud_node = main.find_child("HUD", true, false)
			if hud_node and hud_node.has_node("DebugPanel"):
				var dbg = hud_node.get_node("DebugPanel")
				if dbg and dbg.has_method("toggle_panel"):
					dbg.toggle_panel()
					get_viewport().set_input_as_handled()
					return

	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if settings_panel and settings_panel.visible:
			settings_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		if restart_confirmation and restart_confirmation.visible:
			restart_confirmation.visible = false
			get_viewport().set_input_as_handled()
			return

		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var new_paused = !get_tree().paused
	get_tree().paused = new_paused
	pause_overlay.visible = new_paused

	if new_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resume_requested.emit()

func _on_restart_pressed() -> void:
	if restart_confirmation:
		restart_confirmation.visible = true

func _on_restart_confirmed() -> void:
	get_tree().paused = false
	pause_overlay.visible = false
	var main = get_tree().current_scene
	if main and main.has_method("restart_game"):
		main.restart_game()
	else:
		get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	pause_overlay.visible = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
