extends Label

func _process(_delta):
	text = "FPS: %d\nFrame Time: %.2f ms" % [
		Engine.get_frames_per_second(),
		1000.0 / Engine.get_frames_per_second()
	]
