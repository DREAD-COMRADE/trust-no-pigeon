extends Control

signal back_pressed

@onready var master_slider: HSlider = $Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/MasterHBox/MasterSlider if has_node("Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/MasterHBox/MasterSlider") else null
@onready var master_label: Label = $Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/MasterHBox/MasterValue if has_node("Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/MasterHBox/MasterValue") else null

@onready var music_slider: HSlider = $Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/MusicHBox/MusicSlider if has_node("Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/MusicHBox/MusicSlider") else null
@onready var music_label: Label = $Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/MusicHBox/MusicValue if has_node("Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/MusicHBox/MusicValue") else null

@onready var sfx_slider: HSlider = $Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/SfxHBox/SfxSlider if has_node("Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/SfxHBox/SfxSlider") else null
@onready var sfx_label: Label = $Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/SfxHBox/SfxValue if has_node("Margin/VBoxMain/HBox/RightPanel/VBox/AudioSection/SfxHBox/SfxValue") else null

@onready var btn_back: Button = $Margin/VBoxMain/HBox/LeftNav/VBox/BtnBack if has_node("Margin/VBoxMain/HBox/LeftNav/VBox/BtnBack") else null

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	if btn_back:
		btn_back.pressed.connect(func(): back_pressed.emit())

	if master_slider:
		master_slider.value_changed.connect(_on_master_changed)
		_on_master_changed(master_slider.value)

	if music_slider:
		music_slider.value_changed.connect(_on_music_changed)
		_on_music_changed(music_slider.value)

	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_changed)
		_on_sfx_changed(sfx_slider.value)

func _on_master_changed(val: float) -> void:
	if master_label:
		master_label.text = str(int(val)) + "%"
	var db = linear_to_db(val / 100.0) if val > 0 else -80.0
	AudioServer.set_bus_volume_db(0, db)

func _on_music_changed(val: float) -> void:
	if music_label:
		music_label.text = str(int(val)) + "%"

func _on_sfx_changed(val: float) -> void:
	if sfx_label:
		sfx_label.text = str(int(val)) + "%"
