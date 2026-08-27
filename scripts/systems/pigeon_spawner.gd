extends Node3D
class_name PigeonSpawner

enum SpawnMode { SINGLE, FLOCK, MULTI_GOVERNMENT }

@export var normal_pigeon_scene: PackedScene = preload("res://scenes/pigeons/NormalPigeon.tscn")
@export var gov_pigeon_scene: PackedScene = preload("res://scenes/pigeons/GovernmentPigeon.tscn")

@export var score_manager: ScoreManager
@export var aggression_manager: GovernmentAggressionManager

@export var spawn_zones: Array[Marker3D] = []
@export var kill_zones: Array[Marker3D] = []

@export var spawn_mode: SpawnMode = SpawnMode.SINGLE
@export var flock_size: int = 5
@export var flock_gov_count: int = 1
@export var multi_gov_count: int = 3
@export var spawn_delay: float = 0.25
@export var speed_multiplier: float = 1.0

@export var night_speed_mult: float = 1.25
@export var night_spawn_interval_mult: float = 0.75

var is_night_active: bool = false
var spawn_timer: float = 0.0
var is_active: bool = true
var is_wave_spawning: bool = false

func _ready() -> void:
	spawn_timer = 1.0

func _process(delta: float) -> void:
	if not is_active or get_tree().paused:
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0 and not is_wave_spawning:
		trigger_spawn_wave()
		var base_interval = aggression_manager.get_spawn_interval() if aggression_manager else 2.0
		if is_night_active:
			base_interval *= night_spawn_interval_mult
		spawn_timer = max(0.6, base_interval)

func set_night_active(night: bool) -> void:
	is_night_active = night

func trigger_spawn_wave() -> void:
	match spawn_mode:
		SpawnMode.SINGLE:
			spawn_single()
		SpawnMode.FLOCK:
			spawn_flock(flock_size, flock_gov_count)
		SpawnMode.MULTI_GOVERNMENT:
			spawn_multi_government(multi_gov_count)

func spawn_single() -> void:
	var is_gov = false
	if aggression_manager:
		is_gov = randf() < aggression_manager.get_gov_spawn_chance()
	else:
		is_gov = randf() < 0.2

	_instantiate_pigeon(is_gov)

func spawn_flock(size: int = 5, gov_count: int = 1) -> void:
	is_wave_spawning = true
	var gov_to_spawn = clamp(gov_count, 0, size)
	var normal_to_spawn = max(1, size - gov_to_spawn)

	for i in range(normal_to_spawn):
		if not is_active or not is_inside_tree() or get_tree().paused:
			is_wave_spawning = false
			return
		_instantiate_pigeon(false)
		if spawn_delay > 0.0:
			await get_tree().create_timer(spawn_delay).timeout

	for i in range(gov_to_spawn):
		if not is_active or not is_inside_tree() or get_tree().paused:
			is_wave_spawning = false
			return
		_instantiate_pigeon(true)
		if spawn_delay > 0.0:
			await get_tree().create_timer(spawn_delay).timeout

	is_wave_spawning = false

func spawn_multi_government(count: int = 3) -> void:
	is_wave_spawning = true
	var num_to_spawn = max(2, count)
	for i in range(num_to_spawn):
		if not is_active or not is_inside_tree() or get_tree().paused:
			is_wave_spawning = false
			return
		_instantiate_pigeon(true)
		if spawn_delay > 0.0:
			await get_tree().create_timer(spawn_delay).timeout

	is_wave_spawning = false

func spawn_direct_attacking_government(count: int = 1) -> void:
	if not is_inside_tree() or not gov_pigeon_scene:
		return

	for i in range(count):
		var pigeon = gov_pigeon_scene.instantiate() as PigeonBase
		if not pigeon:
			continue

		var start_pos = Vector3(randf_range(-20.0, 20.0), randf_range(8.0, 15.0), randf_range(-20.0, -30.0))
		var target_pos = Vector3(0, 1.6, 0)
		var speed_mult = speed_multiplier * (aggression_manager.get_attack_speed_multiplier() if aggression_manager else 1.0)

		get_parent().add_child(pigeon)
		pigeon.setup(start_pos, target_pos, speed_mult)
		pigeon.pigeon_killed.connect(_on_pigeon_killed)

		if pigeon.has_method("start_attack"):
			pigeon.start_attack()

func _instantiate_pigeon(is_gov: bool) -> void:
	if not is_active or not is_inside_tree() or get_tree().paused:
		return

	var scene_to_spawn = gov_pigeon_scene if is_gov else normal_pigeon_scene
	if not scene_to_spawn:
		return

	var pigeon = scene_to_spawn.instantiate() as PigeonBase
	if not pigeon:
		return

	var positions = _get_spawn_and_kill_positions()
	var start_pos = positions[0]
	var target_pos = positions[1]

	var speed_mult = speed_multiplier
	if is_gov and aggression_manager:
		speed_mult *= aggression_manager.get_attack_speed_multiplier()
	if is_night_active:
		speed_mult *= night_speed_mult
	speed_mult *= randf_range(0.85, 1.25)

	get_parent().add_child(pigeon)
	pigeon.setup(start_pos, target_pos, speed_mult)

	pigeon.pigeon_killed.connect(_on_pigeon_killed)

func _get_spawn_and_kill_positions() -> Array[Vector3]:
	var start_pos: Vector3 = Vector3(-26.0 if randf() > 0.5 else 26.0, randf_range(3.0, 12.0), randf_range(-6.0, -28.0))
	var target_pos: Vector3 = Vector3(26.0 if start_pos.x < 0 else -26.0, randf_range(2.5, 11.0), randf_range(-6.0, -28.0))

	# Resolve start position from spawn zones
	if spawn_zones.size() > 0:
		var zone: Marker3D = spawn_zones[randi() % spawn_zones.size()]
		if zone and is_instance_valid(zone):
			if zone.has_method("get_spawn_position"):
				start_pos = zone.get_spawn_position()
			elif zone.is_inside_tree():
				start_pos = zone.global_position
			else:
				start_pos = zone.position

	# Resolve target position from kill zones (guaranteed opposite / min dist 20m)
	var valid_kill_nodes: Array[Marker3D] = []
	if kill_zones.size() > 0:
		for zone in kill_zones:
			if zone and is_instance_valid(zone):
				var pos = zone.global_position if zone.is_inside_tree() else zone.position
				if pos.distance_to(start_pos) >= 20.0:
					valid_kill_nodes.append(zone)

	if valid_kill_nodes.size() > 0:
		var zone = valid_kill_nodes[randi() % valid_kill_nodes.size()]
		if zone.has_method("get_kill_position"):
			target_pos = zone.get_kill_position()
		elif zone.is_inside_tree():
			target_pos = zone.global_position
		else:
			target_pos = zone.position

	return [start_pos, target_pos]

func _on_pigeon_killed(_pigeon: PigeonBase, score: int, is_gov: bool) -> void:
	if score_manager:
		score_manager.add_score(score, is_gov)

func stop() -> void:
	is_active = false
	is_wave_spawning = false

func start() -> void:
	is_active = true
	is_wave_spawning = false
	spawn_timer = 0.5
