extends Node3D
class_name Shotgun

# ==============================================================================
# 🛠️ HARDWARE CLASSIFICATION & IDENTITY
# Manufacturer: O.F. Mossberg & Sons
# Base Platform: Mossberg 940/990 Gas System
# Legal Classification: "Other" Firearm (Non-NFA, No Stock, Bird's Head Grip)
# Action Type: Gas-Operated Semi-Automatic
# ==============================================================================

signal gun_fired(hit_object, hit_position)
signal shot_fired(from_pos: Vector3, direction_vec: Vector3)
signal ammo_changed(ammo_count: int)
signal reload_started()
signal reload_completed()
signal shell_inserted(current_ammo: int)

# --- 📏 Physical Dimensions & Weight Constants ---
const OVERALL_LENGTH_INCHES: float = 27.125 # 68.90 cm
const BARREL_LENGTH_INCHES: float = 14.75   # 37.46 cm
const BASE_WEIGHT_LBS: float = 6.60         # 2.99 kg empty
const SHELL_WEIGHT_LBS: float = 0.10        # +0.045 kg per shell
const CHOKE_TYPE: String = "Cylinder Bore"   # Fixed minimum spread cone

# --- 🔋 Magazine & Capacity Specs ---
const TUBE_CAPACITY: int = 5
const CHAMBER_CAPACITY: int = 1
const MAX_CAPACITY: int = 6 # 5 (Tube) + 1 (Chamber)

# --- ⏱️ Reload Timing Variables (with +15% Competition Port Buff) ---
const EMPTY_CHAMBER_PENALTY: float = 0.80 # Initial bolt slap/rack animation penalty
const BASE_SHELL_INSERT_TIME: float = 0.60 # 0.55s - 0.65s per shell
const COMPETITION_PORT_BUFF: float = 0.85 # +15% speed bonus from oversized loader bevel
const EFFECTIVE_SHELL_INSERT_TIME: float = BASE_SHELL_INSERT_TIME * COMPETITION_PORT_BUFF # ~0.51s

# --- 💥 Fire Rate & Ballistics Specs ---
const MECHANICAL_CYCLE_TIME: float = 0.12 # 0.11 - 0.13s (450-500 theoretical RPM)
const HUMAN_PRACTICAL_FIRE_RATE: float = 0.25 # ~240 RPM practical click registration limit

# --- 🎯 Bullet Spread & Damage Drop-Off Specs ---
const STANDARD_PELLET_COUNT: int = 9 # Standard 2.75" 00-Buckshot
const BASE_SPREAD_DEGREES: float = 2.85 # 2.5° to 3.0° random distribution cone
const PUSH_PULL_BRACE_SPREAD_MULT: float = 0.70 # 30% spread reduction in Aim/Brace state

const DAMAGE_DROP_FULL_RANGE: float = 10.0 # 100% damage: 0 to 10m
const DAMAGE_DROP_MAX_RANGE: float = 34.0  # Linear decay: 11 to 34m
const DAMAGE_DROP_MIN_THRESHOLD: float = 0.10 # 10% minimum damage threshold: 35m+

# --- 🔄 Recoil & Camera Handling Vectors (Bird's Head Grip Profile) ---
const GAS_PISTON_DAMPENING: float = 0.75 # 25% lower rearward impulse than pump-actions
const RECOIL_PITCH_KICK_HIP: float = 3.2 # Sharp upward vertical pitch
const RECOIL_YAW_SNAP_HIP: float = 1.4   # Erratic horizontal snap window
const PUSH_PULL_RECOIL_MULT: float = 0.70 # 30% reduction when aiming/bracing
const RECOIL_RECOVERY_SPEED: float = 8.5 # 30% slower settle time for bird's head grip

@export var camera: Camera3D
@export var fire_rate: float = HUMAN_PRACTICAL_FIRE_RATE
@export var pellet_count: int = STANDARD_PELLET_COUNT
@export var max_range: float = 100.0

@export var hip_position: Vector3 = Vector3(0.26, -0.28, -0.48)
@export var ads_position: Vector3 = Vector3(0.0, -0.17, -0.38)
@export var ads_speed: float = 14.0

@export var starting_ammo: int = 6
@export var reserve_ammo: int = 18

@export var tracer_scene: PackedScene = preload("res://scenes/effects/BulletTracer.tscn")

@onready var shoot_origin: Node3D = $ShootOrigin if has_node("ShootOrigin") else null
@onready var muzzle_flash: OmniLight3D = $MuzzleFlash if has_node("MuzzleFlash") else null
@onready var visual: Node3D = $Visual if has_node("Visual") else null
@onready var shoot_sound: AudioStreamPlayer3D = $ShootSound if has_node("ShootSound") else null
@onready var shell_load_sound: AudioStreamPlayer3D = $ShellLoadSound if has_node("ShellLoadSound") else null

var ammo: int = 6
var is_active: bool = false
var can_fire: bool = true
var fire_timer: float = 0.0

var is_aiming: bool = false
var mouse_delta: Vector2 = Vector2.ZERO

