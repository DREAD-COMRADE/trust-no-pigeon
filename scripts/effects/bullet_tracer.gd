extends Node3D
class_name BulletTracer

@export var speed: float = 240.0
@export var lifetime: float = 0.25

var direction: Vector3 = Vector3.FORWARD
var target_pos: Vector3
var distance_traveled: float = 0.0
var max_distance: float = 120.0
var time_alive: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null

func setup(from: Vector3, to: Vector3) -> void:
	global_position = from
	target_pos = to
	direction = (to - from).normalized()
	max_distance = from.distance_to(to)
	if direction != Vector3.ZERO:
		look_at(from + direction, Vector3.UP)

func _process(delta: float) -> void:
	time_alive += delta
	var move_dist = speed * delta
	global_position += direction * move_dist
	distance_traveled += move_dist

	# Fade out near end of life or destination
	if distance_traveled >= max_distance or time_alive >= lifetime:
		queue_free()
