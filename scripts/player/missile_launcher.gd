extends Node3D
class_name MissileLauncher

signal ammo_changed(ammo_count: int)
signal switch_to_gun_requested
signal reload_started()
signal reload_completed()

const RELOAD_DURATION: float = 2.48 # Matches Rocket_launcher_reload.mp3 length

@export var camera: Camera3D
@export var missile_scene: PackedScene = preload("res://scenes/objects/GuidedMissile.tscn")
@export var hip_position: Vector3 = Vector3(0.32, -0.32, -0.6)
@export var ads_position: Vector3 = Vector3(0.121, -0.123, -0.066)
@export var ads_speed: float = 14.0
@export var reload_sound_delay: float = 0.20 # Tunable delay before audio plays while launcher lowers

@onready var shoot_origin: Node3D = $ShootOrigin if has_node("ShootOrigin") else null
@onready var visual: Node3D = $Visual if has_node("Visual") else null
@onready var muzzle_flash: OmniLight3D = $MuzzleFlash if has_node("MuzzleFlash") else null
@onready var launch_sound: AudioStreamPlayer3D = $LaunchSound if has_node("LaunchSound") else null

var launch_sound_stream: AudioStream = preload("res://assets/Audio/Rocket_launch.mp3")
var reload_sound_stream: AudioStream = preload("res://assets/Audio/Rocket_launcher_reload.mp3")
var empty_sound_stream: AudioStream = preload("res://assets/Audio/empty_gunshot.mp3")

var ammo: int = 0
var is_active: bool = false
var has_fired: bool = false
var is_bore_loaded: bool = false # Only 1 projectile in bore at any time
var is_reloading: bool = false
var reload_timer: float = 0.0

# Randomized reload angles per sequence (15-25° down, 18-25° left)
var target_down_deg: float = 20.0
var target_left_deg: float = 22.0

var recoil_offset: Vector3 = Vector3.ZERO
var recoil_rotation: Vector3 = Vector3.ZERO
var is_aiming: bool = false
var mouse_delta: Vector2 = Vector2.ZERO

func _ready() -> void:
	position = hip_position
	if not camera and get_parent() is Camera3D:
		camera = get_parent() as Camera3D

func on_ammo_added() -> void:
	ammo_changed.emit(ammo)
	# Only reload if the bore is currently empty and not already reloading/firing
	if ammo > 0 and not is_bore_loaded and not is_reloading and not has_fired:
		start_reload()

func start_reload() -> void:
	# If bore is already loaded, reloading or empty, do nothing
	if is_reloading or ammo <= 0 or is_bore_loaded:
		return

	is_reloading = true
	reload_timer = RELOAD_DURATION

	# Pick organic randomized reload angle ranges
	target_down_deg = randf_range(15.0, 25.0) # 15° to 25° pointing down
	target_left_deg = randf_range(18.0, 25.0) # 18° to 25° pointing left

	reload_started.emit()

	# Delayed audio playback: allows player weapon adjustment into stance first
	if reload_sound_delay > 0.0 and is_inside_tree():
		get_tree().create_timer(reload_sound_delay).timeout.connect(func():
			if is_reloading and is_inside_tree():
				play_reload_sound()
		)
	else:
		play_reload_sound()

func play_reload_sound() -> void:
	if not reload_sound_stream or not is_inside_tree():
		return
	var asp = AudioStreamPlayer3D.new()
	asp.stream = reload_sound_stream
	asp.volume_db = 3.0
	asp.pitch_scale = randf_range(0.98, 1.02)
	add_child(asp)
	asp.finished.connect(asp.queue_free)
	asp.play()

