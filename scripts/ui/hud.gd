extends CanvasLayer

@warning_ignore("unused_signal")
signal restart_requested

# ── Weapon Icon Textures (Configured or loaded automatically) ───────────────
@export_group("Weapon Textures")
@export var weapon_icon_pistol: Texture2D = preload("res://assets/icons/weapons/Pistol_icon.png")
@export var weapon_icon_shotgun: Texture2D = preload("res://assets/icons/weapons/shortgun_icon.png")
@export var weapon_icon_rocket: Texture2D = preload("res://assets/icons/weapons/Rocket_launcher_icon.png")
@export_group("")

# ── Swappable Panel References ──────────────────────────────────────────────
@export_group("Swappable Panels")
@export var objective_panel_path: NodePath = ^"ObjectivePanel"
@export var compass_panel_path: NodePath = ^"TopCenterPill"
@export var score_panel_path: NodePath = ^"ScorePanel"
@export var toast_panel_path: NodePath = ^"EventToast"
@export var status_panel_path: NodePath = ^"PlayerStatusPanel"
@export var health_panel_path: NodePath = ^"HealthHeartsPanel"
@export var weapon_panel_path: NodePath = ^"WeaponPanel"
@export_group("")

# ── Camera ref for compass ───────────────────────────────────────────────────
var _camera: Camera3D

# ── Node references ───────────────────────────────────────────────────────────
# Objective
@onready var obj_line1: Label = get_node_or_null("ObjectivePanel/ObjVBox/ObjAccentRow/ObjTextVBox/ObjLine1")
@onready var obj_line2: Label = get_node_or_null("ObjectivePanel/ObjVBox/ObjAccentRow/ObjTextVBox/ObjLine2")

# Compass (top-center)
@onready var compass_label: Label = get_node_or_null("TopCenterPill/CenterHBox/CompassLabel")

# Score (top-right)
@onready var score_label: Label = get_node_or_null("ScorePanel/ScoreHBox/ScoreLabel")
@onready var high_score_label: Label = get_node_or_null("ScorePanel/ScoreHBox/HighScoreLabel")

# Toast (top-right feedback popup)
@onready var event_toast: Control = get_node_or_null("EventToast")
@onready var event_toast_label: Label = get_node_or_null("EventToast/ToastPanel/ToastHBox/ToastLabel")
@onready var event_toast_points: Label = get_node_or_null("EventToast/ToastPanel/ToastHBox/ToastPoints")

# Player Status (bottom-left)
@onready var shield_bar: PanelContainer = get_node_or_null("PlayerStatusPanel/StatusVBox/ShieldRow/ShieldBarBg/ShieldBar")
@onready var hp_bar: PanelContainer = get_node_or_null("PlayerStatusPanel/StatusVBox/HPRow/HPBarBg/HPBar")
@onready var shield_value_label: Label = get_node_or_null("PlayerStatusPanel/StatusVBox/ShieldRow/ShieldValueLabel")
@onready var hp_value_label: Label = get_node_or_null("PlayerStatusPanel/StatusVBox/HPRow/HPValueLabel")

# Health Hearts (bottom-center)
@onready var heart1: Label = get_node_or_null("HealthHeartsPanel/HeartsVBox/HeartsRow/Heart1")
@onready var heart2: Label = get_node_or_null("HealthHeartsPanel/HeartsVBox/HeartsRow/Heart2")
@onready var heart3: Label = get_node_or_null("HealthHeartsPanel/HeartsVBox/HeartsRow/Heart3")
@onready var wave_label: Label = get_node_or_null("HealthHeartsPanel/HeartsVBox/WaveLabel")

# Weapon & Ammo (bottom-right)
@onready var ammo_loaded_label: Label = get_node_or_null("WeaponPanel/WeaponVBox/AmmoRow/AmmoLoaded")
@onready var ammo_slash_label: Label = get_node_or_null("WeaponPanel/WeaponVBox/AmmoRow/AmmoSlash")
@onready var ammo_reserve_label: Label = get_node_or_null("WeaponPanel/WeaponVBox/AmmoRow/AmmoReserve")
@onready var weapon_icon: TextureRect = get_node_or_null("WeaponPanel/WeaponVBox/AmmoRow/WeaponIcon")

