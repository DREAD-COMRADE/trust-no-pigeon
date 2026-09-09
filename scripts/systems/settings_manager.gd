extends Node
class_name SettingsManager

# ── Global Settings Store & Config Persistence ──────────────────────────────
const CONFIG_PATH = "user://game_settings.cfg"

enum Difficulty { EASY, NORMAL, HARD, NIGHTMARE }

static var current_difficulty: int = Difficulty.NORMAL
static var camera_shake_mult: float = 1.0
static var field_of_view: float = 75.0
static var show_crosshair: bool = true

static var mouse_sens_hip: float = 0.15
static var mouse_sens_ads: float = 0.07
static var invert_y: bool = false
static var invert_x: bool = false

static var master_volume: float = 80.0
static var music_volume: float = 60.0
static var sfx_volume: float = 75.0
static var is_muted: bool = false

static var window_mode: int = 0 # 0=Fullscreen, 1=Borderless, 2=Windowed
static var vsync_enabled: bool = true
static var fps_cap: int = 0 # 0=Unlimited, 60, 120, 144
static var distance_fog_enabled: bool = true

static var high_contrast_hud: bool = false
static var flash_reduction: bool = false
static var show_tutorial_hints: bool = true

static var is_initialized: bool = false

static func init_settings() -> void:
	if is_initialized:
		return
	is_initialized = true
	load_from_disk()
	apply_all_settings()

static func load_from_disk() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err != OK:
		return # Use defaults

	current_difficulty = cfg.get_value("gameplay", "difficulty", Difficulty.NORMAL)
	camera_shake_mult = cfg.get_value("gameplay", "camera_shake", 1.0)
	field_of_view = cfg.get_value("gameplay", "fov", 75.0)
	show_crosshair = cfg.get_value("gameplay", "show_crosshair", true)

	mouse_sens_hip = cfg.get_value("controls", "sens_hip", 0.15)
	mouse_sens_ads = cfg.get_value("controls", "sens_ads", 0.07)
	invert_y = cfg.get_value("controls", "invert_y", false)
	invert_x = cfg.get_value("controls", "invert_x", false)

	master_volume = cfg.get_value("audio", "master", 80.0)
	music_volume = cfg.get_value("audio", "music", 60.0)
	sfx_volume = cfg.get_value("audio", "sfx", 75.0)
	is_muted = cfg.get_value("audio", "muted", false)

	window_mode = cfg.get_value("video", "window_mode", 0)
	vsync_enabled = cfg.get_value("video", "vsync", true)
	fps_cap = cfg.get_value("video", "fps_cap", 0)
	distance_fog_enabled = cfg.get_value("video", "fog", true)

	high_contrast_hud = cfg.get_value("accessibility", "high_contrast", false)
	flash_reduction = cfg.get_value("accessibility", "flash_reduction", false)
	show_tutorial_hints = cfg.get_value("accessibility", "hints", true)

static func save_to_disk() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("gameplay", "difficulty", current_difficulty)
	cfg.set_value("gameplay", "camera_shake", camera_shake_mult)
	cfg.set_value("gameplay", "fov", field_of_view)
	cfg.set_value("gameplay", "show_crosshair", show_crosshair)

	cfg.set_value("controls", "sens_hip", mouse_sens_hip)
	cfg.set_value("controls", "sens_ads", mouse_sens_ads)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("controls", "invert_x", invert_x)

	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "muted", is_muted)

	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "vsync", vsync_enabled)
	cfg.set_value("video", "fps_cap", fps_cap)
	cfg.set_value("video", "fog", distance_fog_enabled)

	cfg.set_value("accessibility", "high_contrast", high_contrast_hud)
	cfg.set_value("accessibility", "flash_reduction", flash_reduction)
	cfg.set_value("accessibility", "hints", show_tutorial_hints)

	cfg.save(CONFIG_PATH)

static func apply_all_settings() -> void:
	# Apply Audio
	var m_vol = 0.0 if is_muted else master_volume
	var db_master = linear_to_db(m_vol / 100.0) if m_vol > 0 else -80.0
	AudioServer.set_bus_volume_db(0, db_master)

	# Apply Display Mode
	match window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS) else DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Apply VSync
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

	# Apply FPS Cap
	Engine.max_fps = fps_cap

	# Notify active scenes/listeners
	for cb in _settings_listeners:
		if cb.is_valid():
			cb.call()

static var _settings_listeners: Array[Callable] = []

static func register_listener(cb: Callable) -> void:
	if not _settings_listeners.has(cb):
		_settings_listeners.append(cb)

static func unregister_listener(cb: Callable) -> void:
	_settings_listeners.erase(cb)

static func get_difficulty_speed_mult() -> float:
	match current_difficulty:
		Difficulty.EASY: return 0.85
		Difficulty.NORMAL: return 1.0
		Difficulty.HARD: return 1.20
		Difficulty.NIGHTMARE: return 1.45
	return 1.0

static func get_difficulty_max_hearts() -> int:
	return 3
