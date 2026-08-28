extends Node
class_name EventManager

signal time_updated(run_time: float, next_event_countdown: float)
signal event_triggered(event_name: String, banner_title: String)
signal event_ended(event_name: String)
@warning_ignore("unused_signal")
signal weapon_switch_requested(weapon_type: String, ammo: int)


@export var min_event_interval: float = 25.0
@export var max_event_interval: float = 45.0
@export var initial_first_event_delay: float = 20.0

@export var auto_attack_interval: float = 120.0 # 2 minutes periodic attack on idle players

@export var ufo_scene: PackedScene = preload("res://scenes/objects/UFO.tscn")
@export var drone_scene: PackedScene = preload("res://scenes/objects/PackageDrone.tscn")

@export var spawner: PigeonSpawner
@export var aggression_manager: GovernmentAggressionManager
@export var day_night_manager: DayNightManager

# Configurable event registry
@export var event_definitions: Array[Dictionary] = [
	{
		"name": "Single pigeon spawn",
		"min_time": 0.0,
		"max_time": 0.0,
		"cooldown": 15.0,
		"duration": 5.0,
		"enabled": true,
		"banner": ""
	},
	{
		"name": "Pigeon flock",
		"min_time": 15.0,
		"max_time": 0.0,
		"cooldown": 30.0,
		"duration": 6.0,
		"enabled": true,
		"banner": "PIGEON FLOCK INCOMING"
	},
	{
		"name": "Supply drone drop",
		"min_time": 20.0,
		"max_time": 0.0,
		"cooldown": 45.0,
		"duration": 15.0,
		"enabled": true,
		"banner": "SUPPLY DRONE INCOMING"
	},
	{
		"name": "Multi-Government-Pigeon wave",
		"min_time": 35.0,
		"max_time": 0.0,
		"cooldown": 45.0,
		"duration": 8.0,
		"enabled": true,
		"banner": "GOVERNMENT SQUADRON DETECTED"
	},
	{
		"name": "Government Has Noticed",
		"min_time": 50.0,
		"max_time": 0.0,
		"cooldown": 90.0,
		"duration": 18.0,
		"enabled": true,
		"banner": "GOVERNMENT HAS NOTICED"
	},
	{
		"name": "Emergency Press Conference",
		"min_time": 80.0,
		"max_time": 0.0,
		"cooldown": 120.0,
		"duration": 20.0,
		"enabled": true,
		"banner": "EMERGENCY PRESS CONFERENCE"
	},
	{
		"name": "Operation: Shut Him Up",
		"min_time": 110.0,
		"max_time": 0.0,
		"cooldown": 140.0,
		"duration": 22.0,
		"enabled": true,
		"banner": "OPERATION: SHUT HIM UP"
	},
	{
		"name": "Day/Night transitions",
		"min_time": 60.0,
		"max_time": 0.0,
		"cooldown": 150.0,
		"duration": 10.0,
		"enabled": true,
		"banner": "TIME SHIFT"
	},
	{
		"name": "UFO event",
		"min_time": 65.0,
		"max_time": 0.0,
		"cooldown": 110.0,
		"duration": 45.0,
		"enabled": true,
		"banner": "UNIDENTIFIED FLYING OBJECT"
	}
]

var run_time: float = 0.0
var next_event_countdown: float = 0.0
var auto_attack_timer: float = 120.0
var is_active: bool = true

# Tracking event cooldown timestamps
var event_last_triggered: Dictionary = {}
var active_event_name: String = ""
var active_event_timer: float = 0.0

var active_ufo: UFO = null

func _ready() -> void:
	# Fallback references if not assigned in Inspector
	if get_tree() and get_tree().current_scene:
		if not spawner:
			spawner = get_tree().current_scene.find_child("PigeonSpawner", true, false) as PigeonSpawner
		if not aggression_manager:
			aggression_manager = get_tree().current_scene.find_child("GovernmentAggressionManager", true, false) as GovernmentAggressionManager
		if not day_night_manager:
			day_night_manager = get_tree().current_scene.find_child("DayNightManager", true, false) as DayNightManager

	next_event_countdown = initial_first_event_delay
	auto_attack_timer = auto_attack_interval

