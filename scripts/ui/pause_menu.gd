extends CanvasLayer

signal resume_requested
@warning_ignore("unused_signal")
signal restart_requested
@warning_ignore("unused_signal")
signal main_menu_requested


@onready var pause_overlay: Control = $PauseOverlay
@onready var center_vbox: Control = $PauseOverlay/CenterVBox if has_node("PauseOverlay/CenterVBox") else null
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
		if not settings_panel.back_pressed.is_connected(_on_settings_back):
			settings_panel.back_pressed.connect(_on_settings_back)
	if restart_confirmation:
		restart_confirmation.visible = false
		if not restart_confirmation.confirmed.is_connected(_on_restart_confirmed):
			restart_confirmation.confirmed.connect(_on_restart_confirmed)
		if not restart_confirmation.cancelled.is_connected(_on_restart_cancelled):
			restart_confirmation.cancelled.connect(_on_restart_cancelled)

	if btn_resume and not btn_resume.pressed.is_connected(_on_resume_pressed):
		btn_resume.pressed.connect(_on_resume_pressed)
	if btn_restart and not btn_restart.pressed.is_connected(_on_restart_pressed):
		btn_restart.pressed.connect(_on_restart_pressed)
	if btn_settings and not btn_settings.pressed.is_connected(_on_settings_pressed):
		btn_settings.pressed.connect(_on_settings_pressed)
	if btn_main_menu and not btn_main_menu.pressed.is_connected(_on_main_menu_pressed):
		btn_main_menu.pressed.connect(_on_main_menu_pressed)

	var helper_script = load("res://scripts/ui/ui_audio_helper.gd")
	if helper_script:
		helper_script.setup_ui_audio(self)


func _unhandled_input(event: InputEvent) -> void:
	# Backquote ( ` ) or F1 key opens DebugPanel while in Pause Menu
	if event is InputEventKey and (event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE or event.keycode == KEY_F1) and event.pressed and not event.echo:
		if is_inside_tree() and get_tree():
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
			_on_settings_back()
			get_viewport().set_input_as_handled()
			return
		if restart_confirmation and restart_confirmation.visible:
			_on_restart_cancelled()
			get_viewport().set_input_as_handled()
			return

		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var tree = get_tree() if is_inside_tree() else null
	var new_paused = !tree.paused if tree else !pause_overlay.visible
	if tree:
		tree.paused = new_paused
	pause_overlay.visible = new_paused
	if center_vbox:
		center_vbox.visible = true
	if settings_panel:
		settings_panel.visible = false
	if restart_confirmation:
		restart_confirmation.visible = false

	if new_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resume_requested.emit()

func _on_settings_pressed() -> void:
	if center_vbox:
		center_vbox.visible = false
	if settings_panel:
		settings_panel.visible = true

func _on_settings_back() -> void:
	if settings_panel:
		settings_panel.visible = false
	if center_vbox:
		center_vbox.visible = true

func _on_restart_pressed() -> void:
	if center_vbox:
		center_vbox.visible = false
	if restart_confirmation:
		restart_confirmation.visible = true

func _on_restart_cancelled() -> void:
	if restart_confirmation:
		restart_confirmation.visible = false
	if center_vbox:
		center_vbox.visible = true

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