var original_visual_pos: Vector3
var recoil_offset: Vector3 = Vector3.ZERO
var recoil_rotation: Vector3 = Vector3.ZERO

# Iterative reload state machine
var is_reloading: bool = false
var reload_timer: float = 0.0
var reload_needs_rack: bool = false

func _ready() -> void:
	ammo = clamp(starting_ammo, 0, MAX_CAPACITY)
	position = hip_position
	if not camera and get_parent() is Camera3D:
		camera = get_parent() as Camera3D
	if visual:
		original_visual_pos = visual.position
	if muzzle_flash:
		muzzle_flash.visible = false

func get_total_weight_lbs() -> float:
	return BASE_WEIGHT_LBS + (ammo * SHELL_WEIGHT_LBS)

func on_ammo_added() -> void:
	ammo_changed.emit(ammo)

func add_shells(count: int) -> void:
	reserve_ammo += count
	# If empty in active magazine, auto trigger reload
	if ammo < MAX_CAPACITY and not is_reloading:
		start_reload()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or (get_tree() and get_tree().paused):
		return

	# Fire Trigger (Left Mouse Button)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# If reloading with at least 1 shell loaded, interrupt reload immediately and shoot!
			if is_reloading and ammo > 0:
				_cancel_reload()
				shoot()
			else:
				shoot()
			get_viewport().set_input_as_handled()

	# Manual Reload Key (R)
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		if not is_reloading and ammo < MAX_CAPACITY and (reserve_ammo > 0 or ammo < MAX_CAPACITY):
			start_reload()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_active or (get_tree() and get_tree().paused):
		return

	# Fire rate cooldown timer
	if not can_fire:
		fire_timer -= delta
		if fire_timer <= 0.0:
			can_fire = true

	# Iterative Tubular Magazine Reload Loop
	if is_reloading:
		_process_reload(delta)

	# Smooth position transition between Hipfire and ADS ("Push-Pull" Handguard Brace)
	var target_pos = ads_position if is_aiming else hip_position
	position = position.lerp(target_pos, delta * ads_speed)

	# Weapon sway & 30% slower recoil recovery settle time (bird's head grip characteristics)
	var sway_amount = 0.0006 if not is_aiming else 0.00018
	var sway_rot = Vector3(-mouse_delta.y * sway_amount, -mouse_delta.x * sway_amount, 0.0)

	if visual:
		recoil_offset = recoil_offset.lerp(Vector3.ZERO, delta * RECOIL_RECOVERY_SPEED)
		recoil_rotation = recoil_rotation.lerp(Vector3.ZERO, delta * (RECOIL_RECOVERY_SPEED * 0.9))
		visual.position = original_visual_pos + recoil_offset
		visual.rotation = sway_rot + recoil_rotation

	if muzzle_flash and muzzle_flash.visible:
		muzzle_flash.visible = false

func start_reload() -> void:
	if is_reloading or ammo >= MAX_CAPACITY:
		return

	is_reloading = true
	reload_needs_rack = (ammo == 0) # Apply 0.80s bolt slap/rack penalty if chamber is empty
	reload_timer = (EMPTY_CHAMBER_PENALTY + EFFECTIVE_SHELL_INSERT_TIME) if reload_needs_rack else EFFECTIVE_SHELL_INSERT_TIME
	reload_started.emit()

func _cancel_reload() -> void:
	is_reloading = false
	reload_timer = 0.0

func _process_reload(delta: float) -> void:
	reload_timer -= delta
	if reload_timer <= 0.0:
		# Single shell inserted into tubular magazine
		ammo += 1
		if reserve_ammo > 0:
			reserve_ammo -= 1

		ammo_changed.emit(ammo)
		shell_inserted.emit(ammo)

		# Play metallic shell loading click sound
		_play_shell_load_sound()

		# Visual nudge for shell insertion
		recoil_offset.z += 0.02
		recoil_offset.y -= 0.01

		# Check if magazine is fully loaded (6 rounds total) or out of reserve ammo
		if ammo >= MAX_CAPACITY:
			is_reloading = false
			reload_completed.emit()
		else:
			# Loop next shell insert
			reload_timer = EFFECTIVE_SHELL_INSERT_TIME

func _play_shell_load_sound() -> void:
	if shell_load_sound:
		shell_load_sound.pitch_scale = randf_range(0.85, 1.05)
		shell_load_sound.play()

