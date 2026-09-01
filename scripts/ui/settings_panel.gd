extends Control

signal back_pressed

# ── Left Navigation Tabs ────────────────────────────────────────────────────
@onready var btn_gameplay: Button = $Margin/VBoxMain/HBox/LeftNav/VBox/BtnGameplay if has_node("Margin/VBoxMain/HBox/LeftNav/VBox/BtnGameplay") else null
@onready var btn_controls: Button = $Margin/VBoxMain/HBox/LeftNav/VBox/BtnControls if has_node("Margin/VBoxMain/HBox/LeftNav/VBox/BtnControls") else null
@onready var btn_audio: Button = $Margin/VBoxMain/HBox/LeftNav/VBox/BtnAudio if has_node("Margin/VBoxMain/HBox/LeftNav/VBox/BtnAudio") else null
@onready var btn_video: Button = $Margin/VBoxMain/HBox/LeftNav/VBox/BtnVideo if has_node("Margin/VBoxMain/HBox/LeftNav/VBox/BtnVideo") else null
@onready var btn_accessibility: Button = $Margin/VBoxMain/HBox/LeftNav/VBox/BtnAccessibility if has_node("Margin/VBoxMain/HBox/LeftNav/VBox/BtnAccessibility") else null
@onready var btn_back: Button = $Margin/VBoxMain/HBox/LeftNav/VBox/BtnBack if has_node("Margin/VBoxMain/HBox/LeftNav/VBox/BtnBack") else null

# ── Content Sections ────────────────────────────────────────────────────────
@onready var gameplay_section: Control = $Margin/VBoxMain/HBox/RightPanel/GameplaySection if has_node("Margin/VBoxMain/HBox/RightPanel/GameplaySection") else null
@onready var controls_section: Control = $Margin/VBoxMain/HBox/RightPanel/ControlsSection if has_node("Margin/VBoxMain/HBox/RightPanel/ControlsSection") else null
@onready var audio_section: Control = $Margin/VBoxMain/HBox/RightPanel/AudioSection if has_node("Margin/VBoxMain/HBox/RightPanel/AudioSection") else null
@onready var video_section: Control = $Margin/VBoxMain/HBox/RightPanel/VideoSection if has_node("Margin/VBoxMain/HBox/RightPanel/VideoSection") else null
@onready var accessibility_section: Control = $Margin/VBoxMain/HBox/RightPanel/AccessibilitySection if has_node("Margin/VBoxMain/HBox/RightPanel/AccessibilitySection") else null

# ── Gameplay Controls ───────────────────────────────────────────────────────
@onready var diff_option: OptionButton = $Margin/VBoxMain/HBox/RightPanel/GameplaySection/DiffHBox/DifficultyOption if has_node("Margin/VBoxMain/HBox/RightPanel/GameplaySection/DiffHBox/DifficultyOption") else null
@onready var shake_slider: HSlider = $Margin/VBoxMain/HBox/RightPanel/GameplaySection/ShakeHBox/ShakeSlider if has_node("Margin/VBoxMain/HBox/RightPanel/GameplaySection/ShakeHBox/ShakeSlider") else null
@onready var shake_val: Label = $Margin/VBoxMain/HBox/RightPanel/GameplaySection/ShakeHBox/ShakeValue if has_node("Margin/VBoxMain/HBox/RightPanel/GameplaySection/ShakeHBox/ShakeValue") else null
@onready var fov_slider: HSlider = $Margin/VBoxMain/HBox/RightPanel/GameplaySection/FovHBox/FovSlider if has_node("Margin/VBoxMain/HBox/RightPanel/GameplaySection/FovHBox/FovSlider") else null
@onready var fov_val: Label = $Margin/VBoxMain/HBox/RightPanel/GameplaySection/FovHBox/FovValue if has_node("Margin/VBoxMain/HBox/RightPanel/GameplaySection/FovHBox/FovValue") else null

# ── Controls / Sensitivity ───────────────────────────────────────────────────
@onready var hip_slider: HSlider = $Margin/VBoxMain/HBox/RightPanel/ControlsSection/HipSensHBox/HipSensSlider if has_node("Margin/VBoxMain/HBox/RightPanel/ControlsSection/HipSensHBox/HipSensSlider") else null
@onready var hip_val: Label = $Margin/VBoxMain/HBox/RightPanel/ControlsSection/HipSensHBox/HipSensValue if has_node("Margin/VBoxMain/HBox/RightPanel/ControlsSection/HipSensHBox/HipSensValue") else null
@onready var ads_slider: HSlider = $Margin/VBoxMain/HBox/RightPanel/ControlsSection/AdsSensHBox/AdsSensSlider if has_node("Margin/VBoxMain/HBox/RightPanel/ControlsSection/AdsSensHBox/AdsSensSlider") else null
@onready var ads_val: Label = $Margin/VBoxMain/HBox/RightPanel/ControlsSection/AdsSensHBox/AdsSensValue if has_node("Margin/VBoxMain/HBox/RightPanel/ControlsSection/AdsSensHBox/AdsSensValue") else null
@onready var invert_y_check: CheckButton = $Margin/VBoxMain/HBox/RightPanel/ControlsSection/InvertYHBox/InvertYCheck if has_node("Margin/VBoxMain/HBox/RightPanel/ControlsSection/InvertYHBox/InvertYCheck") else null

