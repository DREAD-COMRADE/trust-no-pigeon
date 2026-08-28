extends Node

var click_sound: AudioStream = preload("res://assets/Audio/menu_click.mp3")

# Pitch ranges for variation: hover = slightly higher/breezy, click = solid punch
const HOVER_PITCH_MIN := 1.08
const HOVER_PITCH_MAX := 1.28
const CLICK_PITCH_MIN := 0.88
const CLICK_PITCH_MAX := 1.08

static func setup_ui_audio(root_node: Node) -> void:
	if not root_node:
		return

	var helper = root_node.get_node_or_null("UIAudioHelper")
	if not helper:
		var script = load("res://scripts/ui/ui_audio_helper.gd")
		if script:
			helper = script.new()
			helper.name = "UIAudioHelper"
			root_node.add_child(helper)

	if helper and helper.has_method("bind_buttons_deferred"):
		helper.bind_buttons_deferred(root_node)

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func bind_buttons_deferred(root_node: Node) -> void:
	# Wait one frame so we're fully mounted inside the scene tree
	if is_inside_tree():
		await get_tree().process_frame
	bind_buttons_recursive(root_node)

func bind_buttons_recursive(node: Node) -> void:
	if not node:
		return

	if node is BaseButton:
		if not node.has_meta("audio_bound"):
			node.set_meta("audio_bound", true)
			node.pressed.connect(func(): play_click_sfx(false))
			node.mouse_entered.connect(func(): play_click_sfx(true))

	for child in node.get_children():
		bind_buttons_recursive(child)

func play_click_sfx(is_hover: bool = false) -> void:
	if not is_inside_tree() or not click_sound:
		return

	# Polyphonic player: spawns an independent player per sound so fast hovers/clicks don't cut off
	var player = AudioStreamPlayer.new()
	player.stream = click_sound
	player.bus = &"Master"
	player.process_mode = PROCESS_MODE_ALWAYS

	if is_hover:
		player.pitch_scale = randf_range(HOVER_PITCH_MIN, HOVER_PITCH_MAX)
		player.volume_db = -8.0
	else:
		player.pitch_scale = randf_range(CLICK_PITCH_MIN, CLICK_PITCH_MAX)
		player.volume_db = -4.0

	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
