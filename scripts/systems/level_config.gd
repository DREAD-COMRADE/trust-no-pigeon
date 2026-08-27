extends Resource
class_name LevelConfig

enum SpawnMode { SINGLE, SWARM, MULTI_GOVERNMENT }
enum TimeOfDay { DAY, SUNSET, NIGHT, DAWN }

@export var level_name: String = "Default Level"
@export var starting_time_of_day: TimeOfDay = TimeOfDay.DAY

@export var spawn_mode: SpawnMode = SpawnMode.SINGLE
@export var swarm_size: int = 5
@export var government_count: int = 1

@export var spawn_interval: float = 2.0
@export var base_pigeon_speed: float = 8.0

@export var enable_night_modifiers: bool = true
@export var night_speed_multiplier: float = 1.25
@export var night_spawn_interval_multiplier: float = 0.75
