@tool
extends TextureRect
class_name CrosshairDot

## Size of the crosshair dot on screen in pixels
@export var dot_size: Vector2 = Vector2(3.0, 3.0):
	set(val):

		dot_size = val
		_update_crosshair_size()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not texture:
		texture = preload("res://crossair.png")
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_update_crosshair_size()

func _update_crosshair_size() -> void:
	custom_minimum_size = dot_size
	size = dot_size
	offset_left = -dot_size.x * 0.5
	offset_top = -dot_size.y * 0.5
	offset_right = dot_size.x * 0.5
	offset_bottom = dot_size.y * 0.5

