extends CanvasLayer

@warning_ignore("unused_signal")
signal restart_requested

# ── Swappable Panel References (override in Inspector to swap your own scenes) ──
# Each of these points to a top-level panel node in HUD.tscn.
# You can hide/replace any of them without touching the others.
@export_group("Swappable Panels")
@export var objective_panel_path: NodePath = ^"ObjectivePanel"
@export var compass_panel_path: NodePath = ^"TopCenterPill"
@export var score_panel_path: NodePath = ^"ScorePanel"
@export var toast_panel_path: NodePath = ^"EventToast"
@export var status_panel_path: NodePath = ^"PlayerStatusPanel"
@export var health_panel_path: NodePath = ^"HealthHeartsPanel"
@export var weapon_panel_path: NodePath = ^"WeaponPanel"
@export_group("")

# ── Camera ref for compass (auto-resolved from scene) ─────────────────────────
var _camera: Camera3D

# ── Node references ───────────────────────────────────────────────────────────
# Objective
@onready var obj_line1: Label = get_node_or_null("ObjectivePanel/ObjBg/ObjVBox/ObjAccentRow/ObjTextVBox/ObjLine1")
@onready var obj_line2: Label = get_node_or_null("ObjectivePanel/ObjBg/ObjVBox/ObjAccentRow/ObjTextVBox/ObjLine2")

# Compass (top-center)
@onready var compass_label: Label     = get_node_or_null("TopCenterPill/CenterBg/CenterHBox/CompassLabel")
@onready var next_event_label: Label  = get_node_or_null("TopCenterPill/CenterBg/CenterHBox/NextEventLabel")
@onready var aggression_label: Label  = get_node_or_null("TopCenterPill/CenterBg/CenterHBox/AggressionLabel")

# Score (top-right)
@onready var score_label: Label      = get_node_or_null("ScorePanel/ScoreBg/ScoreHBox/ScoreLabel")
@onready var high_score_label: Label = get_node_or_null("ScorePanel/ScoreBg/ScoreHBox/HighScoreLabel")

# Toast (top-right feedback)
@onready var event_toast: Control      = get_node_or_null("EventToast")
@onready var event_toast_label: Label  = get_node_or_null("EventToast/ToastPanel/ToastHBox/ToastLabel")
@onready var event_toast_points: Label = get_node_or_null("EventToast/ToastPanel/ToastHBox/ToastPoints")

# Player Status (bottom-left bars)
@onready var hp_bar: PanelContainer    = get_node_or_null("PlayerStatusPanel/StatusBg/StatusVBox/HPRow/HPBarBg/HPBar")
@onready var armor_bar: PanelContainer = get_node_or_null("PlayerStatusPanel/StatusBg/StatusVBox/ArmorRow/ArmorBarBg/ArmorBar")
@onready var hp_value_label: Label     = get_node_or_null("PlayerStatusPanel/StatusBg/StatusVBox/HPRow/HPValueLabel")
@onready var armor_value_label: Label  = get_node_or_null("PlayerStatusPanel/StatusBg/StatusVBox/ArmorRow/ArmorValueLabel")

# Health Hearts (bottom-center)
@onready var heart1: Label = get_node_or_null("HealthHeartsPanel/HeartsBg/HeartsRow/Heart1")
@onready var heart2: Label = get_node_or_null("HealthHeartsPanel/HeartsBg/HeartsRow/Heart2")
@onready var heart3: Label = get_node_or_null("HealthHeartsPanel/HeartsBg/HeartsRow/Heart3")

# Weapon & Ammo (bottom-right)
@onready var ammo_loaded_label: Label  = get_node_or_null("WeaponPanel/WeaponBg/WeaponVBox/AmmoRow/AmmoLoaded")
@onready var ammo_slash_label: Label   = get_node_or_null("WeaponPanel/WeaponBg/WeaponVBox/AmmoRow/AmmoSlash")
@onready var ammo_reserve_label: Label = get_node_or_null("WeaponPanel/WeaponBg/WeaponVBox/AmmoRow/AmmoReserve")
@onready var weapon_icon_label: Label  = get_node_or_null("WeaponPanel/WeaponBg/WeaponVBox/AmmoRow/WeaponIcon")
@onready var slot_label1: Label = get_node_or_null("WeaponPanel/WeaponBg/WeaponVBox/SlotRow/SlotLabel1")
@onready var slot_label2: Label = get_node_or_null("WeaponPanel/WeaponBg/WeaponVBox/SlotRow/SlotLabel2")
@onready var slot_label3: Label = get_node_or_null("WeaponPanel/WeaponBg/WeaponVBox/SlotRow/SlotLabel3")

