extends Area3D
class_name PigeonBase

enum State { FLYING, ATTACKING, FALLING, DYING, DEAD }

@export var speed: float = 8.0
@export var score_value: int = 100
@export var is_government: bool = false

var current_state: State = State.FLYING
var target_player_pos: Vector3 = Vector3.ZERO
var time_passed: float = 0.0

var start_point: Vector3
var control_point: Vector3
var end_point: Vector3

var progress_t: float = 0.0
var total_distance: float = 1.0
var actual_speed: float = 8.0
var previous_position: Vector3

# Falling & Death Dynamics
var fall_velocity: Vector3 = Vector3.ZERO
var fall_tumble_axis: Vector3 = Vector3.ZERO
var fall_tumble_speed: float = 0.0
var death_timer: float = 0.0
var is_on_ground: bool = false

@onready var visual: Node3D = $Visual
@onready var wing_left: Node3D = $Visual/WingLeft if has_node("Visual/WingLeft") else null
@onready var wing_right: Node3D = $Visual/WingRight if has_node("Visual/WingRight") else null
@onready var anim_player: AnimationPlayer = _find_animation_player()

signal pigeon_killed(pigeon, score, is_gov)
signal pigeon_escaped(pigeon)

func _ready() -> void:
	time_passed = randf() * 10.0
	previous_position = global_position
	_setup_animations()

func _find_animation_player() -> AnimationPlayer:
	if has_node("Visual"):
		var p = $Visual.find_child("AnimationPlayer", true, false)
		if p is AnimationPlayer:
			return p
	return find_child("AnimationPlayer", true, false) as AnimationPlayer

func _setup_animations() -> void:
	if not anim_player:
		return

	# Configure linear looping for flight and turning animations
	var looping_anims = [
		"flying", "gliding", "soaring",
		"turningLeft_flying", "turningRight_flying",
		"turningLeft_gliding", "turningRight_gliding"
	]
	for a_name in looping_anims:
		if anim_player.has_animation(a_name):
			var anim = anim_player.get_animation(a_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR

	anim_player.speed_scale = 1.3
	play_anim("flying", 0.2)

func play_anim(anim_name: String, blend_time: float = 0.15) -> void:
	if not anim_player:
		anim_player = _find_animation_player()
	if anim_player and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name, blend_time)

func setup(start_pos: Vector3, target_pos: Vector3, speed_mult: float = 1.0) -> void:
	if is_inside_tree():
		global_position = start_pos
	else:
		position = start_pos
	start_point = start_pos
	end_point = target_pos

	actual_speed = speed * speed_mult

	# Generate random 3D control point for smooth Bezier curve trajectory
	var mid = (start_point + end_point) * 0.5
	var curve_offset = Vector3(
		randf_range(-14.0, 14.0),
		randf_range(-6.0, 8.0),
		randf_range(-10.0, 10.0)
	)
	control_point = mid + curve_offset

	total_distance = max(1.0, start_point.distance_to(control_point) + control_point.distance_to(end_point))
	progress_t = 0.0
	previous_position = start_pos

