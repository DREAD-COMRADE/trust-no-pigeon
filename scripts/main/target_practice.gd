extends Node3D

@onready var camera: Camera3D = $Player/Camera3D
@onready var gun: Node3D = $Player/Camera3D/Gun
@onready var score_manager: ScoreManager = $Systems/ScoreManager
@onready var hud: CanvasLayer = $Systems/HUD

func _ready() -> void:
	if gun and gun.has_method("shoot"):
		gun.camera = camera

	if score_manager:
		score_manager.score_updated.connect(_on_score_updated)

	if hud:
		hud.restart_requested.connect(restart_scene)
		if hud.has_node("TopMargin/HBox/AggressionLabel"):
			hud.get_node("TopMargin/HBox/AggressionLabel").text = "TARGET RANGE [T: MAIN LEVEL]"

	_on_score_updated(0, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_T and event.pressed:
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_score_updated(current: int, high: int) -> void:
	if hud:
		hud.update_score(current, high)

func restart_scene() -> void:
	get_tree().reload_current_scene()