# Debug & Game Over
@onready var debug_panel: Control      = $DebugPanel if has_node("DebugPanel") else null
@onready var game_over_panel: Control  = $GameOverPanel
@onready var final_score_label: Label  = get_node_or_null("GameOverPanel/VBox/ScoreHBox/ScoreVBox/FinalScoreLabel")
@onready var high_score_value_label: Label = get_node_or_null("GameOverPanel/VBox/ScoreHBox/HighScoreVBox/HighScoreValueLabel")
@onready var gov_kills_label: Label    = get_node_or_null("GameOverPanel/VBox/StatsVBox/GovKillsLabel")
@onready var accuracy_label: Label     = get_node_or_null("GameOverPanel/VBox/StatsVBox/AccuracyLabel")
@onready var message_label: Label      = get_node_or_null("GameOverPanel/VBox/MessageLabel")
@onready var restart_button: Button    = get_node_or_null("GameOverPanel/VBox/RestartButton")

# ── Internal state ────────────────────────────────────────────────────────────
var toast_tween: Tween
var cur_active_slot: int = 0

var game_over_bad_stream: AudioStream = preload("res://assets/Audio/GAME_OVER.mp3")
var game_over_good_stream: AudioStream = preload("res://assets/Audio/Game_over_2.mp3")
var game_over_audio: AudioStreamPlayer

# Compass direction table (yaw in degrees → label string)
const COMPASS_DIRS: Array = [
	[0,   "N"], [22,  "NNE"], [45, "NE"], [67,  "ENE"],
	[90,  "E"], [112, "ESE"], [135,"SE"], [157, "SSE"],
	[180, "S"], [202, "SSW"], [225,"SW"], [247, "WSW"],
	[270, "W"], [292, "WNW"], [315,"NW"], [337, "NNW"], [360, "N"]
]

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	game_over_panel.visible = false
	if event_toast:
		event_toast.modulate.a = 0.0
		event_toast.visible = false

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

	# Bind UI click audio
	var helper_script = load("res://scripts/ui/ui_audio_helper.gd")
	if helper_script:
		helper_script.setup_ui_audio(self)

	# Default weapon display
	update_weapon_ui(0, 6, 0, 18)
	_update_hearts(3, 3)

	# Auto-resolve camera for compass
	await get_tree().process_frame
	var scene = get_tree().current_scene
	if scene:
		var cam = scene.find_child("Camera3D", true, false)
		if cam is Camera3D:
			_camera = cam

# ── Process — Compass ─────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not compass_label:
		return
	if not _camera:
		# Try to find camera lazily
		if get_tree() and get_tree().current_scene:
			var cam = get_tree().current_scene.find_child("Camera3D", true, false)
			if cam is Camera3D:
				_camera = cam
		return

	# Build scrolling compass string from camera yaw
	var yaw_deg = fmod(rad_to_deg(-_camera.rotation.y) + 360.0, 360.0)
	compass_label.text = _build_compass_string(yaw_deg)

func _build_compass_string(yaw_deg: float) -> String:
	# Show a window of directions centered on the current heading.
	# We generate a band of cardinal/intercardinal labels spaced ~45° apart.
	const WINDOW: float = 90.0   # degrees visible either side
	const TICK_EVERY: float = 22.5  # label every 22.5 degrees

	var entries: Array = []
	var start_deg = yaw_deg - WINDOW
	var end_deg = yaw_deg + WINDOW

	var angle = floor(start_deg / TICK_EVERY) * TICK_EVERY
	while angle <= end_deg:
		var norm = fmod(angle + 360.0, 360.0)
		var label = _deg_to_dir(norm)
		var weight = abs(angle - yaw_deg)  # 0 = center
		# Center marker
		if weight < 4.0:
			entries.append("[ %s ]" % label)
		elif weight < 14.0:
			entries.append(label)
		else:
			entries.append(label.to_lower())
		angle += TICK_EVERY

	return "  ".join(entries)

func _deg_to_dir(deg: float) -> String:
	# Snap to nearest compass point
	var snapped = round(deg / 22.5) * 22.5
	var idx = int(fmod(snapped, 360.0) / 22.5) % 16
	const DIRS = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
	return DIRS[idx]

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F1 and event.pressed and not event.echo:
		if debug_panel and debug_panel.has_method("toggle_panel"):
			debug_panel.toggle_panel()
			get_viewport().set_input_as_handled()
		return

	if game_over_panel.visible:
		if event.is_action_pressed("shoot") or (event is InputEventKey and event.keycode == KEY_R and event.pressed):
			_on_restart_pressed()