func _process(delta: float) -> void:
	if not is_active or (get_tree() and get_tree().paused):
		return

	run_time += delta
	next_event_countdown -= delta
	auto_attack_timer -= delta

	# Periodic 2-minute auto-attack to prevent idle standing
	if auto_attack_timer <= 0.0:
		auto_attack_timer = auto_attack_interval
		_trigger_idle_prevention_attack()

	if active_event_name != "":
		active_event_timer -= delta
		if active_event_timer <= 0.0:
			_end_active_event()

	if next_event_countdown <= 0.0:
		_pick_and_trigger_next_event()
		next_event_countdown = randf_range(min_event_interval, max_event_interval)

	time_updated.emit(run_time, max(0.0, next_event_countdown))

func _trigger_idle_prevention_attack() -> void:
	if spawner:
		spawner.spawn_direct_attacking_government(1)
	_broadcast_screens("SURVEILLANCE ENGAGEMENT", "TACTICAL STRIKE IN PROGRESS")
	event_triggered.emit("Auto Attack", "WARNING: DIRECT SURVEILLANCE STRIKE!")

func _pick_and_trigger_next_event() -> void:
	var eligible_events: Array[Dictionary] = []

	for event in event_definitions:
		if not event.get("enabled", true):
			continue

		var ev_name: String = event.get("name", "")
		var min_t: float = event.get("min_time", 0.0)
		var max_t: float = event.get("max_time", 0.0)
		var cooldown: float = event.get("cooldown", 30.0)

		# Check run_time minimum
		if run_time < min_t:
			continue

		# Check run_time maximum (if max_time > 0)
		if max_t > 0.0 and run_time > max_t:
			continue

		# Check cooldown
		if event_last_triggered.has(ev_name):
			var time_since = run_time - event_last_triggered[ev_name]
			if time_since < cooldown:
				continue

		eligible_events.append(event)

	if eligible_events.size() > 0:
		var selected = eligible_events[randi() % eligible_events.size()]
		trigger_event(selected.get("name", ""))
	else:
		# Fallback to single or flock spawn if no complex events are off cooldown
		if spawner:
			spawner.trigger_spawn_wave()

func trigger_event(ev_name: String) -> void:
	var event_def: Dictionary = {}
	for ev in event_definitions:
		if ev.get("name", "") == ev_name:
			event_def = ev
			break

	if event_def.is_empty():
		return

	event_last_triggered[ev_name] = run_time
	active_event_name = ev_name
	active_event_timer = event_def.get("duration", 15.0)

	var banner_text: String = event_def.get("banner", ev_name.to_upper())
	if banner_text == "":
		banner_text = ev_name.to_upper()

	event_triggered.emit(ev_name, banner_text)

	match ev_name:
		"Single pigeon spawn":
			_trigger_single_spawn()
		"Pigeon flock":
			_trigger_flock()
		"Supply drone drop":
			spawn_package_drone(randi_range(2, 3), randi_range(4, 6))
		"Multi-Government-Pigeon wave":
			_trigger_multi_gov()
		"Government Has Noticed":
			_trigger_government_noticed()
		"Emergency Press Conference":
			_trigger_press_conference()
		"Operation: Shut Him Up":
			_trigger_shut_him_up()
		"Day/Night transitions":
			_trigger_day_night_transition()
		"UFO event":
			_trigger_ufo_event()

func _trigger_single_spawn() -> void:
	if spawner:
		spawner.spawn_single()

func _trigger_flock() -> void:
	if spawner:
		spawner.spawn_flock(5, 1)

func _trigger_multi_gov() -> void:
	if spawner:
		spawner.spawn_multi_government(3)

func spawn_package_drone(rockets: int = 3, shells: int = 4) -> void:
	if drone_scene and is_inside_tree():
		var drone = drone_scene.instantiate() as PackageDrone
		var start_left = randf() > 0.5
		var from_pos = Vector3(-35.0 if start_left else 35.0, randf_range(9.0, 14.0), randf_range(-14.0, -28.0))
		var to_pos = Vector3(35.0 if start_left else -35.0, randf_range(8.0, 13.0), randf_range(-14.0, -28.0))

		var parent_node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_tree().root
		parent_node.add_child(drone)
		drone.setup(from_pos, to_pos, rockets, shells)