# Slot Selector Underlines
@onready var slot_label1: Label = get_node_or_null("WeaponPanel/WeaponVBox/SlotRow/Slot1VBox/SlotLabel1")
@onready var underline1: Panel = get_node_or_null("WeaponPanel/WeaponVBox/SlotRow/Slot1VBox/Underline1")
@onready var slot_label2: Label = get_node_or_null("WeaponPanel/WeaponVBox/SlotRow/Slot2VBox/SlotLabel2")
@onready var underline2: Panel = get_node_or_null("WeaponPanel/WeaponVBox/SlotRow/Slot2VBox/Underline2")
@onready var slot_label3: Label = get_node_or_null("WeaponPanel/WeaponVBox/SlotRow/Slot3VBox/SlotLabel3")
@onready var underline3: Panel = get_node_or_null("WeaponPanel/WeaponVBox/SlotRow/Slot3VBox/Underline3")

# Debug & Game Over
@onready var debug_panel: Control = $DebugPanel if has_node("DebugPanel") else null
@onready var game_over_panel: Control = $GameOverPanel
@onready var final_score_label: Label = get_node_or_null("GameOverPanel/VBox/ScoreHBox/ScoreVBox/FinalScoreLabel")
@onready var high_score_value_label: Label = get_node_or_null("GameOverPanel/VBox/ScoreHBox/HighScoreVBox/HighScoreValueLabel")
@onready var gov_kills_label: Label = get_node_or_null("GameOverPanel/VBox/StatsVBox/GovKillsLabel")
@onready var accuracy_label: Label = get_node_or_null("GameOverPanel/VBox/StatsVBox/AccuracyLabel")
@onready var message_label: Label = get_node_or_null("GameOverPanel/VBox/MessageLabel")
@onready var restart_button: Button = get_node_or_null("GameOverPanel/VBox/RestartButton")

# ── Internal state ────────────────────────────────────────────────────────────
var toast_tween: Tween
var cur_active_slot: int = 0

var game_over_bad_stream: AudioStream = preload("res://assets/Audio/GAME_OVER.mp3")
var game_over_good_stream: AudioStream = preload("res://assets/Audio/Game_over_2.mp3")
var game_over_audio: AudioStreamPlayer

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

	# Initial setup
	update_score(0, 0)
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
		if get_tree() and get_tree().current_scene:
			var cam = get_tree().current_scene.find_child("Camera3D", true, false)
			if cam is Camera3D:
				_camera = cam
		return

	# Calculate 360 heading tape
	var yaw_deg = fmod(rad_to_deg(-_camera.rotation.y) + 360.0, 360.0)
	compass_label.text = _build_compass_tape(yaw_deg)

func _build_compass_tape(yaw_deg: float) -> String:
	# Format matches reference tape: e.g. 6   NW   330   345   N   15   30   NE   45
	const STEP: float = 15.0
	const WINDOW: float = 75.0

	var tape_items: Array = []
	var start_deg = yaw_deg - WINDOW
	var end_deg = yaw_deg + WINDOW

	var angle = floor(start_deg / STEP) * STEP
	while angle <= end_deg:
		var norm = int(fmod(angle + 360.0, 360.0))
		var label = _deg_to_bearing_label(norm)
		var diff = abs(angle - yaw_deg)

		if diff < 6.0:
			tape_items.append("│ %s │" % label)
		else:
			tape_items.append(label)

		angle += STEP

	return "      ".join(tape_items)

func _deg_to_bearing_label(deg: int) -> String:
	match deg:
		0, 360: return "N"
		45: return "NE"
		90: return "E"
		135: return "SE"
		180: return "S"
		225: return "SW"
		270: return "W"
		315: return "NW"
		_: return str(deg)

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
		# Format with comma separators (e.g. 1,250)
		score_label.text = _format_number_commas(score)
	if high_score_label:
		high_score_label.text = "HI: " + _format_number_commas(high_score)

func _format_number_commas(num: int) -> String:
	var s = str(abs(num))
	var res = ""
	var cnt = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "," + res
	return ("-" if num < 0 else "") + res

# ── Aggression / Event ────────────────────────────────────────────────────────
func update_aggression(_level: int, _status_text: String) -> void:
	pass # Minimal HUD keeps center clear

@warning_ignore("integer_division")
func update_run_time(_time_seconds: float, _next_event_seconds: float) -> void:
	pass

# ── Health Hearts ─────────────────────────────────────────────────────────────
func _update_hearts(current: int, maximum: int) -> void:
	const FULL = "❤"
	const EMPTY = "♡"
	const FULL_COLOR = Color(1.0, 0.22, 0.22, 1.0)
	const EMPTY_COLOR = Color(1.0, 1.0, 1.0, 0.25)

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

