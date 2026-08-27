extends Node3D
class_name EventScreen

@export var default_title: String = "TRUST NO PIGEON"
@export var default_subtitle: String = "SURVEILLANCE NETWORK ACTIVE"
@export var is_active_by_default: bool = true

@onready var title_label: Label3D = $ScreenSurface/TitleLabel
@onready var subtitle_label: Label3D = $ScreenSurface/SubtitleLabel
@onready var header_label: Label3D = $ScreenSurface/HeaderLabel
@onready var screen_mesh: MeshInstance3D = $ScreenSurface
@onready var alert_light: OmniLight3D = $AlertLight if has_node("AlertLight") else null

var is_event_active: bool = false
var pulse_time: float = 0.0

func _ready() -> void:
	add_to_group("event_screens")
	if is_active_by_default:
		clear_screen()
	else:
		set_screen_power(false)

func _process(delta: float) -> void:
	if is_event_active:
		pulse_time += delta * 6.0
		var pulse = (sin(pulse_time) + 1.0) * 0.5
		if alert_light:
			alert_light.light_energy = lerp(2.0, 8.0, pulse)
		if title_label:
			title_label.modulate = Color(1.0, lerp(0.2, 0.9, pulse * 0.4), 0.1, 1.0)

func show_event(title_text: String, subtitle_text: String = "") -> void:
	is_event_active = true
	pulse_time = 0.0

	_ensure_nodes()

	if header_label:
		header_label.text = ">>> PRIORITY BROADCAST <<<"
		header_label.modulate = Color(1.0, 0.3, 0.3, 1.0)

	if title_label:
		title_label.text = title_text
		title_label.modulate = Color(1.0, 0.85, 0.1, 1.0)

	if subtitle_label:
		subtitle_label.text = subtitle_text if subtitle_text != "" else "TACTICAL ADVISORY ISSUED"
		subtitle_label.modulate = Color(0.9, 0.9, 0.9, 1.0)

	if alert_light:
		alert_light.visible = true
		alert_light.light_color = Color(1.0, 0.3, 0.1, 1.0)
		alert_light.light_energy = 5.0

func clear_screen() -> void:
	is_event_active = false
	_ensure_nodes()

	if header_label:
		header_label.text = "CITY METROPOLITAN FEED"
		header_label.modulate = Color(0.3, 0.7, 1.0, 0.8)

	if title_label:
		title_label.text = default_title
		title_label.modulate = Color(0.4, 0.85, 1.0, 1.0)

	if subtitle_label:
		subtitle_label.text = default_subtitle
		subtitle_label.modulate = Color(0.6, 0.7, 0.8, 0.7)

	if alert_light:
		alert_light.visible = true
		alert_light.light_color = Color(0.2, 0.6, 1.0, 1.0)
		alert_light.light_energy = 1.5

func _ensure_nodes() -> void:
	if not title_label:
		title_label = find_child("TitleLabel", true, false) as Label3D
	if not subtitle_label:
		subtitle_label = find_child("SubtitleLabel", true, false) as Label3D
	if not header_label:
		header_label = find_child("HeaderLabel", true, false) as Label3D
	if not alert_light:
		alert_light = find_child("AlertLight", true, false) as OmniLight3D

func set_screen_power(powered: bool) -> void:
	visible = powered
	if alert_light:
		alert_light.visible = powered
