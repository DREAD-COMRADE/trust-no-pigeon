extends Node

var click_sound: AudioStream = preload("res://assets/Audio/menu_click.mp3")
var audio_player: AudioStreamPlayer


static func setup_ui_audio(root_node: Node) -> void:
	if not root_node or not root_node.is_inside_tree():
		return

	var helper = root_node.get_node_or_null("UIAudioHelper")

	if not helper:
		var script = load("res://scripts/ui/ui_audio_helper.gd")
		if script:
			helper = script.new()
			helper.name = "UIAudioHelper"
			root_node.add_child(helper)

	if helper and helper.has_method("bind_buttons_recursive"):
		helper.bind_buttons_recursive(root_node)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	audio_player = AudioStreamPlayer.new()
	audio_player.stream = click_sound
	audio_player.bus = &"Master"

	add_child(audio_player)


func bind_buttons_recursive(node: Node) -> void:
	if not node:
		return

	if node is BaseButton:
		if not node.has_meta("audio_bound"):
			node.set_meta("audio_bound", true)

			# Button click
			node.pressed.connect(func():
				play_click_sfx(1.0)
			)

			# Mouse hover
			node.mouse_entered.connect(func():
				play_click_sfx(1.2)
			)

	for child in node.get_children():
		bind_buttons_recursive(child)


func play_click_sfx(base_pitch: float = 1.0) -> void:
	if not audio_player or not click_sound:
		return

	# Small random pitch variation
	var pitch_variation := randf_range(0.96, 1.04)

	# Apply variation around the requested base pitch
	audio_player.pitch_scale = base_pitch * pitch_variation

	# Very subtle volume variation
	audio_player.volume_db = randf_range(-1.0, 0.5)

	audio_player.play()
