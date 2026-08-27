extends Node
class_name DayNightManager

enum TimePhase { DAY, SUNSET, NIGHT, DAWN }

signal time_changed(current_ratio: float)
signal phase_changed(phase_name: String, is_night: bool)

# Total 30-minute cycle: 10m Day, 5m Sunset, 10m Night, 5m Dawn
@export var cycle_duration: float = 1800.0
@export_range(0.0, 1.0) var starting_time: float = 0.0
@export var enable_cycle: bool = true

@export var directional_light: DirectionalLight3D
@export var world_environment: WorldEnvironment

var current_time: float = 0.0
var current_phase: TimePhase = TimePhase.DAY
var is_night: bool = false

# Phase Thresholds (Exact 10m / 5m / 10m / 5m distribution)
const RATIO_SUNSET_START = 10.0 / 30.0  # 0.3333 (10 mins)
const RATIO_NIGHT_START  = 15.0 / 30.0  # 0.5000 (15 mins)
const RATIO_DAWN_START   = 25.0 / 30.0  # 0.8333 (25 mins)

# Phase Color Definitions
const COLOR_DAY_TOP = Color(0.35, 0.65, 0.95, 1.0)
const COLOR_DAY_HORIZON = Color(0.70, 0.85, 0.95, 1.0)
const COLOR_DAY_SUN = Color(1.00, 0.95, 0.85, 1.0)
const ENERGY_DAY_SUN = 1.2

const COLOR_SUNSET_TOP = Color(0.25, 0.18, 0.42, 1.0)
const COLOR_SUNSET_HORIZON = Color(0.95, 0.45, 0.20, 1.0)
const COLOR_SUNSET_SUN = Color(0.98, 0.50, 0.15, 1.0)
const ENERGY_SUNSET_SUN = 0.8

const COLOR_NIGHT_TOP = Color(0.02, 0.04, 0.12, 1.0)
const COLOR_NIGHT_HORIZON = Color(0.08, 0.10, 0.22, 1.0)
const COLOR_NIGHT_SUN = Color(0.40, 0.55, 0.85, 1.0)
const ENERGY_NIGHT_SUN = 0.15

const COLOR_DAWN_TOP = Color(0.18, 0.25, 0.50, 1.0)
const COLOR_DAWN_HORIZON = Color(0.90, 0.60, 0.50, 1.0)
const COLOR_DAWN_SUN = Color(0.95, 0.75, 0.60, 1.0)
const ENERGY_DAWN_SUN = 0.7

func _ready() -> void:
	if not directional_light and get_tree() and get_tree().current_scene:
		directional_light = get_tree().current_scene.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if not world_environment and get_tree() and get_tree().current_scene:
		world_environment = get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment

	current_time = starting_time * cycle_duration
	_update_environment(0.0)

func _process(delta: float) -> void:
	if not enable_cycle or cycle_duration <= 0.0:
		return

	current_time += delta
	if current_time >= cycle_duration:
		current_time -= cycle_duration

	_update_environment(delta)

func set_starting_phase(ratio: float) -> void:
	starting_time = clamp(ratio, 0.0, 1.0)
	current_time = starting_time * cycle_duration
	_update_environment(0.0)