func _process(delta: float) -> void:
	time_passed += delta * 12.0
	_animate_wings()

	match current_state:
		State.FLYING:
			_process_flying(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.FALLING:
			_process_falling(delta)
		State.DYING, State.DEAD:
			pass

func _animate_wings() -> void:
	if wing_left or wing_right:
		var flap_angle = sin(time_passed) * 0.45
		if wing_left:
			wing_left.rotation.z = flap_angle
		if wing_right:
			wing_right.rotation.z = -flap_angle

func _process_flying(delta: float) -> void:
	# Flap-synchronized wingbeat phase (tied directly to the 3D model's skeletal wing cycle)
	var flap_phase: float = 0.0
	if anim_player and anim_player.current_animation == "flying" and anim_player.current_animation_length > 0.0:
		flap_phase = (anim_player.current_animation_position / anim_player.current_animation_length) * TAU
	else:
		flap_phase = time_passed * 0.8

	# Rhythmic wingbeat forward surge (thrust acceleration on downstroke)
	var wingbeat_surge = 1.0 + sin(flap_phase) * 0.18
	progress_t += (actual_speed * wingbeat_surge / total_distance) * delta

	if progress_t >= 1.0:
		_on_reach_bounds()
		return

	# Quadratic Bezier Curve position
	var u = 1.0 - progress_t
	var pos = u * u * start_point + 2.0 * u * progress_t * control_point + progress_t * progress_t * end_point

	# Wingbeat-synchronized vertical lift (natural rise on flap, dip on recovery)
	var wingbeat_lift = Vector3(0, sin(flap_phase) * 0.08, 0)
	global_position = pos + wingbeat_lift
	global_position.y = max(global_position.y, 1.2)

	_update_flight_rotation(delta, flap_phase)

func _update_flight_rotation(delta: float, flap_phase: float = 0.0) -> void:
	# Calculate smooth Bezier curve tangent for clean, non-wobbly flight orientation
	var u = 1.0 - progress_t
	var tangent = 2.0 * u * (control_point - start_point) + 2.0 * progress_t * (end_point - control_point)

	if tangent.length_squared() < 0.001:
		return

	var forward_dir = tangent.normalized()
	var up_vec = Vector3.UP
	if abs(forward_dir.dot(up_vec)) > 0.98:
		up_vec = Vector3.RIGHT
	var target_basis = Basis.looking_at(forward_dir, up_vec)

	# Subtle pitch nod synced with wing downstroke thrust
	var pitch_nod = sin(flap_phase) * 0.04
	target_basis = target_basis.rotated(target_basis.x, pitch_nod)

	# Gentle aerodynamic bank into flight curve turns
	var curve_dir = (end_point - start_point).normalized()
	var turn_cross = forward_dir.cross(curve_dir).y
	var bank_tilt = clamp(turn_cross * 0.4, -0.22, 0.22)
	target_basis = target_basis.rotated(target_basis.z, -bank_tilt)

	global_transform.basis = global_transform.basis.orthonormalized().slerp(target_basis, delta * 8.0)

func _process_attacking(delta: float) -> void:
	var dir = (target_player_pos - global_position).normalized()
	if dir.length_squared() > 0.01:
		var up_vec = Vector3.UP
		if abs(dir.dot(up_vec)) > 0.98:
			up_vec = Vector3.RIGHT
		look_at(global_position + dir, up_vec)
	global_position += dir * actual_speed * delta

func _process_falling(delta: float) -> void:
	death_timer += delta

	# Transition to falling animation after initial air recoil
	if anim_player and anim_player.current_animation == "gettingHit_DyingInTheAir" and death_timer > 0.35:
		if anim_player.has_animation("falling"):
			play_anim("falling", 0.15)

	# Apply gravity & aerodynamic drag
	fall_velocity.y -= 16.0 * delta
	fall_velocity.x = lerp(fall_velocity.x, 0.0, delta * 1.2)
	fall_velocity.z = lerp(fall_velocity.z, 0.0, delta * 1.2)

	global_position += fall_velocity * delta

	# Downward tumbling rotation
	if fall_tumble_axis != Vector3.ZERO:
		rotate(fall_tumble_axis, fall_tumble_speed * delta)
		fall_tumble_speed = lerp(fall_tumble_speed, 1.0, delta * 1.5)

	# Ground collision / impact check (ground is at y ~ 0.35)
	if global_position.y <= 0.35 and not is_on_ground:
		_on_hit_ground()

	# Safe timeout cleanup
	if death_timer >= 2.5:
		queue_free()

func _on_hit_ground() -> void:
	is_on_ground = true
	current_state = State.DEAD
	global_position.y = 0.35
	fall_velocity = Vector3.ZERO
	fall_tumble_axis = Vector3.ZERO

	if anim_player and anim_player.has_animation("gettingHit_DyingOnTheGround"):
		play_anim("gettingHit_DyingOnTheGround", 0.1)

	# Safe fade/sink cleanup without zero-scaling transforms
	var tween = create_tween()
	tween.tween_interval(1.0)
	if visual:
		tween.tween_property(visual, "position:y", visual.position.y - 0.4, 0.3)
	tween.tween_callback(queue_free)

func _on_reach_bounds() -> void:
	pigeon_escaped.emit(self)
	queue_free()

func take_hit() -> void:
	if current_state == State.FALLING or current_state == State.DYING or current_state == State.DEAD:
		return

	# Disable collision shape so the pigeon cannot be shot again
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	current_state = State.FALLING
	death_timer = 0.0
	is_on_ground = false

	# Calculate recoil trajectory from current flight velocity
	var flight_dir = (global_position - previous_position).normalized()
	if flight_dir == Vector3.ZERO:
		flight_dir = -global_transform.basis.z
	fall_velocity = flight_dir * (actual_speed * 0.4) + Vector3(
		randf_range(-1.5, 1.5),
		randf_range(1.0, 3.5),
		randf_range(-1.5, 1.5)
	)
	fall_tumble_axis = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	fall_tumble_speed = randf_range(6.0, 12.0)

	# Play getting hit animation
	if anim_player and anim_player.has_animation("gettingHit_DyingInTheAir"):
		play_anim("gettingHit_DyingInTheAir", 0.05)
	elif anim_player and anim_player.has_animation("falling"):
		play_anim("falling", 0.05)

	_on_hit()

func _on_hit() -> void:
	pigeon_killed.emit(self, score_value, is_government)
