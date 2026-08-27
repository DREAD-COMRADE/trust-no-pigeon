extends Camera3D

@export var max_offset: Vector2 = Vector2(0.12, 0.12)
@export var max_roll: float = 0.02
@export var decay: float = 4.0

var trauma: float = 0.0
var trauma_power: float = 2.0

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if trauma > 0.0:
		trauma = max(trauma - decay * delta, 0.0)
		shake()
	else:
		h_offset = lerp(h_offset, 0.0, delta * 12.0)
		v_offset = lerp(v_offset, 0.0, delta * 12.0)
		rotation.z = lerp(rotation.z, 0.0, delta * 12.0)

func shake() -> void:
	var amount = pow(trauma, trauma_power)
	h_offset = max_offset.x * amount * randf_range(-1.0, 1.0)
	v_offset = max_offset.y * amount * randf_range(-1.0, 1.0)
	rotation.z = max_roll * amount * randf_range(-1.0, 1.0)
