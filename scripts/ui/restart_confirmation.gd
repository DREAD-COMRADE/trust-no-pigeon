extends Control

signal confirmed
signal cancelled

@onready var btn_restart: Button = $CardPanel/VBox/BtnHBox/BtnRestart if has_node("CardPanel/VBox/BtnHBox/BtnRestart") else null
@onready var btn_cancel: Button = $CardPanel/VBox/BtnHBox/BtnCancel if has_node("CardPanel/VBox/BtnHBox/BtnCancel") else null

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false

	if btn_restart:
		btn_restart.pressed.connect(func():
			confirmed.emit()
			visible = false
		)

	if btn_cancel:
		btn_cancel.pressed.connect(func():
			cancelled.emit()
			visible = false
		)

func _unhandled_input(event: InputEvent) -> void:
	if visible:
		if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
			cancelled.emit()
			visible = false
			get_viewport().set_input_as_handled()