func _trigger_government_noticed() -> void:
	_broadcast_screens("GOVERNMENT HAS NOTICED", "SURVEILLANCE LEVEL INCREASED")
	if aggression_manager:
		aggression_manager.on_government_killed(aggression_manager.gov_kills + 1)
	if spawner:
		spawner.spawn_flock(4, 2)

func _trigger_press_conference() -> void:
	_broadcast_screens("EMERGENCY PRESS CONFERENCE", "OFFICIAL STATEMENT UNDERWAY")
	if spawner:
		spawner.spawn_flock(6, 1)

func _trigger_shut_him_up() -> void:
	_broadcast_screens("OPERATION: SHUT HIM UP", "TACTICAL SUPPRESSION AUTHORIZED")
	if spawner:
		spawner.spawn_multi_government(3)

func _trigger_day_night_transition() -> void:
	if day_night_manager:
		# Advance time slightly or trigger atmospheric shift
		day_night_manager.current_time += 180.0
		if day_night_manager.current_time >= day_night_manager.cycle_duration:
			day_night_manager.current_time -= day_night_manager.cycle_duration

func _trigger_ufo_event() -> void:
	_broadcast_screens("UNIDENTIFIED OBJECT DETECTED", "INTERCEPT WITH 3 GUIDED ROCKETS")

	# Play Theme4 tension music for UFO spawn
	var main = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
	if main and main.has_node("Systems/MusicManager"):
		var mm = main.get_node("Systems/MusicManager")
		if mm and mm.has_method("play_ufo_tension_theme"):
			mm.play_ufo_tension_theme()


	# Spawn UFO (requires 3 rocket hits to down)
	if ufo_scene and is_inside_tree():
		var ufo = ufo_scene.instantiate() as UFO
		var start_side = randf() > 0.5
		var start_pos = Vector3(-45.0 if start_side else 45.0, 20.0, -42.0)
		var center_pos = Vector3(randf_range(-6.0, 6.0), randf_range(18.0, 22.0), randf_range(-35.0, -45.0))

		var parent_node = get_tree().current_scene if get_tree() and get_tree().current_scene else get_tree().root
		parent_node.add_child(ufo)

		ufo.setup(start_pos, center_pos, 45.0, 3)

		ufo.ufo_destroyed.connect(_on_ufo_destroyed)
		ufo.ufo_escaped.connect(_on_ufo_escaped)
		active_ufo = ufo

	# Spawn initial supply drone with rockets
	spawn_package_drone(3, 4)

	# Schedule secondary supply drone so player has surplus rockets
	if is_inside_tree():
		get_tree().create_timer(12.0).timeout.connect(func():
			if active_ufo and is_instance_valid(active_ufo):
				spawn_package_drone(3, 4)
		)

func _on_ufo_destroyed() -> void:
	_broadcast_screens("UFO DESTROYED", "DEFENSE SYSTEM BONUS +2500")
	event_triggered.emit("UFO DESTROYED", "UFO DESTROYED! +2500 PTS")
	active_ufo = null
	_end_active_event()

func _on_ufo_escaped() -> void:
	_broadcast_screens("UFO ESCAPED", "SURVEILLANCE PRESSURE INCREASED")
	event_triggered.emit("UFO ESCAPED", "UFO ESCAPED! AGGRESSION RISING")
	if aggression_manager:
		aggression_manager.on_government_killed(aggression_manager.gov_kills + 1)
	if spawner:
		spawner.spawn_flock(5, 2)
	active_ufo = null
	_end_active_event()

func _broadcast_screens(title: String, subtitle: String = "") -> void:
	if not is_inside_tree() or not get_tree():
		return
	var screens = get_tree().get_nodes_in_group("event_screens")
	for screen in screens:
		if is_instance_valid(screen) and screen.has_method("show_event"):
			screen.show_event(title, subtitle)

func _clear_screens() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var screens = get_tree().get_nodes_in_group("event_screens")
	for screen in screens:
		if is_instance_valid(screen) and screen.has_method("clear_screen"):
			screen.clear_screen()

func _end_active_event() -> void:
	if active_event_name != "":
		var old_event = active_event_name
		active_event_name = ""
		active_event_timer = 0.0
		_clear_screens()
		event_ended.emit(old_event)