func _play_dry_fire_sound() -> void:
	if not empty_sound_stream or not is_inside_tree():
		return
	var player = AudioStreamPlayer3D.new()
	player.stream = empty_sound_stream
	player.volume_db = 1.0
	player.pitch_scale = randf_range(0.95, 1.05)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or (get_tree() and get_tree().paused):
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if ammo > 0 and is_bore_loaded and not has_fired and not is_reloading:
				fire_missile()
			else:
				_play_dry_fire_sound()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_active or (get_tree() and get_tree().paused):
		return

	# Smooth & Bumpy Procedural Shoulder Reload Animation
	if is_reloading:
		reload_timer -= delta
		var progress = 1.0 - clamp(reload_timer / RELOAD_DURATION, 0.0, 1.0) # 0.0 -> 1.0

		var target_rot = Vector3.ZERO
		var target_pos_offset = Vector3.ZERO

		if progress < 0.32:
			# Phase 1: Smoothly lower launcher down (15-25°) and left (18-25°) into reload stance
			var ease_down = _ease_in_out(progress / 0.32)
			target_rot.x = -deg_to_rad(target_down_deg) * ease_down
			target_rot.y = deg_to_rad(target_left_deg) * ease_down
			target_rot.z = -deg_to_rad(target_left_deg * 0.35) * ease_down
			target_pos_offset = Vector3(0.04 * ease_down, -0.08 * ease_down, 0.05 * ease_down)
		elif progress < 0.72:
			# Phase 2: Rocket slides into bore with gentle mechanical insertion bump
			var phase_prog = (progress - 0.32) / 0.40 # 0.0 -> 1.0
			var insertion_bump = sin(phase_prog * PI) * 0.022 # Smooth physical jolt along launch tube

			target_rot.x = -deg_to_rad(target_down_deg) + deg_to_rad(sin(phase_prog * PI) * 2.5)
			target_rot.y = deg_to_rad(target_left_deg)
			target_rot.z = -deg_to_rad(target_left_deg * 0.35)
			target_pos_offset = Vector3(0.04, -0.08 - insertion_bump * 0.5, 0.05 + insertion_bump)
		else:
			# Phase 3: Smoothly raise & lock launcher back to shoulder crosshair position
			var ease_up = 1.0 - _ease_in_out((progress - 0.72) / 0.28)
			target_rot.x = -deg_to_rad(target_down_deg) * ease_up
			target_rot.y = deg_to_rad(target_left_deg) * ease_up
			target_rot.z = -deg_to_rad(target_left_deg * 0.35) * ease_up
			target_pos_offset = Vector3(0.04 * ease_up, -0.08 * ease_up, 0.05 * ease_up)

		recoil_rotation = recoil_rotation.lerp(target_rot, delta * 12.0)
		recoil_offset = recoil_offset.lerp(target_pos_offset, delta * 12.0)

		if reload_timer <= 0.0:
			is_reloading = false
			is_bore_loaded = true
			has_fired = false
			recoil_rotation = Vector3.ZERO
			recoil_offset = Vector3.ZERO
			reload_completed.emit()
	else:
		recoil_offset = recoil_offset.lerp(Vector3.ZERO, delta * 10.0)
		recoil_rotation = recoil_rotation.lerp(Vector3.ZERO, delta * 10.0)

	# Smooth position transition between Hipfire and ADS
	var target_pos = ads_position if is_aiming else hip_position
	position = position.lerp(target_pos, delta * ads_speed)

	# Weapon sway
	var sway_amount = 0.0006 if not is_aiming else 0.0002
	var sway_rot = Vector3(-mouse_delta.y * sway_amount, -mouse_delta.x * sway_amount, 0.0)

	if visual:
		visual.rotation = sway_rot + recoil_rotation
		visual.position = recoil_offset

	if muzzle_flash and muzzle_flash.visible:
		muzzle_flash.visible = false

func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func fire_missile() -> void:
	if ammo <= 0 or has_fired or is_reloading or not is_bore_loaded:
		return

	has_fired = true
	is_bore_loaded = false
	ammo -= 1
	ammo_changed.emit(ammo)

	# Play Rocket Launch sound
	if launch_sound:
		launch_sound.play()
	elif launch_sound_stream:
		var asp = AudioStreamPlayer3D.new()
		asp.stream = launch_sound_stream
		asp.volume_db = 8.0
		var target_scene = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
		target_scene.add_child(asp)
		asp.global_position = global_position
		asp.play()
		asp.finished.connect(asp.queue_free)

	# Recoil kick (upward muzzle jump)
	recoil_offset.z += 0.22
	recoil_offset.y += 0.06
	recoil_rotation = Vector3(deg_to_rad(12.0), deg_to_rad(-2.0), 0.0)

	if muzzle_flash:
		muzzle_flash.visible = true

	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.3)

	if missile_scene:
		var missile = missile_scene.instantiate() as GuidedMissile
		var spawn_pos = shoot_origin.global_position if shoot_origin else global_position
		var cam_node = camera if camera else (get_parent() if get_parent() is Camera3D else null)
		var fwd_dir = -cam_node.global_transform.basis.z if cam_node else -global_transform.basis.z

		var target_parent = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
		target_parent.add_child(missile)
		missile.global_position = spawn_pos
		missile.global_transform = missile.global_transform.looking_at(spawn_pos + fwd_dir, Vector3.UP)

		missile.missile_detonated.connect(_on_missile_detonated)

func _on_missile_detonated(_hit_ufo: bool) -> void:
	if ammo > 0:
		start_reload() # Chamber next rocket into bore
	else:
		has_fired = false
		await get_tree().create_timer(1.2).timeout
		if ammo <= 0 and is_active:
			switch_to_gun_requested.emit()
