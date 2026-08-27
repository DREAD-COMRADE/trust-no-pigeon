extends PanelContainer

@onready var close_button: Button = $Margin/VBox/HeaderHBox/CloseButton

@onready var btn_day: Button = $Margin/VBox/TimeGrid/BtnDay
@onready var btn_sunset: Button = $Margin/VBox/TimeGrid/BtnSunset
@onready var btn_night: Button = $Margin/VBox/TimeGrid/BtnNight
@onready var btn_dawn: Button = $Margin/VBox/TimeGrid/BtnDawn

@onready var btn_ufo: Button = $Margin/VBox/EventGrid/BtnUFO if has_node("Margin/VBox/EventGrid/BtnUFO") else null
@onready var btn_drone: Button = $Margin/VBox/EventGrid/BtnDrone if has_node("Margin/VBox/EventGrid/BtnDrone") else null
@onready var btn_gov_noticed: Button = $Margin/VBox/EventGrid/BtnGovNoticed if has_node("Margin/VBox/EventGrid/BtnGovNoticed") else null
@onready var btn_press_conf: Button = $Margin/VBox/EventGrid/BtnPressConf if has_node("Margin/VBox/EventGrid/BtnPressConf") else null
@onready var btn_shut_him_up: Button = $Margin/VBox/EventGrid/BtnShutHimUp if has_node("Margin/VBox/EventGrid/BtnShutHimUp") else null
@onready var btn_flock: Button = $Margin/VBox/EventGrid/BtnFlock if has_node("Margin/VBox/EventGrid/BtnFlock") else null
@onready var btn_multi_gov: Button = $Margin/VBox/EventGrid/BtnMultiGov if has_node("Margin/VBox/EventGrid/BtnMultiGov") else null

@onready var chk_godmode: CheckBox = $Margin/VBox/MiscHBox/ChkGodMode

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false

	if close_button:
		close_button.pressed.connect(func(): visible = false)

	# Time buttons
	if btn_day:
		btn_day.pressed.connect(func(): _set_time(0.0))
	if btn_sunset:
		btn_sunset.pressed.connect(func(): _set_time(10.0 / 30.0 + 0.01))
	if btn_night:
		btn_night.pressed.connect(func(): _set_time(15.0 / 30.0 + 0.01))
	if btn_dawn:
		btn_dawn.pressed.connect(func(): _set_time(25.0 / 30.0 + 0.01))

	# Event buttons
	if btn_ufo:
		btn_ufo.pressed.connect(func(): _trigger_event("UFO event"))
	if btn_drone:
		btn_drone.pressed.connect(func(): _trigger_event("Supply drone drop"))
	if btn_gov_noticed:
		btn_gov_noticed.pressed.connect(func(): _trigger_event("Government Has Noticed"))
	if btn_press_conf:
		btn_press_conf.pressed.connect(func(): _trigger_event("Emergency Press Conference"))
	if btn_shut_him_up:
		btn_shut_him_up.pressed.connect(func(): _trigger_event("Operation: Shut Him Up"))
	if btn_flock:
		btn_flock.pressed.connect(func(): _trigger_event("Pigeon flock"))
	if btn_multi_gov:
		btn_multi_gov.pressed.connect(func(): _trigger_event("Multi-Government-Pigeon wave"))

	# God Mode checkbox
	if chk_godmode:
		chk_godmode.toggled.connect(_on_godmode_toggled)

	var helper_script = load("res://scripts/ui/ui_audio_helper.gd")
	if helper_script:
		helper_script.setup_ui_audio(self)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE or event.keycode == KEY_F1) and event.pressed and not event.echo:
		toggle_panel()
		get_viewport().set_input_as_handled()

func toggle_panel() -> void:
	visible = !visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _set_time(ratio: float) -> void:
	var main = get_tree().current_scene
	if main and main.has_node("Systems/DayNightManager"):
		var dnm = main.get_node("Systems/DayNightManager")
		if dnm and dnm.has_method("set_starting_phase"):
			dnm.set_starting_phase(ratio)

func _trigger_event(event_name: String) -> void:
	var main = get_tree().current_scene
	if main and main.has_node("Systems/EventManager"):
		var em = main.get_node("Systems/EventManager")
		if em and em.has_method("trigger_event"):
			em.trigger_event(event_name)

func _on_godmode_toggled(toggled: bool) -> void:
	var main = get_tree().current_scene
	if main and "is_god_mode" in main:
		main.is_god_mode = toggled