# ── Audio Controls ──────────────────────────────────────────────────────────
@onready var master_slider: HSlider = $Margin/VBoxMain/HBox/RightPanel/AudioSection/MasterHBox/MasterSlider if has_node("Margin/VBoxMain/HBox/RightPanel/AudioSection/MasterHBox/MasterSlider") else null
@onready var master_label: Label = $Margin/VBoxMain/HBox/RightPanel/AudioSection/MasterHBox/MasterValue if has_node("Margin/VBoxMain/HBox/RightPanel/AudioSection/MasterHBox/MasterValue") else null
@onready var music_slider: HSlider = $Margin/VBoxMain/HBox/RightPanel/AudioSection/MusicHBox/MusicSlider if has_node("Margin/VBoxMain/HBox/RightPanel/AudioSection/MusicHBox/MusicSlider") else null
@onready var music_label: Label = $Margin/VBoxMain/HBox/RightPanel/AudioSection/MusicHBox/MusicValue if has_node("Margin/VBoxMain/HBox/RightPanel/AudioSection/MusicHBox/MusicValue") else null
@onready var sfx_slider: HSlider = $Margin/VBoxMain/HBox/RightPanel/AudioSection/SfxHBox/SfxSlider if has_node("Margin/VBoxMain/HBox/RightPanel/AudioSection/SfxHBox/SfxSlider") else null
@onready var sfx_label: Label = $Margin/VBoxMain/HBox/RightPanel/AudioSection/SfxHBox/SfxValue if has_node("Margin/VBoxMain/HBox/RightPanel/AudioSection/SfxHBox/SfxValue") else null
@onready var mute_check: CheckButton = $Margin/VBoxMain/HBox/RightPanel/AudioSection/MuteHBox/MuteCheck if has_node("Margin/VBoxMain/HBox/RightPanel/AudioSection/MuteHBox/MuteCheck") else null

# ── Video Controls ──────────────────────────────────────────────────────────
@onready var window_option: OptionButton = $Margin/VBoxMain/HBox/RightPanel/VideoSection/WindowModeHBox/WindowModeOption if has_node("Margin/VBoxMain/HBox/RightPanel/VideoSection/WindowModeHBox/WindowModeOption") else null
@onready var vsync_check: CheckButton = $Margin/VBoxMain/HBox/RightPanel/VideoSection/VsyncHBox/VsyncCheck if has_node("Margin/VBoxMain/HBox/RightPanel/VideoSection/VsyncHBox/VsyncCheck") else null
@onready var fps_option: OptionButton = $Margin/VBoxMain/HBox/RightPanel/VideoSection/FpsHBox/FpsOption if has_node("Margin/VBoxMain/HBox/RightPanel/VideoSection/FpsHBox/FpsOption") else null
@onready var fog_check: CheckButton = $Margin/VBoxMain/HBox/RightPanel/VideoSection/FogHBox/FogCheck if has_node("Margin/VBoxMain/HBox/RightPanel/VideoSection/FogHBox/FogCheck") else null

# ── Accessibility Controls ──────────────────────────────────────────────────
@onready var high_contrast_check: CheckButton = $Margin/VBoxMain/HBox/RightPanel/AccessibilitySection/HighContrastHBox/HighContrastCheck if has_node("Margin/VBoxMain/HBox/RightPanel/AccessibilitySection/HighContrastHBox/HighContrastCheck") else null
@onready var flash_check: CheckButton = $Margin/VBoxMain/HBox/RightPanel/AccessibilitySection/FlashHBox/FlashCheck if has_node("Margin/VBoxMain/HBox/RightPanel/AccessibilitySection/FlashHBox/FlashCheck") else null
@onready var hints_check: CheckButton = $Margin/VBoxMain/HBox/RightPanel/AccessibilitySection/HintsHBox/HintsCheck if has_node("Margin/VBoxMain/HBox/RightPanel/AccessibilitySection/HintsHBox/HintsCheck") else null

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	SettingsManager.init_settings()

	_setup_options()
	_setup_navigation()
	_bind_control_signals()
	_load_ui_from_settings()

	# Start on Audio or Gameplay tab
	_switch_tab(0)

	var helper_script = load("res://scripts/ui/ui_audio_helper.gd")
	if helper_script:
		helper_script.setup_ui_audio(self)

