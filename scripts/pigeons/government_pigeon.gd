extends PigeonBase
class_name GovernmentPigeon

signal player_attacked(pigeon)

@export var attack_speed_mult: float = 1.22
@onready var sensor_light: OmniLight3D = $Visual/SensorLight if has_node("Visual/SensorLight") else null

var hit_effect_scene: PackedScene = preload("res://scenes/effects/GovernmentPigeonHit.tscn")
var player_explosion_scene: PackedScene = preload("res://scenes/effects/GovernmentPigeonPlayerExplosion.tscn")

var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_velocity: Vector3 = Vector3.ZERO
var dodge_cooldown: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("government_pigeons")
	score_value = 500
	is_government = true

func _on_reach_bounds() -> void:
	super._on_reach_bounds()

func check_near_miss_and_dodge(from_pos: Vector3, dir_vec: Vector3) -> void:
	if current_state == State.DYING or dodge_cooldown > 0.0:
		return

	var to_pigeon = global_position - from_pos
	var proj = to_pigeon.dot(dir_vec)

	if proj > 0:
		var closest_point = from_pos + dir_vec * proj
		var dist = global_position.distance_to(closest_point)

		# Near miss threshold (shot passed within 7.0 meters of pigeon)
		if dist < 7.0:
			trigger_evasive_dodge_and_attack(dir_vec)

const MIN_ALTITUDE: float = 1.3
const MAX_LATERAL_X: float = 24.0

func trigger_evasive_dodge_and_attack(shot_dir: Vector3) -> void:
	is_dodging = true
	dodge_timer = 0.40
	dodge_cooldown = 0.6

	var cur_pos = global_position if is_inside_tree() else position

	# Calculate high-speed perpendicular dodge direction (left, right, up)
	var side_dir = Vector3.UP.cross(shot_dir).normalized()
	if side_dir.length_squared() < 0.01:
		side_dir = Vector3.RIGHT

	# Always dodge towards the center if near boundary, otherwise random
	var side_sign = 1.0 if randf() > 0.5 else -1.0
	if cur_pos.x > 18.0:
		side_sign = -1.0
	elif cur_pos.x < -18.0:
		side_sign = 1.0

	# Prevent dodging downwards if near floor level
	var vertical_sign = 1.0
	if cur_pos.y > 4.5 and randf() > 0.6:
		vertical_sign = -0.4

	var dodge_dir = (side_dir * side_sign * 1.2 + Vector3.UP * vertical_sign * 1.0).normalized()
	dodge_velocity = dodge_dir * (actual_speed * 1.35)

	# Flashes sensor light bright warning red
	if sensor_light:
		sensor_light.light_energy = 15.0
		sensor_light.light_color = Color(1.0, 0.0, 0.0, 1.0)

	if current_state != State.ATTACKING:
		start_attack()

func start_attack() -> void:
	if current_state != State.ATTACKING:
		current_state = State.ATTACKING
		actual_speed *= attack_speed_mult

	if sensor_light:
		sensor_light.light_energy = 8.0
		sensor_light.light_color = Color(1.0, 0.0, 0.0, 1.0)

	var vp = get_viewport()
	var camera = vp.get_camera_3d() if vp else null
	if camera and camera.is_inside_tree():
		target_player_pos = camera.global_position
	else:
		target_player_pos = Vector3(0, 1.6, 0)

	player_attacked.emit(self)

func _process(delta: float) -> void:
	if dodge_cooldown > 0.0:
		dodge_cooldown -= delta

	if current_state == State.ATTACKING:
		_process_attacking(delta)
	else:
		super._process(delta)

func _process_attacking(delta: float) -> void:
	var vp = get_viewport()
	var camera = vp.get_camera_3d() if vp else null
	if camera and camera.is_inside_tree():
		target_player_pos = camera.global_position

	var cur_pos = global_position if is_inside_tree() else position
	var dist_to_target = cur_pos.distance_to(target_player_pos)

	if dist_to_target < 1.5:
		_explode_on_player()
		return

	# Handle active dodge sidestep burst
	if dodge_timer > 0.0:
		dodge_timer -= delta
		cur_pos += dodge_velocity * delta
		dodge_velocity = dodge_velocity.lerp(Vector3.ZERO, delta * 6.0)

		# Roll visual mesh sideways during dodge
		if visual:
			visual.rotation.z = lerp(visual.rotation.z, 1.2 * sign(dodge_velocity.x if dodge_velocity.x != 0 else 1.0), delta * 15.0)
	else:
		is_dodging = false
		if visual:
			visual.rotation.z = lerp(visual.rotation.z, 0.0, delta * 10.0)

		var dir = (target_player_pos - cur_pos).normalized()
		if dir != Vector3.ZERO and is_inside_tree():
			look_at(cur_pos + dir, Vector3.UP)

		cur_pos += dir * actual_speed * delta

	# FAIR-PLAY & ANTI-CLIPPING CONSTRAINTS:
	# 1. Never clip below floor level
	cur_pos.y = max(cur_pos.y, MIN_ALTITUDE)

	# 2. Constrain lateral bounds within the player's 90-deg aim cone
	cur_pos.x = clamp(cur_pos.x, -MAX_LATERAL_X, MAX_LATERAL_X)

	# 3. Ensure pigeon stays in front of the player (Z <= -0.5) until impact
	if dist_to_target > 1.5 and cur_pos.z > -0.5:
		cur_pos.z = -0.5

	if is_inside_tree():
		global_position = cur_pos
	else:
		position = cur_pos

func _on_hit() -> void:
	if hit_effect_scene:
		var fx = hit_effect_scene.instantiate()
		var parent_node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
		parent_node.add_child(fx)
		fx.global_position = global_position

	pigeon_killed.emit(self, score_value, is_government)
	queue_free()

func _explode_on_player() -> void:
	current_state = State.DYING

	var camera = get_viewport().get_camera_3d()
	var spawn_pos = camera.global_position if camera else global_position

	if player_explosion_scene:
		var fx = player_explosion_scene.instantiate()
		var parent_node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
		parent_node.add_child(fx)
		fx.global_position = spawn_pos


	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(1.0)

	var main = get_tree().current_scene
	if main and main.has_method("trigger_game_over"):
		main.trigger_game_over()

	queue_free()
