extends Area3D
class_name TargetBoard

@export var score_value_bullseye: int = 200
@export var score_value_outer: int = 50

@onready var visual: Node3D = $Visual
@onready var center_marker: Node3D = $Visual/Bullseye if has_node("Visual/Bullseye") else null

var original_rot: Vector3
var wobble_timer: float = 0.0

func _ready() -> void:
	if visual:
		original_rot = visual.rotation

func _process(delta: float) -> void:
	if wobble_timer > 0.0:
		wobble_timer -= delta
		var wobble = sin(wobble_timer * 30.0) * wobble_timer * 0.3
		if visual:
			visual.rotation.x = original_rot.x + wobble

func take_hit() -> void:
	wobble_timer = 0.4

	# Spawn hit hole visual
	var hole = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.05, 1.0)
	sphere.material = mat
	hole.mesh = sphere

	add_child(hole)

	# Get main camera ray to position hit mark slightly in front of face
	var camera = get_viewport().get_camera_3d()
	if camera:
		var center_pos = global_position
		var hit_pos = center_pos + (camera.global_position - center_pos).normalized() * 0.1
		hole.global_position = hit_pos

	# Award score via Main scene
	var main = get_tree().current_scene
	if main and main.has_node("Systems/ScoreManager"):
		var score_mgr = main.get_node("Systems/ScoreManager")
		if score_mgr and score_mgr.has_method("add_score"):
			score_mgr.add_score(score_value_bullseye, false)
