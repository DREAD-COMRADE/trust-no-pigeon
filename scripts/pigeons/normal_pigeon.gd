extends PigeonBase
class_name NormalPigeon


var hit_effect_scene: PackedScene = preload("res://scenes/effects/NormalPigeonHit.tscn")

func _ready() -> void:
	super._ready()
	score_value = 100
	is_government = false

func _on_hit() -> void:
	if hit_effect_scene:
		var fx = hit_effect_scene.instantiate()
		var parent = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
		parent.add_child(fx)
		fx.global_position = global_position

	pigeon_killed.emit(self, score_value, is_government)

