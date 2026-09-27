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

# Cached player reference resolved via group on first attack
var _cached_player: PlayerController = null

const MIN_ALTITUDE: float = 1.3
const MAX_LATERAL_X: float = 24.0

func _ready() -> void:
	super._ready()
	add_to_group("government_pigeons")
	score_value = 500
	is_government = true

func _on_reach_bounds() -> void:
	super._on_reach_bounds()

# Safe lookup helpers

func _get_player() -> PlayerController:
	if is_instance_valid(_cached_player):
		return _cached_player
	if not is_inside_tree() or not get_tree():
		return null
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerController:
			_cached_player = node as PlayerController
			return _cached_player
	return null


func _get_active_camera() -> Camera3D:
	var vp = get_viewport()
	if vp:
		var cam = vp.get_camera_3d()
		if cam and cam.is_inside_tree():
			return cam
	var p = _get_player()
	if p:
		var cam = p.get_node_or_null("Camera3D")
		if cam and cam.is_inside_tree():
			return cam
	return null


# Near-miss dodge trigger

func check_near_miss_and_dodge(from_pos: Vector3, dir_vec: Vector3) -> void:
	if current_state == State.FALLING or current_state == State.DYING or current_state == State.DEAD or dodge_cooldown > 0.0:
		return
	var to_pigeon = global_position - from_pos
	var proj = to_pigeon.dot(dir_vec)
	if proj > 0:
		var closest_point = from_pos + dir_vec * proj
		if global_position.distance_to(closest_point) < 7.0:
			trigger_evasive_dodge_and_attack(dir_vec)

func trigger_evasive_dodge_and_attack(shot_dir: Vector3) -> void:
	is_dodging = true
	dodge_timer = 0.40
	dodge_cooldown = 0.6

	var cur_pos = global_position if is_inside_tree() else position
	var side_dir = Vector3.UP.cross(shot_dir).normalized()
	if side_dir.length_squared() < 0.01:
		side_dir = Vector3.RIGHT

	var side_sign = 1.0 if randf() > 0.5 else -1.0
	if cur_pos.x > 18.0: side_sign = -1.0
	elif cur_pos.x < -18.0: side_sign = 1.0

	var vertical_sign = 1.0
	if cur_pos.y > 4.5 and randf() > 0.6:
		vertical_sign = -0.4

	var dodge_dir = (side_dir * side_sign * 1.2 + Vector3.UP * vertical_sign * 1.0).normalized()
	dodge_velocity = dodge_dir * (actual_speed * 1.35)

	# Play directional evasive flight animation
	if side_sign < 0.0:
		play_anim("turningLeft_flying", 0.08)
	else:
		play_anim("turningRight_flying", 0.08)

	if sensor_light:
		sensor_light.light_energy = 16.0
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

	if not anim_player:
		anim_player = _find_animation_player()
	if anim_player:
		anim_player.speed_scale = 1.6
	play_anim("flying", 0.1)

	var cam = _get_active_camera()
	target_player_pos = cam.global_position if cam else Vector3(0, 1.6, 0)
	player_attacked.emit(self)

# Process

func _process(delta: float) -> void:
	if dodge_cooldown > 0.0:
		dodge_cooldown -= delta
	if current_state == State.ATTACKING:
		_process_attacking(delta)
	else:
		super._process(delta)

func _process_attacking(delta: float) -> void:
	var cam = _get_active_camera()
	if cam:
		target_player_pos = cam.global_position

	var cur_pos = global_position if is_inside_tree() else position
	var dist_to_target = cur_pos.distance_to(target_player_pos)

	if dist_to_target < 1.8:
		_explode_on_player()
		return

	if dodge_timer > 0.0:
		dodge_timer -= delta
		cur_pos += dodge_velocity * delta
		dodge_velocity = dodge_velocity.lerp(Vector3.ZERO, delta * 6.0)
		if visual:
			visual.rotation.z = lerp(visual.rotation.z, 1.2 * sign(dodge_velocity.x if dodge_velocity.x != 0 else 1.0), delta * 15.0)
	else:
		if is_dodging:
			is_dodging = false
			play_anim("flying", 0.15)
		if visual:
			visual.rotation.z = lerp(visual.rotation.z, 0.0, delta * 10.0)
		var dir = (target_player_pos - cur_pos).normalized()
		if dir.length_squared() > 0.01 and is_inside_tree():
			var up_vec = Vector3.UP
			if abs(dir.dot(up_vec)) > 0.98:
				up_vec = Vector3.RIGHT
			look_at(cur_pos + dir, up_vec)
		cur_pos += dir * actual_speed * delta

	# Fair-play & floor anti-clipping constraints:
	var floor_node = get_tree().get_first_node_in_group("pigeon_floor") if is_inside_tree() else null
	if floor_node and floor_node is Node3D:
		var floor_y = floor_node.global_position.y
		cur_pos.y = max(cur_pos.y, floor_y + 0.2)
	else:
		cur_pos.y = max(cur_pos.y, MIN_ALTITUDE)

	cur_pos.x = clamp(cur_pos.x, -MAX_LATERAL_X, MAX_LATERAL_X)

	if is_inside_tree():
		global_position = cur_pos
	else:
		position = cur_pos

	# Trigger explosion on arrival
	if cur_pos.distance_to(target_player_pos) < 2.0:
		_explode_on_player()
		return


# Hit and explosion

func _on_hit() -> void:
	if hit_effect_scene:
		var fx = hit_effect_scene.instantiate()
		var parent_node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
		parent_node.add_child(fx)
		fx.global_position = global_position
	pigeon_killed.emit(self, score_value, is_government)

func _explode_on_player() -> void:
	current_state = State.DEAD

	var cam = _get_active_camera()
	var spawn_pos = cam.global_position if cam else global_position

	if player_explosion_scene:
		var fx = player_explosion_scene.instantiate()
		var parent_node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
		parent_node.add_child(fx)
		fx.global_position = spawn_pos

	var player = _get_player()
	var main = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
	var is_god = (player and "is_god_mode" in player and player.is_god_mode) or (main and "is_god_mode" in main and main.is_god_mode)

	if not is_god and cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.65)

	if player:
		player.take_damage(1)
	elif not is_god:
		if main and main.has_method("trigger_game_over"):
			main.trigger_game_over()

	queue_free()