func _update_environment(delta: float) -> void:
	if not directional_light and get_tree() and get_tree().current_scene:
		directional_light = get_tree().current_scene.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if not world_environment and get_tree() and get_tree().current_scene:
		world_environment = get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment

	var ratio = current_time / cycle_duration
	time_changed.emit(ratio)

	var top_color: Color
	var horizon_color: Color
	var sun_color: Color
	var sun_energy: float
	var sun_pitch: float

	var new_phase: TimePhase
	var new_is_night: bool = false

	if ratio < RATIO_SUNSET_START:
		# DAY: 10 minutes (0:00 -> 10:00)
		new_phase = TimePhase.DAY
		var t = ratio / RATIO_SUNSET_START
		top_color = COLOR_DAY_TOP.lerp(COLOR_SUNSET_TOP, t)
		horizon_color = COLOR_DAY_HORIZON.lerp(COLOR_SUNSET_HORIZON, t)
		sun_color = COLOR_DAY_SUN.lerp(COLOR_SUNSET_SUN, t)
		sun_energy = lerp(ENERGY_DAY_SUN, ENERGY_SUNSET_SUN, t)
		sun_pitch = lerp(-65.0, -12.0, t)
	elif ratio < RATIO_NIGHT_START:
		# SUNSET: 5 minutes (10:00 -> 15:00)
		new_phase = TimePhase.SUNSET
		var t = (ratio - RATIO_SUNSET_START) / (RATIO_NIGHT_START - RATIO_SUNSET_START)
		top_color = COLOR_SUNSET_TOP.lerp(COLOR_NIGHT_TOP, t)
		horizon_color = COLOR_SUNSET_HORIZON.lerp(COLOR_NIGHT_HORIZON, t)
		sun_color = COLOR_SUNSET_SUN.lerp(COLOR_NIGHT_SUN, t)
		sun_energy = lerp(ENERGY_SUNSET_SUN, ENERGY_NIGHT_SUN, t)
		sun_pitch = lerp(-12.0, 30.0, t)
		if t > 0.5:
			new_is_night = true
	elif ratio < RATIO_DAWN_START:
		# NIGHT: 10 minutes (15:00 -> 25:00)
		new_phase = TimePhase.NIGHT
		new_is_night = true
		var t = (ratio - RATIO_NIGHT_START) / (RATIO_DAWN_START - RATIO_NIGHT_START)
		top_color = COLOR_NIGHT_TOP.lerp(COLOR_DAWN_TOP, t)
		horizon_color = COLOR_NIGHT_HORIZON.lerp(COLOR_DAWN_HORIZON, t)
		sun_color = COLOR_NIGHT_SUN.lerp(COLOR_DAWN_SUN, t)
		sun_energy = lerp(ENERGY_NIGHT_SUN, ENERGY_DAWN_SUN, t)
		sun_pitch = lerp(30.0, 85.0, t)
	else:
		# DAWN: 5 minutes (25:00 -> 30:00)
		new_phase = TimePhase.DAWN
		var t = (ratio - RATIO_DAWN_START) / (1.0 - RATIO_DAWN_START)
		top_color = COLOR_DAWN_TOP.lerp(COLOR_DAY_TOP, t)
		horizon_color = COLOR_DAWN_HORIZON.lerp(COLOR_DAY_HORIZON, t)
		sun_color = COLOR_DAWN_SUN.lerp(COLOR_DAY_SUN, t)
		sun_energy = lerp(ENERGY_DAWN_SUN, ENERGY_DAY_SUN, t)
		sun_pitch = lerp(-85.0, -65.0, t)

	if new_phase != current_phase or new_is_night != is_night:
		current_phase = new_phase
		is_night = new_is_night
		var phase_name = TimePhase.keys()[current_phase]
		phase_changed.emit(phase_name, is_night)

		_update_light_fixtures(current_phase)

		var main = get_tree().current_scene if get_tree() else null
		if main and main.has_node("Systems/PigeonSpawner"):
			var spawner = main.get_node("Systems/PigeonSpawner")
			if spawner and spawner.has_method("set_night_active"):
				spawner.set_night_active(is_night)

	# Apply Light changes
	if directional_light:
		if delta > 0.0:
			directional_light.light_color = directional_light.light_color.lerp(sun_color, delta * 5.0)
			directional_light.light_energy = lerp(directional_light.light_energy, sun_energy, delta * 5.0)
		else:
			directional_light.light_color = sun_color
			directional_light.light_energy = sun_energy

		directional_light.rotation_degrees.x = sun_pitch

	# Apply Sky & Environment changes
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		if env.sky and env.sky.sky_material and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
			if delta > 0.0:
				sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(top_color, delta * 5.0)
				sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(horizon_color, delta * 5.0)
			else:
				sky_mat.sky_top_color = top_color
				sky_mat.sky_horizon_color = horizon_color

func _update_light_fixtures(phase: TimePhase, custom_street: Array = [], custom_projectors: Array = []) -> void:
	var tree = get_tree() if (is_inside_tree() and get_tree()) else (Engine.get_main_loop() as SceneTree)

	var street_on = false
	var projector_on = false

	match phase:
		TimePhase.DAY:
			street_on = false
			projector_on = false
		TimePhase.SUNSET:
			street_on = true
			projector_on = false
		TimePhase.NIGHT:
			street_on = true
			projector_on = true
		TimePhase.DAWN:
			street_on = true
			projector_on = false

	var street_lights = custom_street if custom_street.size() > 0 else (tree.get_nodes_in_group("street_lights") if tree else [])
	for light in street_lights:
		if is_instance_valid(light):
			light.visible = street_on

	var projector_lights = custom_projectors if custom_projectors.size() > 0 else (tree.get_nodes_in_group("projector_lights") if tree else [])
	for light in projector_lights:
		if is_instance_valid(light):
			if light.has_method("set_light_state"):
				light.set_light_state(projector_on)
			else:
				light.visible = projector_on
