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
		get_tree().root.add_child(fx)
		fx.global_position = global_position

	pigeon_killed.emit(self, score_value, is_government)
	queue_free()
