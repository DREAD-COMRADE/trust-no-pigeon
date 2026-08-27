extends SpotLight3D
class_name ProjectorLight

@export var sweep_speed: float = 0.5
@export var sweep_angle_yaw: float = 35.0
@export var sweep_angle_pitch: float = 15.0

var base_rotation: Vector3
var time_offset: float = 0.0
var is_active: bool = false

func _ready() -> void:
	add_to_group("projector_lights")
	base_rotation = rotation
	time_offset = randf() * 10.0
	visible = false

func set_light_state(enabled: bool) -> void:
	is_active = enabled
	visible = enabled

func _process(delta: float) -> void:
	if not is_active or not visible or get_tree().paused:
		return

	time_offset += delta * sweep_speed
	var yaw_offset = sin(time_offset) * deg_to_rad(sweep_angle_yaw)
	var pitch_offset = cos(time_offset * 1.5) * deg_to_rad(sweep_angle_pitch)

	rotation.y = base_rotation.y + yaw_offset
	rotation.x = base_rotation.x + pitch_offset
