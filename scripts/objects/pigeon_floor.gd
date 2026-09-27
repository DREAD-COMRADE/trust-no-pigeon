@tool
extends Node3D
class_name PigeonFloor

## PigeonFloor defines the physical & visual floor height where shot pigeons fall and impact.
## You can freely move this node in the Godot 3D Editor to adjust the impact plane height.

@export var debug_mesh_visible_in_game: bool = false

@onready var visual_plane: MeshInstance3D = get_node_or_null("VisualPlane")

func _ready() -> void:
	add_to_group("pigeon_floor")
	if visual_plane and not Engine.is_editor_hint():
		visual_plane.visible = debug_mesh_visible_in_game

func get_floor_y() -> float:
	return global_position.y