# ── Score ─────────────────────────────────────────────────────────────────────
func update_score(score: int, high_score: int) -> void:
	if score_label:
		score_label.text = str(score)
	if high_score_label:
		high_score_label.text = "  HI: " + str(high_score)

# ── Aggression ────────────────────────────────────────────────────────────────
func update_aggression(level: int, status_text: String) -> void:
	if aggression_label:
		aggression_label.text = status_text
		aggression_label.modulate = Color(1.0, 0.3, 0.3, 0.9) if level > 0 else Color(0.4, 0.9, 0.4, 0.9)

# ── Timer / Event ─────────────────────────────────────────────────────────────
@warning_ignore("integer_division")
func update_run_time(time_seconds: float, next_event_seconds: float) -> void:
	if next_event_label:
		var n_total: int = int(next_event_seconds)
		var n_mins: int = int(float(n_total) / 60.0)
		var n_secs: int = n_total % 60
		next_event_label.text = "NEXT %02d:%02d" % [n_mins, n_secs]

# ── Health Hearts ─────────────────────────────────────────────────────────────
func _update_hearts(current: int, maximum: int) -> void:
	const FULL  = "❤"
	const EMPTY = "♡"
	const FULL_COLOR  = Color(1.0, 0.22, 0.22, 1.0)
	const EMPTY_COLOR = Color(1.0, 1.0, 1.0, 0.2)

	var hearts = [heart1, heart2, heart3]
	for i in range(hearts.size()):
		var h = hearts[i]
		if h:
			if i < maximum:
				h.visible = true
				h.text = FULL if i < current else EMPTY
				h.modulate = FULL_COLOR if i < current else EMPTY_COLOR
			else:
				h.visible = false

func update_health(current: int, maximum: int) -> void:
	_update_hearts(current, maximum)

# ── Player Status Bars (armor / HP percent bars) ──────────────────────────────
func update_player_status(hp: int, max_hp: int, armor: int, max_armor: int) -> void:
	# HP bar fill (anchor_right = hp ratio)
	if hp_bar:
		var ratio = clamp(float(hp) / float(max(1, max_hp)), 0.0, 1.0)
		hp_bar.anchor_right = ratio
	if hp_value_label:
		hp_value_label.text = str(hp)

	# Armor bar fill
	if armor_bar:
		var ratio = clamp(float(armor) / float(max(1, max_armor)), 0.0, 1.0)
		armor_bar.anchor_right = ratio
	if armor_value_label:
		armor_value_label.text = str(armor)

# ── Weapon & Ammo ─────────────────────────────────────────────────────────────
func update_weapon_ui(slot: int, shotgun_ammo: int, rocket_ammo: int, shotgun_reserve: int = 0) -> void:
	cur_active_slot = slot

	# Active slot highlights
	const ACTIVE_COLOR   = Color(0.95, 0.95, 0.95, 1.0)
	const INACTIVE_COLOR = Color(0.5, 0.5, 0.5, 0.45)
	const EMPTY_COLOR    = Color(1.0, 0.35, 0.35, 0.9)

	if slot_label1: slot_label1.modulate = ACTIVE_COLOR if slot == 0 else INACTIVE_COLOR
	if slot_label2: slot_label2.modulate = ACTIVE_COLOR if slot == 1 else INACTIVE_COLOR
	if slot_label3: slot_label3.modulate = ACTIVE_COLOR if slot == 2 else INACTIVE_COLOR

	match slot:
		0: # Gun — infinite
			if ammo_loaded_label:  ammo_loaded_label.text = "∞"
			if ammo_slash_label:   ammo_slash_label.visible = false
			if ammo_reserve_label: ammo_reserve_label.visible = false
			if weapon_icon_label:  weapon_icon_label.text = "🔫"
		1: # Shotgun
			if ammo_loaded_label:
				ammo_loaded_label.text = str(shotgun_ammo)
				ammo_loaded_label.modulate = EMPTY_COLOR if shotgun_ammo == 0 else ACTIVE_COLOR
			if ammo_slash_label:   ammo_slash_label.visible = true
			if ammo_reserve_label:
				ammo_reserve_label.visible = true
				ammo_reserve_label.text = str(shotgun_reserve)
				ammo_reserve_label.modulate = EMPTY_COLOR if shotgun_reserve == 0 else INACTIVE_COLOR
			if weapon_icon_label:  weapon_icon_label.text = "⌂"
		2: # Rocket
			if ammo_loaded_label:
				ammo_loaded_label.text = str(rocket_ammo)
				ammo_loaded_label.modulate = EMPTY_COLOR if rocket_ammo == 0 else ACTIVE_COLOR
			if ammo_slash_label:   ammo_slash_label.visible = false
			if ammo_reserve_label: ammo_reserve_label.visible = false
			if weapon_icon_label:  weapon_icon_label.text = "🚀"

