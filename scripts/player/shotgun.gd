extends Node3D
class_name Shotgun

signal gun_fired(hit_object, hit_position)
signal shot_fired(from_pos: Vector3, direction_vec: Vector3)
signal ammo_changed(ammo_count: int)
signal reload_started()
signal reload_completed()
signal shell_inserted(current_ammo: int)

# ── Capacity ───────────────────────────────────────────────────────────────────
const MAX_CAPACITY: int = 6  # 5 tube + 1 chamber

# ── Reload timing ──────────────────────────────────────────────────────────────
const EMPTY_CHAMBER_PENALTY: float = 0.80       # Extra delay when chamber is empty
const EFFECTIVE_SHELL_INSERT_TIME: float = 0.51  # Per-shell insert time (~0.51s)

# ── Fire rate ──────────────────────────────────────────────────────────────────
const HUMAN_PRACTICAL_FIRE_RATE: float = 0.25

# ── Spread & pellets ───────────────────────────────────────────────────────────
const STANDARD_PELLET_COUNT: int = 12
const BASE_SPREAD_DEGREES: float = 4.5
const PUSH_PULL_BRACE_SPREAD_MULT: float = 0.55  # ADS tightens spread by 45%

# ── Damage drop-off ────────────────────────────────────────────────────────────
const DAMAGE_DROP_FULL_RANGE: float = 18.0       # 100% damage within 18m
const DAMAGE_DROP_MAX_RANGE: float = 55.0        # Linear decay 18–55m
const DAMAGE_DROP_MIN_THRESHOLD: float = 0.10    # 10% floor beyond 55m

# ── Recoil ─────────────────────────────────────────────────────────────────────
const GAS_PISTON_DAMPENING: float = 0.75
const RECOIL_PITCH_KICK_HIP: float = 3.2
const PUSH_PULL_RECOIL_MULT: float = 0.70        # 30% reduction when aiming
const RECOIL_RECOVERY_SPEED: float = 8.5

@export var camera: Camera3D
@export var fire_rate: float = HUMAN_PRACTICAL_FIRE_RATE
@export var pellet_count: int = STANDARD_PELLET_COUNT
@export var max_range: float = 100.0


@export var hip_position: Vector3 = Vector3(0.26, -0.28, -0.48)
@export var ads_position: Vector3 = Vector3(-0.0113, -0.078, -0.32)
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

# Cached references — resolved once in _ready()
var _player_ctrl: PlayerController = null

func _ready() -> void:
	ammo = clamp(starting_ammo, 0, MAX_CAPACITY)
	position = hip_position
	if not camera and get_parent() is Camera3D:
		camera = get_parent() as Camera3D

	# Cache player controller reference once
	if camera:
		var p = camera.get_parent()
		if p is PlayerController:
			_player_ctrl = p as PlayerController

	if visual:
		original_visual_pos = visual.position
	if muzzle_flash:
		muzzle_flash.visible = false


func on_ammo_added() -> void:
	ammo_changed.emit(ammo)

func add_shells(count: int) -> void:
	reserve_ammo += count
	# If empty, auto trigger reload
	if ammo < MAX_CAPACITY and not is_reloading:
		start_reload()

var empty_sound_stream: AudioStream = preload("res://assets/Audio/empty_gunshot.mp3")

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

	# Manual Reload Key (R) - only reloads if reserve ammo is available
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		if not is_reloading and ammo < MAX_CAPACITY and reserve_ammo > 0:
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
	# If gun and reserve storage are empty, do not reload
	if is_reloading or ammo >= MAX_CAPACITY or reserve_ammo <= 0:
		return

	is_reloading = true
	reload_needs_rack = (ammo == 0) # Apply 0.80s bolt slap/rack penalty if chamber is empty
	reload_timer = (EMPTY_CHAMBER_PENALTY + EFFECTIVE_SHELL_INSERT_TIME) if reload_needs_rack else EFFECTIVE_SHELL_INSERT_TIME
	reload_started.emit()

func _cancel_reload() -> void:
	is_reloading = false
	reload_timer = 0.0

func _process_reload(delta: float) -> void:
	# Stop reload immediately if reserve runs out
	if reserve_ammo <= 0:
		is_reloading = false
		reload_completed.emit()
		return

	reload_timer -= delta
	if reload_timer <= 0.0:
		# Single shell inserted into tubular magazine
		ammo += 1
		reserve_ammo -= 1

		ammo_changed.emit(ammo)
		shell_inserted.emit(ammo)

		# Play metallic shell loading click sound
		_play_shell_load_sound()

		# Visual nudge for shell insertion
		recoil_offset.z += 0.02
		recoil_offset.y -= 0.01

		# Check if magazine is fully loaded (6 rounds total) or out of reserve ammo
		if ammo >= MAX_CAPACITY or reserve_ammo <= 0:
			is_reloading = false
			reload_completed.emit()
		else:
			# Loop next shell insert
			reload_timer = EFFECTIVE_SHELL_INSERT_TIME

