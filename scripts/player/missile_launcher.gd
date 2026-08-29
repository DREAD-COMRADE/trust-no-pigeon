extends Node3D
class_name MissileLauncher

signal ammo_changed(ammo_count: int)
signal switch_to_gun_requested

@export var camera: Camera3D
@export var missile_scene: PackedScene = preload("res://scenes/objects/GuidedMissile.tscn")
@export var hip_position: Vector3 = Vector3(0.32, -0.32, -0.6)
@export var ads_position: Vector3 = Vector3(0.121, -0.123, -0.066)
@export var ads_speed: float = 14.0

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
var recoil_offset: Vector3 = Vector3.ZERO
var is_aiming: bool = false
var mouse_delta: Vector2 = Vector2.ZERO

func _ready() -> void:
	position = hip_position
	if not camera and get_parent() is Camera3D:
		camera = get_parent() as Camera3D

func on_ammo_added() -> void:
	ammo_changed.emit(ammo)
	play_reload_sound()

func play_reload_sound() -> void:
	if not reload_sound_stream or not is_inside_tree():
		return
	var asp = AudioStreamPlayer3D.new()
	asp.stream = reload_sound_stream
	asp.volume_db = 3.0
	asp.pitch_scale = randf_range(0.97, 1.03)
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
			if ammo > 0 and not has_fired:
				fire_missile()
			else:
				_play_dry_fire_sound()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_active or (get_tree() and get_tree().paused):
		return

	# Smooth position transition between Hipfire and ADS
	var target_pos = ads_position if is_aiming else hip_position
	position = position.lerp(target_pos, delta * ads_speed)

	# Weapon sway & recoil
	var sway_amount = 0.0006 if not is_aiming else 0.0002
	var sway_rot = Vector3(-mouse_delta.y * sway_amount, -mouse_delta.x * sway_amount, 0.0)
	if visual:
		visual.rotation = visual.rotation.lerp(sway_rot, delta * 10.0)
		recoil_offset = recoil_offset.lerp(Vector3.ZERO, delta * 10.0)
		visual.position = recoil_offset

	if muzzle_flash and muzzle_flash.visible:
		muzzle_flash.visible = false

func fire_missile() -> void:
	if ammo <= 0 or has_fired:
		return

	has_fired = true
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

	# Recoil kick
	recoil_offset.z += 0.25
	recoil_offset.y += 0.08
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
	has_fired = false
	if ammo > 0:
		play_reload_sound() # Chamber next rocket
	else:
		await get_tree().create_timer(0.8).timeout
		if ammo <= 0:
			switch_to_gun_requested.emit()
