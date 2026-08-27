extends Node3D

@onready var player: PlayerController = $Player if has_node("Player") and $Player is PlayerController else null
@onready var camera: Camera3D = $Player/Camera3D
@onready var gun: Gun = $Player/Camera3D/Gun if has_node("Player/Camera3D/Gun") else null
@onready var shotgun: Shotgun = $Player/Camera3D/Shotgun if has_node("Player/Camera3D/Shotgun") else null
@onready var missile_launcher: MissileLauncher = $Player/Camera3D/MissileLauncher if has_node("Player/Camera3D/MissileLauncher") else null

@onready var score_manager: ScoreManager = $Systems/ScoreManager
@onready var aggression_manager: GovernmentAggressionManager = $Systems/GovernmentAggressionManager
@onready var spawner: PigeonSpawner = $Systems/PigeonSpawner
@onready var day_night_manager: DayNightManager = $Systems/DayNightManager if has_node("Systems/DayNightManager") else null
@onready var event_manager: EventManager = $Systems/EventManager if has_node("Systems/EventManager") else null
@onready var hud: CanvasLayer = $Systems/HUD

var is_game_over: bool = false
var is_god_mode: bool = false

func _ready() -> void:
	get_tree().paused = false
	_clean_up_spawned_objects()

	if gun and gun.has_signal("shot_fired"):
		gun.shot_fired.connect(_on_shot_fired)

	if shotgun and shotgun.has_signal("shot_fired"):
		shotgun.shot_fired.connect(_on_shot_fired)

	if missile_launcher:
		missile_launcher.switch_to_gun_requested.connect(_on_switch_to_gun)

	if player:
		player.weapon_switched.connect(_on_player_weapon_switched)
		player.ammo_updated.connect(_on_player_ammo_updated)

	if spawner:
		spawner.score_manager = score_manager
		spawner.aggression_manager = aggression_manager

	if score_manager:
		score_manager.score_updated.connect(_on_score_updated)
		score_manager.government_pigeon_killed.connect(_on_gov_pigeon_killed)

	if aggression_manager:
		aggression_manager.aggression_changed.connect(_on_aggression_changed)

	if event_manager:
		event_manager.spawner = spawner
		event_manager.aggression_manager = aggression_manager
		event_manager.day_night_manager = day_night_manager
		event_manager.time_updated.connect(_on_event_time_updated)
		event_manager.event_triggered.connect(_on_event_triggered)
		event_manager.weapon_switch_requested.connect(_on_weapon_switch_requested)

	if hud:
		hud.restart_requested.connect(restart_game)

	_on_score_updated(0, 0)
	_on_aggression_changed(0, "NORMAL")
	_refresh_hud_weapons()

func _clean_up_spawned_objects() -> void:
	var groups = ["ufo", "drones", "missiles", "tracers", "government_pigeons", "pigeons"]
	for grp in groups:
		for node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node) and node != self and not is_ancestor_of(node):
				node.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_T and event.pressed:
		get_tree().change_scene_to_file("res://scenes/main/TargetPractice.tscn")

func _on_shot_fired(from_pos: Vector3, dir_vec: Vector3) -> void:
	var gov_pigeons = get_tree().get_nodes_in_group("government_pigeons")
	for pigeon in gov_pigeons:
		if is_instance_valid(pigeon) and pigeon.has_method("check_near_miss_and_dodge"):
			pigeon.check_near_miss_and_dodge(from_pos, dir_vec)

func _on_player_weapon_switched(_slot: int, _wep_name: String, _ammo: int) -> void:
	_refresh_hud_weapons()

func _on_player_ammo_updated(_wep_name: String, _ammo: int) -> void:
	_refresh_hud_weapons()

func _refresh_hud_weapons() -> void:
	if not hud:
		return
	var slot = player.current_slot if player else 0
	var s_ammo = shotgun.ammo if shotgun else 0
	var r_ammo = missile_launcher.ammo if missile_launcher else 0
	if hud.has_method("update_weapon_ui"):
		hud.update_weapon_ui(slot, s_ammo, r_ammo)

func _on_score_updated(current: int, high: int) -> void:
	if hud:
		hud.update_score(current, high)

func _on_gov_pigeon_killed(total_gov: int) -> void:
	if aggression_manager:
		aggression_manager.on_government_killed(total_gov)

func _on_aggression_changed(level: int, status_text: String) -> void:
	if hud:
		hud.update_aggression(level, status_text)

func _on_event_time_updated(current_time: float, next_event_countdown: float) -> void:
	if hud and hud.has_method("update_run_time"):
		hud.update_run_time(current_time, next_event_countdown)

func _on_event_triggered(_event_name: String, banner_title: String) -> void:
	if hud and hud.has_method("show_event_banner") and banner_title != "":
		hud.show_event_banner(banner_title)

func _on_weapon_switch_requested(weapon_type: String, ammo_count: int) -> void:
	if weapon_type == "guided_missile" and player:
		player.add_rocket_ammo(ammo_count)
		player.switch_to_slot(2)

func _on_switch_to_gun() -> void:
	if player:
		player.switch_to_slot(0)

func trigger_game_over() -> void:
	if is_game_over or is_god_mode:
		return
	is_game_over = true

	if spawner:
		spawner.stop()

	if event_manager:
		event_manager.is_active = false

	if hud and score_manager:
		hud.show_game_over(
			score_manager.current_score,
			score_manager.high_score,
			score_manager.government_kills,
			score_manager.total_kills,
			score_manager.shots_fired
		)

func restart_game() -> void:
	_clean_up_spawned_objects()
	get_tree().paused = false
	get_tree().reload_current_scene()
