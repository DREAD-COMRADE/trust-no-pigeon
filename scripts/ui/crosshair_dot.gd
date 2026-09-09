@tool
extends Control
class_name CrosshairDot

## Radius of the inner white dot in pixels
@export var dot_radius: float = 2.0:
	set(val):
		dot_radius = val
		queue_redraw()

## Thickness of the outer dark outline in pixels
@export var outline_width: float = 1.0:
	set(val):
		outline_width = val
		queue_redraw()

## Color of the center dot
@export var dot_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(val):
		dot_color = val
		queue_redraw()

## Color of the outline border (provides contrast against bright sky and clouds)
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.85):
	set(val):
		outline_color = val
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	# Draw sharp high-contrast outline
	draw_circle(Vector2.ZERO, dot_radius + outline_width, outline_color)
	# Draw crisp white dot at exact sub-pixel center
	draw_circle(Vector2.ZERO, dot_radius, dot_color)
