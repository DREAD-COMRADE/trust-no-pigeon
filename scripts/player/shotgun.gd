extends Node3D
class_name Shotgun

signal gun_fired(hit_object, hit_position)
signal shot_fired(from_pos: Vector3, direction_vec: Vector3)
signal ammo_changed(ammo_count: int)

@export var camera: Camera3D
@export var fire_rate: float = 0.65
@export var pellet_count: int = 10
@export var max_range: float = 120.0
@export var hip_spread: float = 0.085
@export var ads_spread: float = 0.040

@export var hip_position: Vector3 = Vector3(0.28, -0.30, -0.52)
@export var ads_position: Vector3 = Vector3(0.0, -0.19, -0.40)
@export var ads_speed: float = 16.0

@export var starting_ammo: int = 2

@export var tracer_scene: PackedScene = preload("res://scenes/effects/BulletTracer.tscn")

@onready var shoot_origin: Node3D = $ShootOrigin if has_node("ShootOrigin") else null
@onready var muzzle_flash: OmniLight3D = $MuzzleFlash if has_node("MuzzleFlash") else null
@onready var visual: Node3D = $Visual if has_node("Visual") else null
@onready var shoot_sound: AudioStreamPlayer3D = $ShootSound if has_node("ShootSound") else null

var ammo: int = 2
var is_active: bool = false
var can_fire: bool = true
var fire_timer: float = 0.0
var original_visual_pos: Vector3
var recoil_offset: Vector3 = Vector3.ZERO
var is_aiming: bool = false
var mouse_delta: Vector2 = Vector2.ZERO

func _ready() -> void:
	ammo = starting_ammo
	position = hip_position
	if not camera and get_parent() is Camera3D:
		camera = get_parent() as Camera3D
	if visual:
		original_visual_pos = visual.position
	if muzzle_flash:
		muzzle_flash.visible = false

func on_ammo_added() -> void:
	ammo_changed.emit(ammo)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or (get_tree() and get_tree().paused):
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			shoot()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_active or (get_tree() and get_tree().paused):
		return

	if not can_fire:
		fire_timer -= delta
		if fire_timer <= 0.0:
			can_fire = true

	# Smooth position transition between Hipfire and ADS
	var target_pos = ads_position if is_aiming else hip_position
	position = position.lerp(target_pos, delta * ads_speed)

	# Weapon sway
	var sway_amount = 0.0008 if not is_aiming else 0.0002
	var sway_rot = Vector3(-mouse_delta.y * sway_amount, -mouse_delta.x * sway_amount, 0.0)
	if visual:
		visual.rotation = visual.rotation.lerp(sway_rot, delta * 10.0)
		recoil_offset = recoil_offset.lerp(Vector3.ZERO, delta * 12.0)
		visual.position = original_visual_pos + recoil_offset

	if muzzle_flash and muzzle_flash.visible:
		muzzle_flash.visible = false

func shoot() -> void:
	if not can_fire or ammo <= 0 or (get_tree() and get_tree().paused):
		return

	can_fire = false
	fire_timer = fire_rate
	ammo -= 1
	ammo_changed.emit(ammo)

	if shoot_sound:
		shoot_sound.play()

	# Recoil effect
	recoil_offset.z += 0.22
	recoil_offset.y += 0.08

	if muzzle_flash:
		muzzle_flash.visible = true

	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.18 if is_aiming else 0.28)

	var cam_node = camera if camera else (get_parent() if get_parent() is Camera3D else null)
	var from = cam_node.global_position if cam_node else (global_position if is_inside_tree() else position)
	var base_dir = -cam_node.global_transform.basis.z if cam_node else (-global_transform.basis.z if is_inside_tree() else Vector3.FORWARD)
	var right_vec = cam_node.global_transform.basis.x if cam_node else (global_transform.basis.x if is_inside_tree() else Vector3.RIGHT)
	var up_vec = cam_node.global_transform.basis.y if cam_node else (global_transform.basis.y if is_inside_tree() else Vector3.UP)

	var spawn_muzzle_pos = shoot_origin.global_position if (shoot_origin and shoot_origin.is_inside_tree()) else from

	shot_fired.emit(from, base_dir)

	var spread_val = ads_spread if is_aiming else hip_spread
	var hit_targets: Array[Object] = []
	var space_state = get_world_3d().direct_space_state if is_inside_tree() else null

	# Fire multi-pellet spread cone with visual bullet tracers
	for i in range(pellet_count):
		var spread_x = randf_range(-spread_val, spread_val)
		var spread_y = randf_range(-spread_val, spread_val)
		var pellet_dir = (base_dir + right_vec * spread_x + up_vec * spread_y).normalized()
		var to = from + pellet_dir * max_range
		var target_end_point = to

		if space_state:
			var query = PhysicsRayQueryParameters3D.create(from, to)
			query.collide_with_areas = true
			query.collide_with_bodies = true

			var result = space_state.intersect_ray(query)
			if result:
				target_end_point = result.position
				var collider = result.collider
				gun_fired.emit(collider, result.position)
				if collider and not hit_targets.has(collider):
					hit_targets.append(collider)
					_apply_damage_to_target(collider, 2)

		# Spawn visible bullet tracer streak
		if tracer_scene and is_inside_tree():
			var tracer = tracer_scene.instantiate() as BulletTracer
			get_tree().root.add_child(tracer)
			tracer.setup(spawn_muzzle_pos, target_end_point)

func _apply_damage_to_target(target: Object, damage: int) -> void:
	if target.has_method("take_hit"):
		if target is PackageDrone:
			target.take_hit(damage) # Shotgun destroys drone in 1 shot
		else:
			target.take_hit()
	elif target.get_parent() and target.get_parent().has_method("take_hit"):
		if target.get_parent() is PackageDrone:
			target.get_parent().take_hit(damage)
		else:
			target.get_parent().take_hit()
