extends Parallax2D

@export var strength := 12.0
@export var smooth_speed := 3

var target_position := Vector2.ZERO

func _ready():
	target_position = position

func _process(delta):
	var mouse_pos := get_viewport().get_mouse_position()
	var screen_size := get_viewport_rect().size

	var offset := (mouse_pos / screen_size) - Vector2(0.5, 0.5)

	target_position = offset * strength

	position = position.lerp(target_position, smooth_speed * delta)