func shoot() -> void:
	if not can_fire or ammo <= 0 or (get_tree() and get_tree().paused):
		if ammo <= 0 and not is_reloading:
			start_reload()
		return

	can_fire = false
	fire_timer = fire_rate
	ammo -= 1
	ammo_changed.emit(ammo)

	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.96, 1.04)
		shoot_sound.play()

	# Recoil calculation: Gas piston reduces raw rearward jerk by 25%
	# Push-Pull Brace (ADS) applies 30% reduction to total recoil vectors
	var brace_mult = PUSH_PULL_RECOIL_MULT if is_aiming else 1.0

	# Linear weapon kick (Gas system dampening applied)
	recoil_offset.z += 0.14 * GAS_PISTON_DAMPENING * brace_mult
	recoil_offset.y += 0.04 * brace_mult
	recoil_offset.x += 0.012 * brace_mult

	# High upward muzzle flip rotation + rightward twist (Bird's head grip torque)
	var kick_pitch = deg_to_rad(14.0 * brace_mult) # Upward barrel flip (+X angle tilts muzzle up)
	var kick_yaw = deg_to_rad(randf_range(2.0, 5.0) * brace_mult) # Rightward yaw drift (-Y angle turns muzzle right)
	var kick_roll = deg_to_rad(randf_range(-2.0, -4.5) * brace_mult) # Clockwise cant to the right
	recoil_rotation = Vector3(kick_pitch, -kick_yaw, kick_roll)

	# Camera trauma & Direct Camera Viewport Recoil Pitch Kick
	var cam_node = camera if camera else (get_parent() if get_parent() is Camera3D else null)
	if cam_node and cam_node.has_method("add_trauma"):
		cam_node.add_trauma(0.20 if is_aiming else 0.32)

	# Direct camera pitch kick to player controller (kicks camera up & slightly right)
	var player_ctrl = cam_node.get_parent() if cam_node else null
	if player_ctrl and player_ctrl.has_method("add_recoil"):
		var pitch_kick = RECOIL_PITCH_KICK_HIP * brace_mult
		var yaw_kick = randf_range(0.6, 1.4) * brace_mult
		player_ctrl.add_recoil(pitch_kick, yaw_kick)


	if muzzle_flash:
		muzzle_flash.visible = true

	# Projectile Spawn Muzzle Point (14.75" barrel length offset from receiver)
	var from = cam_node.global_position if cam_node else (global_position if is_inside_tree() else position)
	var base_dir = -cam_node.global_transform.basis.z if cam_node else (-global_transform.basis.z if is_inside_tree() else Vector3.FORWARD)
	var right_vec = cam_node.global_transform.basis.x if cam_node else (global_transform.basis.x if is_inside_tree() else Vector3.RIGHT)
	var up_vec = cam_node.global_transform.basis.y if cam_node else (global_transform.basis.y if is_inside_tree() else Vector3.UP)

	var spawn_muzzle_pos = shoot_origin.global_position if (shoot_origin and shoot_origin.is_inside_tree()) else from

	shot_fired.emit(from, base_dir)

	# Cylinder Bore 2.85° Base Spread Cone (Tighter in ADS / Push-Pull Brace)
	var spread_deg = BASE_SPREAD_DEGREES * brace_mult
	var spread_rad = deg_to_rad(spread_deg)

	var hit_targets: Array[Object] = []
	var space_state = get_world_3d().direct_space_state if is_inside_tree() else null

	# Fire 9-Pellet 00-Buckshot Array
	for i in range(pellet_count):
		# Circular cone distribution
		var circle_angle = randf() * TAU
		var circle_radius = sqrt(randf()) * spread_rad
		var offset_x = cos(circle_angle) * circle_radius
		var offset_y = sin(circle_angle) * circle_radius

		var pellet_dir = (base_dir + right_vec * offset_x + up_vec * offset_y).normalized()
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
				var hit_dist = from.distance_to(result.position)

				# Ballistic Damage Drop-Off Curve:
				# 0-10m: 100% | 11-34m: Linear Decay | 35m+: 10% Minimum Threshold
				var dmg_factor: float = 1.0
				if hit_dist <= DAMAGE_DROP_FULL_RANGE:
					dmg_factor = 1.0
				elif hit_dist <= DAMAGE_DROP_MAX_RANGE:
					var progress = (hit_dist - DAMAGE_DROP_FULL_RANGE) / (DAMAGE_DROP_MAX_RANGE - DAMAGE_DROP_FULL_RANGE)
					dmg_factor = lerp(1.0, DAMAGE_DROP_MIN_THRESHOLD, progress)
				else:
					dmg_factor = DAMAGE_DROP_MIN_THRESHOLD

				gun_fired.emit(collider, result.position)

				if collider and not hit_targets.has(collider):
					hit_targets.append(collider)
					_apply_damage_to_target(collider, dmg_factor)

		# Spawn visible high-velocity bullet tracer
		if tracer_scene and is_inside_tree():
			var tracer = tracer_scene.instantiate() as BulletTracer
			var target_parent = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
			target_parent.add_child(tracer)
			tracer.setup(spawn_muzzle_pos, target_end_point)

func _apply_damage_to_target(target: Object, dmg_factor: float) -> void:
	# At full damage (> 0.4), deals lethal damage to pigeons and 2 damage to drones
	var effective_damage: int = 2 if dmg_factor >= 0.5 else 1

	if target.has_method("take_hit"):
		if target is PackageDrone:
			target.take_hit(effective_damage)
		else:
			# Non-lethal at extreme ranges (35m+) unless player connects multiple shots
			if dmg_factor > 0.15 or randf() < 0.35:
				target.take_hit()
	elif target.get_parent() and target.get_parent().has_method("take_hit"):
		var p = target.get_parent()
		if p is PackageDrone:
			p.take_hit(effective_damage)
		else:
			if dmg_factor > 0.15 or randf() < 0.35:
				p.take_hit()
