extends Node3D
class_name Gun

signal gun_fired(hit_object, hit_position)
signal shot_fired(from_pos: Vector3, direction_vec: Vector3)

@export var camera: Camera3D
@export var fire_rate: float = 0.15
@export var max_range: float = 150.0

@export var hip_position: Vector3 = Vector3(0.28, -0.28, -0.55)
@export var ads_position: Vector3 = Vector3(0.0, -0.165, -0.38)
@export var ads_speed: float = 16.0

@onready var shoot_origin: Node3D = $ShootOrigin if has_node("ShootOrigin") else null
@onready var muzzle_flash: OmniLight3D = $MuzzleFlash if has_node("MuzzleFlash") else null
@onready var visual: Node3D = $Visual if has_node("Visual") else null
@onready var shoot_sound: AudioStreamPlayer3D = $ShootSound if has_node("ShootSound") else null

var is_active: bool = true
var can_fire: bool = true
var fire_timer: float = 0.0
var init_grace_timer: float = 0.3 # Prevents accidental firing on scene load
var original_visual_pos: Vector3
var recoil_offset: Vector3 = Vector3.ZERO
var recoil_rotation: Vector3 = Vector3.ZERO
var is_aiming: bool = false
var mouse_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	position = hip_position
	init_grace_timer = 0.3

	if not camera and get_parent() is Camera3D:
		camera = get_parent() as Camera3D

	if visual:
		original_visual_pos = visual.position
	if muzzle_flash:
		muzzle_flash.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or (get_tree() and get_tree().paused) or init_grace_timer > 0.0:
		return

	# Single-source shooting trigger
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			shoot()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if init_grace_timer > 0.0:
		init_grace_timer -= delta

	if not is_active or (get_tree() and get_tree().paused):
		return

	if not can_fire:
		fire_timer -= delta
		if fire_timer <= 0.0:
			can_fire = true

	# Smooth position transition between Hipfire and ADS
	var target_pos = ads_position if is_aiming else hip_position
	position = position.lerp(target_pos, delta * ads_speed)

	# Weapon sway & recoil recovery
	var sway_amount = 0.0008 if not is_aiming else 0.0002
	var sway_rot = Vector3(-mouse_delta.y * sway_amount, -mouse_delta.x * sway_amount, 0.0)

	if visual:
		recoil_offset = recoil_offset.lerp(Vector3.ZERO, delta * 15.0)
		recoil_rotation = recoil_rotation.lerp(Vector3.ZERO, delta * 18.0)
		visual.position = original_visual_pos + recoil_offset
		visual.rotation = sway_rot + recoil_rotation

	if muzzle_flash and muzzle_flash.visible:
		muzzle_flash.visible = false


var empty_sound_stream: AudioStream = preload("res://assets/Audio/empty_gunshot.mp3")

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

func shoot() -> void:
	if not is_active or (get_tree() and get_tree().paused) or init_grace_timer > 0.0:
		return

	if not can_fire:
		return


	can_fire = false
	fire_timer = fire_rate

	if shoot_sound:
		shoot_sound.play()

	# Record shot statistic
	var main = get_tree().current_scene
	if main and main.has_node("Systems/ScoreManager"):
		var sm = main.get_node("Systems/ScoreManager")
		if sm and sm.has_method("record_shot"):
			sm.record_shot()

	# Recoil effect (Upward kick + slight rightward drift)
	var ads_mult = 0.65 if is_aiming else 1.0
	recoil_offset.z += 0.08 * ads_mult
	recoil_offset.y += 0.02 * ads_mult
	recoil_offset.x += 0.006 * ads_mult
	recoil_rotation = Vector3(deg_to_rad(7.5 * ads_mult), deg_to_rad(-2.0 * ads_mult), deg_to_rad(-1.5 * ads_mult))

	# Muzzle flash
	if muzzle_flash:
		muzzle_flash.visible = true

	# Camera nudge
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.08 if is_aiming else 0.14)

	var cam_node = camera if camera else (get_parent() if get_parent() is Camera3D else null)
	if cam_node:
		var player_ctrl = cam_node.get_parent() if cam_node else null
		if player_ctrl and player_ctrl.has_method("add_recoil"):
			player_ctrl.add_recoil(0.7 * ads_mult, 0.3 * ads_mult)


	var from = cam_node.global_position if cam_node else global_position
	var dir = -cam_node.global_transform.basis.z if cam_node else -global_transform.basis.z
	var to = from + dir * max_range


	shot_fired.emit(from, dir)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		gun_fired.emit(collider, result.position)
		if collider.has_method("take_hit"):
			if collider is PackageDrone:
				collider.take_hit(1)
			else:
				collider.take_hit()
		elif collider.get_parent() and collider.get_parent().has_method("take_hit"):
			if collider.get_parent() is PackageDrone:
				collider.get_parent().take_hit(1)
			else:
				collider.get_parent().take_hit()
	else:
		gun_fired.emit(null, Vector3.ZERO)