# ── Player Status Bars (Shield & HP) ──────────────────────────────────────────
func update_player_status(hp: int, max_hp: int, shield: int, max_shield: int) -> void:
	if hp_bar:
		var ratio = clamp(float(hp) / float(max(1, max_hp)), 0.0, 1.0)
		hp_bar.anchor_right = ratio
	if hp_value_label:
		hp_value_label.text = str(hp)

	if shield_bar:
		var ratio = clamp(float(shield) / float(max(1, max_shield)), 0.0, 1.0)
		shield_bar.anchor_right = ratio
	if shield_value_label:
		shield_value_label.text = str(shield)

# ── Weapon & Ammo (Segmented Layout with Icons & Underline) ───────────────────
func update_weapon_ui(slot: int, shotgun_ammo: int, rocket_ammo: int, shotgun_reserve: int = 0) -> void:
	cur_active_slot = slot

	const ACTIVE_LABEL_COLOR = Color(1.0, 1.0, 1.0, 1.0)
	const INACTIVE_LABEL_COLOR = Color(0.6, 0.62, 0.65, 0.5)

	# Update 1 2 3 slot labels & active underlines
	if slot_label1: slot_label1.modulate = ACTIVE_LABEL_COLOR if slot == 0 else INACTIVE_LABEL_COLOR
	if underline1: underline1.modulate.a = 1.0 if slot == 0 else 0.0

	if slot_label2: slot_label2.modulate = ACTIVE_LABEL_COLOR if slot == 1 else INACTIVE_LABEL_COLOR
	if underline2: underline2.modulate.a = 1.0 if slot == 1 else 0.0

	if slot_label3: slot_label3.modulate = ACTIVE_LABEL_COLOR if slot == 2 else INACTIVE_LABEL_COLOR
	if underline3: underline3.modulate.a = 1.0 if slot == 2 else 0.0

	match slot:
		0: # Pistol (Gun)
			if ammo_loaded_label:
				ammo_loaded_label.text = "12"
				ammo_loaded_label.modulate = ACTIVE_LABEL_COLOR
			if ammo_slash_label: ammo_slash_label.visible = true
			if ammo_reserve_label:
				ammo_reserve_label.visible = true
				ammo_reserve_label.text = "36"
				ammo_reserve_label.modulate = Color(0.7, 0.72, 0.76, 0.8)
			if weapon_icon and weapon_icon_pistol:
				weapon_icon.texture = weapon_icon_pistol
				weapon_icon.custom_minimum_size = Vector2(44, 26)

		1: # Shotgun
			if ammo_loaded_label:
				ammo_loaded_label.text = str(shotgun_ammo)
				ammo_loaded_label.modulate = Color(1.0, 0.35, 0.35, 1.0) if shotgun_ammo == 0 else ACTIVE_LABEL_COLOR
			if ammo_slash_label: ammo_slash_label.visible = true
			if ammo_reserve_label:
				ammo_reserve_label.visible = true
				ammo_reserve_label.text = str(shotgun_reserve)
				ammo_reserve_label.modulate = Color(1.0, 0.35, 0.35, 0.8) if shotgun_reserve == 0 else Color(0.7, 0.72, 0.76, 0.8)
			if weapon_icon and weapon_icon_shotgun:
				weapon_icon.texture = weapon_icon_shotgun
				weapon_icon.custom_minimum_size = Vector2(52, 24)

		2: # Rocket Launcher
			if ammo_loaded_label:
				ammo_loaded_label.text = str(rocket_ammo)
				ammo_loaded_label.modulate = Color(1.0, 0.35, 0.35, 1.0) if rocket_ammo == 0 else ACTIVE_LABEL_COLOR
			if ammo_slash_label: ammo_slash_label.visible = false
			if ammo_reserve_label: ammo_reserve_label.visible = false
			if weapon_icon and weapon_icon_rocket:
				weapon_icon.texture = weapon_icon_rocket
				weapon_icon.custom_minimum_size = Vector2(56, 26)

# ── Toast / Feedback Popup ────────────────────────────────────────────────────
func show_event_banner(title: String, points_text: String = "+ 25") -> void:
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
	toast_tween.tween_property(event_toast, "modulate:a", 1.0, 0.12)
	toast_tween.tween_interval(1.4)
	toast_tween.tween_property(event_toast, "modulate:a", 0.0, 0.3)
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

	if final_score_label: final_score_label.text = _format_number_commas(final_score)
	if high_score_value_label: high_score_value_label.text = _format_number_commas(high_score)
	if gov_kills_label: gov_kills_label.text = "SURVEILLANCE PIGEONS KILLED: " + str(gov_kills)

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