# ── Toast / Feedback ──────────────────────────────────────────────────────────
func show_event_banner(title: String, points_text: String = "") -> void:
	if not event_toast or not event_toast_label:
		return

	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()

	event_toast_label.text = title.to_upper()
	if event_toast_points:
		event_toast_points.text = points_text
		event_toast_points.visible = points_text != ""

	event_toast.visible = true

	toast_tween = create_tween()
	toast_tween.tween_property(event_toast, "modulate:a", 1.0, 0.15)
	toast_tween.tween_interval(1.8)
	toast_tween.tween_property(event_toast, "modulate:a", 0.0, 0.35)
	toast_tween.tween_callback(func(): event_toast.visible = false)

# ── Objective ─────────────────────────────────────────────────────────────────
func update_objective(line1: String, line2: String = "") -> void:
	if obj_line1: obj_line1.text = line1
	if obj_line2:
		obj_line2.text = line2
		obj_line2.visible = line2 != ""

# ── Game Over ─────────────────────────────────────────────────────────────────
func show_game_over(final_score: int, high_score: int, gov_kills: int, total_kills: int, shots_fired: int) -> void:
	game_over_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var main = get_tree().current_scene
	if main and main.has_node("Systems/MusicManager"):
		var mm = main.get_node("Systems/MusicManager")
		if mm and mm.has_method("stop_music"):
			mm.stop_music()

	if final_score_label:      final_score_label.text = str(final_score)
	if high_score_value_label: high_score_value_label.text = str(high_score)
	if gov_kills_label:        gov_kills_label.text = "SURVEILLANCE PIGEONS KILLED: " + str(gov_kills)

	var accuracy_pct = int((float(total_kills) / float(max(1, shots_fired))) * 100.0)
	if accuracy_label:
		accuracy_label.text = "ACCURACY: %d%% (%d BIRDS / %d BULLETS)" % [accuracy_pct, total_kills, shots_fired]

	var is_good_run = (gov_kills >= 3 or final_score >= 1500 or (shots_fired >= 5 and accuracy_pct >= 60))

	if message_label:
		var eval_msg = ""
		var msg_color = Color(1.0, 0.85, 0.3, 1.0)

		if shots_fired >= 5 and total_kills < 3:
			is_good_run = false
			eval_msg = "CRITICAL ACCURACY FAILURE: You fired %d bullets and hit only %d birds!" % [shots_fired, total_kills]
			msg_color = Color(1.0, 0.35, 0.35, 1.0)
		elif gov_kills >= 5:
			is_good_run = true
			eval_msg = "EXCELLENT RESISTANCE: Outstanding! You compromised %d government surveillance units!" % gov_kills
			msg_color = Color(0.35, 1.0, 0.45, 1.0)
		elif gov_kills == 0:
			is_good_run = false
			eval_msg = "SURVEILLANCE COMPLETE: You failed to eliminate any government pigeons."
			msg_color = Color(0.95, 0.55, 0.2, 1.0)
		elif final_score >= 1500:
			is_good_run = true
			eval_msg = "HIGH VALUE OPERATIVE: Impressive tactical marksmanship against avian surveillance forces!"
			msg_color = Color(0.35, 0.9, 1.0, 1.0)
		else:
			eval_msg = "PROTOCOL EXECUTED: A government pigeon payload detonated on your position."

		message_label.text = eval_msg
		message_label.modulate = msg_color

	if not game_over_audio:
		game_over_audio = AudioStreamPlayer.new()
		game_over_audio.bus = &"Master"
		add_child(game_over_audio)

	game_over_audio.stream = game_over_good_stream if is_good_run else game_over_bad_stream
	game_over_audio.volume_db = 0.0
	game_over_audio.play()

func _on_restart_pressed() -> void:
	if game_over_audio:
		game_over_audio.stop()
	get_tree().paused = false
	restart_requested.emit()
