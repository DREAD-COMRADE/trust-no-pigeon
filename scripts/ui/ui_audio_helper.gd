extends Node
class_name UIAudioHelper

var click_sound: AudioStream = preload("res://assets/Audio/menu_click.mp3")

# Sound variation profiles
const HOVER_PITCH_MIN := 1.14
const HOVER_PITCH_MAX := 1.32

const CLICK_DEFAULT_PITCH_MIN := 0.92
const CLICK_DEFAULT_PITCH_MAX := 1.08

const CLICK_CONFIRM_PITCH_MIN := 1.02
const CLICK_CONFIRM_PITCH_MAX := 1.18

const CLICK_CANCEL_PITCH_MIN := 0.78
const CLICK_CANCEL_PITCH_MAX := 0.88

const TAB_SWITCH_PITCH_MIN := 1.10
const TAB_SWITCH_PITCH_MAX := 1.25

# Rate limiter for sliders
var _last_slider_sound_time: float = 0.0
const SLIDER_SOUND_INTERVAL: float = 0.06

static func setup_ui_audio(root_node: Node) -> void:
	if not root_node:
		return

	var helper = root_node.get_node_or_null("UIAudioHelper")
	if not helper:
		helper = UIAudioHelper.new()
		helper.name = "UIAudioHelper"
		root_node.add_child(helper)

	if helper and helper.has_method("bind_controls_deferred"):
		helper.bind_controls_deferred(root_node)

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func bind_controls_deferred(root_node: Node) -> void:
	if is_inside_tree():
		await get_tree().process_frame
	bind_controls_recursive(root_node)

func bind_controls_recursive(node: Node) -> void:
	if not node:
		return

	# Buttons
	if node is BaseButton:
		if not node.has_meta("audio_bound"):
			node.set_meta("audio_bound", true)
			var node_name_lower = node.name.to_lower()

			if "back" in node_name_lower or "close" in node_name_lower or "cancel" in node_name_lower:
				node.pressed.connect(func(): play_click_sfx("cancel"))
			elif "play" in node_name_lower or "start" in node_name_lower or "confirm" in node_name_lower or "restart" in node_name_lower:
				node.pressed.connect(func(): play_click_sfx("confirm"))
			elif "btn" in node_name_lower and ("gameplay" in node_name_lower or "controls" in node_name_lower or "audio" in node_name_lower or "video" in node_name_lower or "accessibility" in node_name_lower):
				node.pressed.connect(func(): play_click_sfx("tab"))
			elif node is CheckButton or node is CheckBox:
				node.toggled.connect(func(val): play_toggle_sfx(val))
			else:
				node.pressed.connect(func(): play_click_sfx("default"))

			node.mouse_entered.connect(func(): play_hover_sfx())

	# Sliders
	elif node is Slider:
		if not node.has_meta("audio_bound"):
			node.set_meta("audio_bound", true)
			node.value_changed.connect(func(val): play_slider_sfx(node, val))

	# Option Buttons / Dropdowns
	elif node is OptionButton:
		if not node.has_meta("audio_bound"):
			node.set_meta("audio_bound", true)
			node.item_selected.connect(func(_idx): play_click_sfx("tab"))

	for child in node.get_children():
		bind_controls_recursive(child)

func play_hover_sfx() -> void:
	_play_sfx_instance(randf_range(HOVER_PITCH_MIN, HOVER_PITCH_MAX), -11.0)

func play_click_sfx(type: String = "default") -> void:
	var pitch = 1.0
	var vol_db = -4.0

	match type:
		"confirm":
			pitch = randf_range(CLICK_CONFIRM_PITCH_MIN, CLICK_CONFIRM_PITCH_MAX)
			vol_db = -3.0
		"cancel":
			pitch = randf_range(CLICK_CANCEL_PITCH_MIN, CLICK_CANCEL_PITCH_MAX)
			vol_db = -5.0
		"tab":
			pitch = randf_range(TAB_SWITCH_PITCH_MIN, TAB_SWITCH_PITCH_MAX)
			vol_db = -4.5
		_:
			pitch = randf_range(CLICK_DEFAULT_PITCH_MIN, CLICK_DEFAULT_PITCH_MAX)
			vol_db = -4.0

	_play_sfx_instance(pitch, vol_db)

func play_toggle_sfx(is_on: bool) -> void:
	var pitch = randf_range(1.15, 1.25) if is_on else randf_range(0.85, 0.95)
	_play_sfx_instance(pitch, -4.5)

func play_slider_sfx(slider: Slider, val: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_slider_sound_time < SLIDER_SOUND_INTERVAL:
		return
	_last_slider_sound_time = current_time

	# Pitch varies with slider position (0% -> 0.85 pitch, 100% -> 1.35 pitch)
	var ratio = 0.5
	if slider.max_value > slider.min_value:
		ratio = clamp((val - slider.min_value) / (slider.max_value - slider.min_value), 0.0, 1.0)
	var pitch = lerp(0.85, 1.35, ratio) + randf_range(-0.03, 0.03)

	_play_sfx_instance(pitch, -12.0)

func _play_sfx_instance(pitch: float, volume_db: float) -> void:
	if not is_inside_tree() or not click_sound:
		return

	var player = AudioStreamPlayer.new()
	player.stream = click_sound
	player.bus = &"Master"
	player.process_mode = PROCESS_MODE_ALWAYS
	player.pitch_scale = pitch

	# Factor in SFX settings
	var sfx_ratio = (SettingsManager.sfx_volume / 100.0) if not SettingsManager.is_muted else 0.0
	if sfx_ratio <= 0.0:
		return

	player.volume_db = volume_db + linear_to_db(sfx_ratio)

	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