func _play_shell_load_sound() -> void:
	if shell_load_sound:
		shell_load_sound.pitch_scale = randf_range(0.85, 1.05)
		shell_load_sound.play()

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
	if not can_fire or (get_tree() and get_tree().paused):
		return

	# When player tries to shoot an empty gun, play dry-fire empty gunshot sound
	if ammo <= 0:
		_play_dry_fire_sound()
		if reserve_ammo > 0 and not is_reloading:
			start_reload()
		return

	can_fire = false
	fire_timer = fire_rate
	ammo -= 1
	ammo_changed.emit(ammo)

	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.96, 1.04)
		shoot_sound.play()

	var brace_mult = PUSH_PULL_RECOIL_MULT if is_aiming else 1.0

	# Weapon kick
	recoil_offset.z += 0.14 * GAS_PISTON_DAMPENING * brace_mult
	recoil_offset.y += 0.04 * brace_mult
	recoil_offset.x += 0.012 * brace_mult

	var kick_pitch = deg_to_rad(14.0 * brace_mult)
	var kick_yaw   = deg_to_rad(randf_range(2.0, 5.0) * brace_mult)
	var kick_roll  = deg_to_rad(randf_range(-2.0, -4.5) * brace_mult)
	recoil_rotation = Vector3(kick_pitch, -kick_yaw, kick_roll)

	# Camera trauma — use camera directly, no parent walking
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.20 if is_aiming else 0.32)

	# Recoil pitch kick — use cached player controller
	if _player_ctrl and _player_ctrl.has_method("add_recoil"):
		var pitch_kick = RECOIL_PITCH_KICK_HIP * brace_mult
		var yaw_kick = randf_range(0.6, 1.4) * brace_mult
		_player_ctrl.add_recoil(pitch_kick, yaw_kick)

	if muzzle_flash:
		muzzle_flash.visible = true

	var from      = camera.global_position if camera else (global_position if is_inside_tree() else position)
	var base_dir  = -camera.global_transform.basis.z if camera else (-global_transform.basis.z if is_inside_tree() else Vector3.FORWARD)
	var right_vec = camera.global_transform.basis.x if camera else (global_transform.basis.x if is_inside_tree() else Vector3.RIGHT)
	var up_vec    = camera.global_transform.basis.y if camera else (global_transform.basis.y if is_inside_tree() else Vector3.UP)

	var spawn_muzzle_pos = shoot_origin.global_position if (shoot_origin and shoot_origin.is_inside_tree()) else from

	shot_fired.emit(from, base_dir)


	# Cylinder Bore 2.85° Base Spread Cone (Tighter in ADS / Push-Pull Brace)
	var spread_deg = BASE_SPREAD_DEGREES * brace_mult
	var spread_rad = deg_to_rad(spread_deg)

	var hit_targets: Dictionary = {}  # target -> cumulative dmg_factor from all pellets
	var space_state = get_world_3d().direct_space_state if is_inside_tree() else null

	# Fire 12-Pellet Spread Array (wider cone covers pigeon flocks, center pellet hits crosshair)
	for i in range(pellet_count):
		# Pellet 0 goes straight down the crosshair; others disperse in cone
		var offset_x = 0.0
		var offset_y = 0.0
		if i > 0:
			var circle_angle = randf() * TAU
			var circle_radius = sqrt(randf()) * spread_rad
			offset_x = cos(circle_angle) * circle_radius
			offset_y = sin(circle_angle) * circle_radius

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
				# 0-18m: 100% | 18-55m: Linear Decay | 55m+: 10% Minimum
				var dmg_factor: float = 1.0
				if hit_dist <= DAMAGE_DROP_FULL_RANGE:
					dmg_factor = 1.0
				elif hit_dist <= DAMAGE_DROP_MAX_RANGE:
					var progress = (hit_dist - DAMAGE_DROP_FULL_RANGE) / (DAMAGE_DROP_MAX_RANGE - DAMAGE_DROP_FULL_RANGE)
					dmg_factor = lerp(1.0, DAMAGE_DROP_MIN_THRESHOLD, progress)
				else:
					dmg_factor = DAMAGE_DROP_MIN_THRESHOLD

				gun_fired.emit(collider, result.position)

				# Accumulate pellet hits per target (all pellets that land on same pigeon stack up)
				if collider:
					if collider in hit_targets:
						hit_targets[collider] += dmg_factor
					else:
						hit_targets[collider] = dmg_factor

		# Spawn visible high-velocity bullet tracer
		if tracer_scene and is_inside_tree():
			var tracer = tracer_scene.instantiate() as BulletTracer
			var target_parent = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
			target_parent.add_child(tracer)
			tracer.setup(spawn_muzzle_pos, target_end_point)

	# Apply accumulated damage to all targets hit this shot
	for target in hit_targets:
		_apply_damage_to_target(target, hit_targets[target])

func _apply_damage_to_target(target: Object, total_dmg_factor: float) -> void:
	# total_dmg_factor is the SUM of all pellet hits on this target this shot.
	# 1 pellet at full range  = 1.0
	# 12 pellets all landing  = up to 12.0 (close range group kill)
	# Any value >= 0.5 is lethal to a pigeon.
	# Drones require 2 hits total to destroy; pellet count helps here too.

	var hits_equivalent: int = max(1, int(total_dmg_factor))  # how many pellets worth landed
	var effective_drone_damage: int = clamp(hits_equivalent, 1, 2)

	if target.has_method("take_hit"):
		if target is PackageDrone:
			target.take_hit(effective_drone_damage)
		else:
			# Pigeon dies if total pellet impact >= 0.5 (i.e. even 1 pellet at close range)
			# At longer range multiple pellets must stack before kill threshold is met
			if total_dmg_factor >= 0.5:
				target.take_hit()
	elif target.get_parent() and target.get_parent().has_method("take_hit"):
		var p = target.get_parent()
		if p is PackageDrone:
			p.take_hit(effective_drone_damage)
		else:
			if total_dmg_factor >= 0.5:
				p.take_hit()
