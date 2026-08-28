extends CanvasLayer

@warning_ignore("unused_signal")
signal restart_requested


@onready var score_label: Label = $TopLeftContainer/ScoreCard/VBox/ScoreLabel if has_node("TopLeftContainer/ScoreCard/VBox/ScoreLabel") else null
@onready var high_score_label: Label = $TopLeftContainer/ScoreCard/VBox/HighScoreLabel if has_node("TopLeftContainer/ScoreCard/VBox/HighScoreLabel") else null

@onready var time_label: Label = $TopCenterContainer/CenterPill/HBox/TimeLabel if has_node("TopCenterContainer/CenterPill/HBox/TimeLabel") else null
@onready var next_event_label: Label = $TopCenterContainer/CenterPill/HBox/NextEventLabel if has_node("TopCenterContainer/CenterPill/HBox/NextEventLabel") else null
@onready var aggression_label: Label = $TopCenterContainer/CenterPill/HBox/AggressionLabel if has_node("TopCenterContainer/CenterPill/HBox/AggressionLabel") else null

@onready var gun_label: Label = $BottomRightContainer/WeaponCard/VBox/GunLabel if has_node("BottomRightContainer/WeaponCard/VBox/GunLabel") else null
@onready var shotgun_label: Label = $BottomRightContainer/WeaponCard/VBox/ShotgunLabel if has_node("BottomRightContainer/WeaponCard/VBox/ShotgunLabel") else null
@onready var rocket_label: Label = $BottomRightContainer/WeaponCard/VBox/RocketLabel if has_node("BottomRightContainer/WeaponCard/VBox/RocketLabel") else null

@onready var debug_panel: Control = $DebugPanel if has_node("DebugPanel") else null

@onready var event_toast: Control = $EventToast if has_node("EventToast") else null
@onready var event_toast_label: Label = $EventToast/ToastPanel/HBox/ToastLabel if has_node("EventToast/ToastPanel/HBox/ToastLabel") else null

@onready var game_over_panel: Control = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/VBox/ScoreHBox/ScoreVBox/FinalScoreLabel if has_node("GameOverPanel/VBox/ScoreHBox/ScoreVBox/FinalScoreLabel") else null
@onready var high_score_value_label: Label = $GameOverPanel/VBox/ScoreHBox/HighScoreVBox/HighScoreValueLabel if has_node("GameOverPanel/VBox/ScoreHBox/HighScoreVBox/HighScoreValueLabel") else null
@onready var gov_kills_label: Label = $GameOverPanel/VBox/StatsVBox/GovKillsLabel if has_node("GameOverPanel/VBox/StatsVBox/GovKillsLabel") else null
@onready var accuracy_label: Label = $GameOverPanel/VBox/StatsVBox/AccuracyLabel if has_node("GameOverPanel/VBox/StatsVBox/AccuracyLabel") else null
@onready var message_label: Label = $GameOverPanel/VBox/MessageLabel if has_node("GameOverPanel/VBox/MessageLabel") else null
@onready var restart_button: Button = $GameOverPanel/VBox/RestartButton if has_node("GameOverPanel/VBox/RestartButton") else null

var toast_tween: Tween
var cur_active_slot: int = 0

var game_over_bad_stream: AudioStream = preload("res://assets/Audio/GAME_OVER.mp3")
var game_over_good_stream: AudioStream = preload("res://assets/Audio/Game_over_2.mp3")
var game_over_audio: AudioStreamPlayer

func _ready() -> void:
	game_over_panel.visible = false
	if event_toast:
		event_toast.modulate.a = 0.0
		event_toast.visible = false

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

	update_weapon_ui(0, 2, 0)

	# Bind UI click audio
	var helper_script = load("res://scripts/ui/ui_audio_helper.gd")
	if helper_script:
		helper_script.setup_ui_audio(self)

func _unhandled_input(event: InputEvent) -> void:
	# Dev F1 key opens/toggles DebugPanel directly anywhere in game
	if event is InputEventKey and event.keycode == KEY_F1 and event.pressed and not event.echo:
		if debug_panel and debug_panel.has_method("toggle_panel"):
			debug_panel.toggle_panel()
			get_viewport().set_input_as_handled()
			return

	if game_over_panel.visible:
		if event.is_action_pressed("shoot") or (event is InputEventKey and event.keycode == KEY_R and event.pressed):
			_on_restart_pressed()

func update_score(score: int, high_score: int) -> void:
	if score_label:
		score_label.text = "SCORE: " + str(score)
	if high_score_label:
		high_score_label.text = "HIGH: " + str(high_score)

func update_aggression(level: int, status_text: String) -> void:
	if aggression_label:
		aggression_label.text = status_text
		if level > 0:
			aggression_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		else:
			aggression_label.modulate = Color(0.4, 0.9, 0.4, 1.0)

