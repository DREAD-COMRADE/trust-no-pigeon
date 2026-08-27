extends Area3D
class_name PigeonBase

enum State { FLYING, ATTACKING, DYING }

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

@onready var visual: Node3D = $Visual
@onready var wing_left: Node3D = $Visual/WingLeft if has_node("Visual/WingLeft") else null
@onready var wing_right: Node3D = $Visual/WingRight if has_node("Visual/WingRight") else null

signal pigeon_killed(pigeon, score, is_gov)
signal pigeon_escaped(pigeon)

func _ready() -> void:
	time_passed = randf() * 10.0
	previous_position = global_position

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
		State.DYING:
			pass

func _animate_wings() -> void:
	var flap_angle = sin(time_passed) * 0.45
	if wing_left:
		wing_left.rotation.z = flap_angle
	if wing_right:
		wing_right.rotation.z = -flap_angle

func _process_flying(delta: float) -> void:
	progress_t += (actual_speed / total_distance) * delta

	if progress_t >= 1.0:
		_on_reach_bounds()
		return

	# Quadratic Bezier Curve position
	var u = 1.0 - progress_t
	var pos = u * u * start_point + 2.0 * u * progress_t * control_point + progress_t * progress_t * end_point

	# Organic undulating wing bobbing
	var bob = Vector3(0, sin(time_passed * 1.8) * 0.25, cos(time_passed * 1.4) * 0.15)
	global_position = pos + bob
	global_position.y = max(global_position.y, 1.2)

	_update_flight_rotation(delta)

func _update_flight_rotation(delta: float) -> void:
	var velocity = (global_position - previous_position) / max(delta, 0.001)
	previous_position = global_position

	if velocity.length_squared() < 0.01:
		return

	var target_basis = global_transform.looking_at(global_position + velocity, Vector3.UP).basis
	global_transform.basis = global_transform.basis.slerp(target_basis, delta * 12.0)

func _process_attacking(delta: float) -> void:
	var dir = (target_player_pos - global_position).normalized()
	if dir != Vector3.ZERO:
		look_at(global_position + dir, Vector3.UP)
	global_position += dir * actual_speed * delta

func _on_reach_bounds() -> void:
	pigeon_escaped.emit(self)
	queue_free()

func take_hit() -> void:
	if current_state == State.DYING:
		return
	current_state = State.DYING
	_on_hit()

func _on_hit() -> void:
	pigeon_killed.emit(self, score_value, is_government)
	queue_free()