func _setup_navigation() -> void:
	if btn_gameplay: btn_gameplay.pressed.connect(func(): _switch_tab(0))
	if btn_controls: btn_controls.pressed.connect(func(): _switch_tab(1))
	if btn_audio: btn_audio.pressed.connect(func(): _switch_tab(2))
	if btn_video: btn_video.pressed.connect(func(): _switch_tab(3))
	if btn_accessibility: btn_accessibility.pressed.connect(func(): _switch_tab(4))
	if btn_back: btn_back.pressed.connect(func():
		SettingsManager.save_to_disk()
		back_pressed.emit()
	)

func _switch_tab(index: int) -> void:
	var sections = [gameplay_section, controls_section, audio_section, video_section, accessibility_section]
	var buttons = [btn_gameplay, btn_controls, btn_audio, btn_video, btn_accessibility]

	for i in range(sections.size()):
		var sec = sections[i]
		if sec:
			sec.visible = (i == index)

		var btn = buttons[i]
		if btn:
			btn.modulate = Color(1.0, 0.85, 0.35, 1.0) if (i == index) else Color(0.85, 0.85, 0.85, 0.75)

func _setup_options() -> void:
	if diff_option:
		diff_option.clear()
		diff_option.add_item("EASY (RELAXED BIRD WATCHING)", 0)
		diff_option.add_item("NORMAL (STANDARD AGGRESSION)", 1)
		diff_option.add_item("HARD (TACTICAL THREAT)", 2)
		diff_option.add_item("GOVERNMENT NIGHTMARE (1 HIT KILL)", 3)

	if window_option:
		window_option.clear()
		window_option.add_item("FULLSCREEN", 0)
		window_option.add_item("BORDERLESS WINDOW", 1)
		window_option.add_item("WINDOWED", 2)

	if fps_option:
		fps_option.clear()
		fps_option.add_item("UNLIMITED FPS", 0)
		fps_option.add_item("60 FPS", 1)
		fps_option.add_item("120 FPS", 2)
		fps_option.add_item("144 FPS", 3)

func _load_ui_from_settings() -> void:
	# Gameplay
	if diff_option: diff_option.select(SettingsManager.current_difficulty)
	if shake_slider:
		shake_slider.value = SettingsManager.camera_shake_mult * 100.0
		if shake_val: shake_val.text = "%d%%" % int(shake_slider.value)
	if fov_slider:
		fov_slider.value = SettingsManager.field_of_view
		if fov_val: fov_val.text = "%d°" % int(fov_slider.value)

	# Controls
	if hip_slider:
		hip_slider.value = SettingsManager.mouse_sens_hip
		if hip_val: hip_val.text = "%.2f" % hip_slider.value
	if ads_slider:
		ads_slider.value = SettingsManager.mouse_sens_ads
		if ads_val: ads_val.text = "%.2f" % ads_slider.value
	if invert_y_check:
		invert_y_check.button_pressed = SettingsManager.invert_y
		invert_y_check.text = "ON" if SettingsManager.invert_y else "OFF"

	# Audio
	if master_slider:
		master_slider.value = SettingsManager.master_volume
		if master_label: master_label.text = "%d%%" % int(master_slider.value)
	if music_slider:
		music_slider.value = SettingsManager.music_volume
		if music_label: music_label.text = "%d%%" % int(music_slider.value)
	if sfx_slider:
		sfx_slider.value = SettingsManager.sfx_volume
		if sfx_label: sfx_label.text = "%d%%" % int(sfx_slider.value)
	if mute_check:
		mute_check.button_pressed = SettingsManager.is_muted
		mute_check.text = "ON" if SettingsManager.is_muted else "OFF"

	# Video
	if window_option: window_option.select(SettingsManager.window_mode)
	if vsync_check:
		vsync_check.button_pressed = SettingsManager.vsync_enabled
		vsync_check.text = "ON" if SettingsManager.vsync_enabled else "OFF"
	if fps_option:
		match SettingsManager.fps_cap:
			60: fps_option.select(1)
			120: fps_option.select(2)
			144: fps_option.select(3)
			_: fps_option.select(0)
	if fog_check:
		fog_check.button_pressed = SettingsManager.distance_fog_enabled
		fog_check.text = "ON" if SettingsManager.distance_fog_enabled else "OFF"

	# Accessibility
	if high_contrast_check:
		high_contrast_check.button_pressed = SettingsManager.high_contrast_hud
		high_contrast_check.text = "ON" if SettingsManager.high_contrast_hud else "OFF"
	if flash_check:
		flash_check.button_pressed = SettingsManager.flash_reduction
		flash_check.text = "ON" if SettingsManager.flash_reduction else "OFF"
	if hints_check:
		hints_check.button_pressed = SettingsManager.show_tutorial_hints
		hints_check.text = "ON" if SettingsManager.show_tutorial_hints else "OFF"