@warning_ignore("integer_division")
func update_run_time(time_seconds: float, next_event_seconds: float) -> void:
	if time_label:
		var total_secs: int = int(time_seconds)
		var mins: int = int(float(total_secs) / 60.0)
		var secs: int = total_secs % 60
		time_label.text = "TIME %02d:%02d" % [mins, secs]

	if next_event_label:
		var n_total: int = int(next_event_seconds)
		var n_mins: int = int(float(n_total) / 60.0)
		var n_secs: int = n_total % 60
		next_event_label.text = "NEXT EVENT %02d:%02d" % [n_mins, n_secs]

func update_weapon_ui(slot: int, shotgun_ammo: int, rocket_ammo: int) -> void:
	cur_active_slot = slot

	if gun_label:
		gun_label.text = "[1] GUN  ∞"
		if slot == 0:
			gun_label.modulate = Color(0.3, 1.0, 0.4, 1.0)
		else:
			gun_label.modulate = Color(0.6, 0.6, 0.6, 0.7)

	if shotgun_label:
		shotgun_label.text = "[2] SHOTGUN  %d" % shotgun_ammo
		if slot == 1:
			shotgun_label.modulate = Color(0.3, 1.0, 0.4, 1.0) if shotgun_ammo > 0 else Color(1.0, 0.4, 0.4, 1.0)
		else:
			shotgun_label.modulate = Color(0.85, 0.75, 0.3, 0.8) if shotgun_ammo > 0 else Color(0.5, 0.5, 0.5, 0.5)

	if rocket_label:
		rocket_label.text = "[3] ROCKET  %d" % rocket_ammo
		if slot == 2:
			rocket_label.modulate = Color(0.3, 1.0, 0.4, 1.0) if rocket_ammo > 0 else Color(1.0, 0.4, 0.4, 1.0)
		else:
			rocket_label.modulate = Color(1.0, 0.65, 0.2, 0.8) if rocket_ammo > 0 else Color(0.5, 0.5, 0.5, 0.5)

func show_event_banner(title: String) -> void:
	if not event_toast or not event_toast_label:
		return

	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()

	event_toast_label.text = "⚠️ EVENT: " + title.to_upper()
	event_toast.visible = true

	toast_tween = create_tween()
	toast_tween.tween_property(event_toast, "modulate:a", 1.0, 0.25)
	toast_tween.tween_interval(3.0)
	toast_tween.tween_property(event_toast, "modulate:a", 0.0, 0.4)
	toast_tween.tween_callback(func(): event_toast.visible = false)

func show_game_over(final_score: int, high_score: int, gov_kills: int, total_kills: int, shots_fired: int) -> void:
	game_over_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Stop MusicManager theme music
	var main = get_tree().current_scene
	if main and main.has_node("Systems/MusicManager"):
		var mm = main.get_node("Systems/MusicManager")
		if mm and mm.has_method("stop_music"):
			mm.stop_music()

	if final_score_label:
		final_score_label.text = str(final_score)
	if high_score_value_label:
		high_score_value_label.text = str(high_score)
	if gov_kills_label:
		gov_kills_label.text = "SURVEILLANCE PIGEONS KILLED: " + str(gov_kills)

	var accuracy_pct = int((float(total_kills) / float(max(1, shots_fired))) * 100.0)
	if accuracy_label:
		accuracy_label.text = "ACCURACY: " + str(accuracy_pct) + "% (" + str(total_kills) + " BIRDS SHOT / " + str(shots_fired) + " BULLETS)"

	var is_good_run = (gov_kills >= 3 or final_score >= 1500 or (shots_fired >= 5 and accuracy_pct >= 60))

	if message_label:
		var eval_msg = ""
		var msg_color = Color(1.0, 0.85, 0.3, 1.0)

		if shots_fired >= 5 and total_kills < 3:
			is_good_run = false
			eval_msg = "CRITICAL ACCURACY FAILURE: You fired " + str(shots_fired) + " bullets and hit only " + str(total_kills) + " birds! The government drones easily outmaneuvered your shots!"
			msg_color = Color(1.0, 0.35, 0.35, 1.0)
		elif gov_kills >= 5:
			is_good_run = true
			eval_msg = "EXCELLENT RESISTANCE: Outstanding threat response! You compromised " + str(gov_kills) + " government surveillance units!"
			msg_color = Color(0.35, 1.0, 0.45, 1.0)
		elif gov_kills == 0:
			is_good_run = false
			eval_msg = "SURVEILLANCE COMPLETE: You failed to eliminate any government pigeons before being neutralized."
			msg_color = Color(0.95, 0.55, 0.2, 1.0)
		elif final_score >= 1500:
			is_good_run = true
			eval_msg = "HIGH VALUE OPERATIVE: Impressive tactical marksmanship against avian surveillance forces!"
			msg_color = Color(0.35, 0.9, 1.0, 1.0)
		else:
			eval_msg = "PROTOCOL EXECUTED: A government pigeon payload detonated on your position."

		message_label.text = eval_msg
		message_label.modulate = msg_color

	# Play Game Over Audio based on performance (Good = Game_over_2.mp3, Bad = GAME_OVER.mp3)
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
