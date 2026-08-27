extends Marker3D
class_name PigeonSpawnZone

@export var position_jitter: Vector3 = Vector3(1.5, 1.0, 1.5)

func get_spawn_position() -> Vector3:
	var jitter = Vector3(
		randf_range(-position_jitter.x, position_jitter.x),
		randf_range(-position_jitter.y, position_jitter.y),
		randf_range(-position_jitter.z, position_jitter.z)
	)
	return global_position + jitter