func _bind_control_signals() -> void:
	# Gameplay
	if diff_option:
		diff_option.item_selected.connect(func(idx):
			SettingsManager.current_difficulty = idx
			SettingsManager.save_to_disk()
		)
	if shake_slider:
		shake_slider.value_changed.connect(func(val):
			SettingsManager.camera_shake_mult = val / 100.0
			if shake_val: shake_val.text = "%d%%" % int(val)
			SettingsManager.save_to_disk()
		)
	if fov_slider:
		fov_slider.value_changed.connect(func(val):
			SettingsManager.field_of_view = val
			if fov_val: fov_val.text = "%d°" % int(val)
			SettingsManager.save_to_disk()
		)

	# Controls
	if hip_slider:
		hip_slider.value_changed.connect(func(val):
			SettingsManager.mouse_sens_hip = val
			if hip_val: hip_val.text = "%.2f" % val
			SettingsManager.save_to_disk()
		)
	if ads_slider:
		ads_slider.value_changed.connect(func(val):
			SettingsManager.mouse_sens_ads = val
			if ads_val: ads_val.text = "%.2f" % val
			SettingsManager.save_to_disk()
		)
	if invert_y_check:
		invert_y_check.toggled.connect(func(btn_on):
			SettingsManager.invert_y = btn_on
			invert_y_check.text = "ON" if btn_on else "OFF"
			SettingsManager.save_to_disk()
		)

	# Audio
	if master_slider:
		master_slider.value_changed.connect(func(val):
			SettingsManager.master_volume = val
			if master_label: master_label.text = "%d%%" % int(val)
			SettingsManager.apply_all_settings()
			SettingsManager.save_to_disk()
		)
	if music_slider:
		music_slider.value_changed.connect(func(val):
			SettingsManager.music_volume = val
			if music_label: music_label.text = "%d%%" % int(val)
			SettingsManager.save_to_disk()
		)
	if sfx_slider:
		sfx_slider.value_changed.connect(func(val):
			SettingsManager.sfx_volume = val
			if sfx_label: sfx_label.text = "%d%%" % int(val)
			SettingsManager.save_to_disk()
		)
	if mute_check:
		mute_check.toggled.connect(func(btn_on):
			SettingsManager.is_muted = btn_on
			mute_check.text = "ON" if btn_on else "OFF"
			SettingsManager.apply_all_settings()
			SettingsManager.save_to_disk()
		)

	# Video
	if window_option:
		window_option.item_selected.connect(func(idx):
			SettingsManager.window_mode = idx
			SettingsManager.apply_all_settings()
			SettingsManager.save_to_disk()
		)
	if vsync_check:
		vsync_check.toggled.connect(func(btn_on):
			SettingsManager.vsync_enabled = btn_on
			vsync_check.text = "ON" if btn_on else "OFF"
			SettingsManager.apply_all_settings()
			SettingsManager.save_to_disk()
		)
	if fps_option:
		fps_option.item_selected.connect(func(idx):
			var caps = [0, 60, 120, 144]
			SettingsManager.fps_cap = caps[idx] if idx < caps.size() else 0
			SettingsManager.apply_all_settings()
			SettingsManager.save_to_disk()
		)
	if fog_check:
		fog_check.toggled.connect(func(btn_on):
			SettingsManager.distance_fog_enabled = btn_on
			fog_check.text = "ON" if btn_on else "OFF"
			SettingsManager.save_to_disk()
		)

	# Accessibility
	if high_contrast_check:
		high_contrast_check.toggled.connect(func(btn_on):
			SettingsManager.high_contrast_hud = btn_on
			high_contrast_check.text = "ON" if btn_on else "OFF"
			SettingsManager.save_to_disk()
		)
	if flash_check:
		flash_check.toggled.connect(func(btn_on):
			SettingsManager.flash_reduction = btn_on
			flash_check.text = "ON" if btn_on else "OFF"
			SettingsManager.save_to_disk()
		)
	if hints_check:
		hints_check.toggled.connect(func(btn_on):
			SettingsManager.show_tutorial_hints = btn_on
			hints_check.text = "ON" if btn_on else "OFF"
			SettingsManager.save_to_disk()
		)
