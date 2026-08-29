extends Node3D
class_name PlayerController

signal weapon_switched(slot: int, weapon_name: String, ammo: int)
signal ammo_updated(weapon_name: String, ammo: int)

@export var camera: Camera3D
@export var gun: Node3D
@export var shotgun: Node3D
@export var missile_launcher: Node3D

@export var mouse_sensitivity_hip: float = 0.15
@export var mouse_sensitivity_ads: float = 0.07
@export var hip_fov: float = 75.0
@export var ads_fov: float = 45.0
@export var ads_speed: float = 14.0

# Weapon swap animation tunables
@export var holster_duration: float = 0.10    # How long the old weapon slides down
@export var draw_duration: float = 0.14       # How long the new weapon rises up
@export var swap_drop_amount: float = 0.12    # How far (Y) weapon dips when holstering

var pitch: float = 0.0
var yaw: float = 0.0
var mouse_delta: Vector2 = Vector2.ZERO
var is_aiming: bool = false
var current_slot: int = 0 # 0 = Gun, 1 = Shotgun, 2 = Rocket

# Internal swap state
var _is_swapping: bool = false
var _swap_timer: float = 0.0
var _swap_phase: int = 0  # 0 = holster, 1 = draw
var _pending_slot: int = -1
var _swap_offset: float = 0.0  # Y offset applied to current weapon during anim

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if not camera and has_node("Camera3D"):
		camera = $Camera3D

	if not gun and has_node("Camera3D/Gun"):
		gun = $Camera3D/Gun
	if not shotgun and has_node("Camera3D/Shotgun"):
		shotgun = $Camera3D/Shotgun
	if not missile_launcher and has_node("Camera3D/MissileLauncher"):
		missile_launcher = $Camera3D/MissileLauncher

	# Initialize weapon camera references
	if gun and "camera" in gun:
		gun.camera = camera
	if shotgun and "camera" in shotgun:
		shotgun.camera = camera
	if missile_launcher and "camera" in missile_launcher:
		missile_launcher.camera = camera

	# Connect ammo change signals
	if shotgun and shotgun.has_signal("ammo_changed"):
		shotgun.ammo_changed.connect(func(a): ammo_updated.emit("SHOTGUN", a))
	if missile_launcher and missile_launcher.has_signal("ammo_changed"):
		missile_launcher.ammo_changed.connect(func(a): ammo_updated.emit("ROCKET", a))

	# Equip initial primary weapon (Gun)
	_do_switch_to_slot(0) # Skip animation on first equip

func _unhandled_input(event: InputEvent) -> void:
	if is_inside_tree() and get_tree() and get_tree().paused:
		return

	# ESC Key toggles mouse mode
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	# Re-capture mouse on left click if cursor was visible
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	# FPS Mouse Rotation (Always active across all weapons)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_delta = event.relative
		var sensitivity = mouse_sensitivity_ads if is_aiming else mouse_sensitivity_hip
		yaw -= event.relative.x * sensitivity
		pitch -= event.relative.y * sensitivity

		# Clamp rotation so player cannot look behind
		yaw = clamp(yaw, -90.0, 90.0)
		pitch = clamp(pitch, -75.0, 75.0)

		if camera:
			camera.rotation_degrees = Vector3(pitch, yaw, 0.0)

	# Number Keys for direct weapon selection
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			switch_to_slot(0)
		elif event.keycode == KEY_2:
			switch_to_slot(1)
		elif event.keycode == KEY_3:
			switch_to_slot(2)
		elif event.keycode == KEY_R and not event.echo:
			var active = get_active_weapon()
			if active and active.has_method("start_reload"):
				active.start_reload()

	# Mouse Wheel Weapon Cycling
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_weapon(1)


func _process(delta: float) -> void:
	if is_inside_tree() and get_tree() and get_tree().paused:
		return

	is_aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	# Camera FOV Zoom for Aiming (ADS)
	if camera:
		var target_fov = ads_fov if is_aiming else hip_fov
		camera.fov = lerp(camera.fov, target_fov, delta * ads_speed)

	# Pass aim and mouse delta to active weapon
	var active_wep = get_active_weapon()
	if active_wep:
		if "is_aiming" in active_wep:
			active_wep.is_aiming = is_aiming
		if "mouse_delta" in active_wep:
			active_wep.mouse_delta = mouse_delta

	mouse_delta = mouse_delta.lerp(Vector2.ZERO, delta * 12.0)

	# Weapon swap animation tick
	_tick_swap_anim(delta)

func _tick_swap_anim(delta: float) -> void:
	if not _is_swapping:
		return

	_swap_timer -= delta

	if _swap_phase == 0:
		# Phase 0: Holster — smoothly push current weapon down off screen
		var t = clamp(1.0 - (_swap_timer / holster_duration), 0.0, 1.0)
		_swap_offset = _ease_in(t) * swap_drop_amount
		_apply_swap_offset(get_active_weapon(), _swap_offset)

		if _swap_timer <= 0.0:
			# Mid-swap: hide current, show next, snap to draw-from position
			_apply_swap_offset(get_active_weapon(), 0.0)
			_do_switch_to_slot(_pending_slot)
			# Snap new weapon to below-frame start
			_snap_weapon_to_draw_start(get_active_weapon())
			_swap_phase = 1
			_swap_timer = draw_duration
	else:
		# Phase 1: Draw — new weapon rises into hip position
		var t = clamp(1.0 - (_swap_timer / draw_duration), 0.0, 1.0)
		_swap_offset = (1.0 - _ease_out(t)) * swap_drop_amount
		_apply_swap_offset(get_active_weapon(), _swap_offset)

		if _swap_timer <= 0.0:
			_apply_swap_offset(get_active_weapon(), 0.0)
			_is_swapping = false

func _snap_weapon_to_draw_start(wep: Node3D) -> void:
	if not wep:
		return
	# Snap it below view so it rises up during draw phase
	var base_pos = wep.position
	base_pos.y -= swap_drop_amount
	wep.position = base_pos

func _apply_swap_offset(wep: Node3D, y_offset: float) -> void:
	if not wep:
		return
	# Add the swap drop offset on top of the weapon's current hip/ads base position
	# We do this by adjusting position.y directly; each weapon's _process handles sway/recoil
	# We store the base and just override the y offset
	wep.position.y += y_offset

func _ease_in(t: float) -> float:
	return t * t

func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

func cycle_weapon(dir: int) -> void:
	var new_slot = (current_slot + dir) % 3
	if new_slot < 0:
		new_slot = 2
	switch_to_slot(new_slot)

func switch_to_slot(slot: int) -> void:
	if slot == current_slot and not _is_swapping:
		return
	if _is_swapping and slot == _pending_slot:
		return

	# If already swapping, snap instantly to pending then queue new
	if _is_swapping:
		_apply_swap_offset(get_active_weapon(), 0.0)
		_do_switch_to_slot(_pending_slot)

	# Start holster phase
	_pending_slot = slot
	_is_swapping = true
	_swap_phase = 0
	_swap_timer = holster_duration
	_swap_offset = 0.0

	# Lock weapon input immediately
	var cur_wep = get_active_weapon()
	if cur_wep and "is_active" in cur_wep:
		cur_wep.is_active = false

func _do_switch_to_slot(slot: int) -> void:
	current_slot = slot

	# Hide all weapons
	if gun:
		gun.visible = false
		if "is_active" in gun:
			gun.is_active = false
	if shotgun:
		shotgun.visible = false
		if "is_active" in shotgun:
			shotgun.is_active = false
	if missile_launcher:
		missile_launcher.visible = false
		if "is_active" in missile_launcher:
			missile_launcher.is_active = false

	var wep_name = "GUN"
	var ammo_val = 999

	match slot:
		0:
			if gun:
				gun.visible = true
				if "is_active" in gun:
					gun.is_active = true
			wep_name = "GUN"
			ammo_val = -1 # Infinite
		1:
			if shotgun:
				shotgun.visible = true
				if "is_active" in shotgun:
					shotgun.is_active = true
				if "ammo" in shotgun:
					ammo_val = shotgun.ammo
			wep_name = "SHOTGUN"
		2:
			if missile_launcher:
				missile_launcher.visible = true
				if "is_active" in missile_launcher:
					missile_launcher.is_active = true
				if "ammo" in missile_launcher:
					ammo_val = missile_launcher.ammo
				if missile_launcher.has_method("on_equipped"):
					missile_launcher.on_equipped()
			wep_name = "ROCKET"

	weapon_switched.emit(slot, wep_name, ammo_val)

func get_active_weapon() -> Node3D:
	match current_slot:
		0:
			return gun
		1:
			return shotgun
		2:
			return missile_launcher
	return null

func add_recoil(pitch_kick: float, yaw_kick: float) -> void:
	pitch = clamp(pitch + pitch_kick, -75.0, 75.0)
	yaw = clamp(yaw + yaw_kick, -90.0, 90.0)
	if camera:
		camera.rotation_degrees = Vector3(pitch, yaw, 0.0)

func add_rocket_ammo(count: int) -> void:
	if missile_launcher and "ammo" in missile_launcher:
		missile_launcher.ammo += count
		if missile_launcher.has_method("on_ammo_added"):
			missile_launcher.on_ammo_added()
		ammo_updated.emit("ROCKET", missile_launcher.ammo)

func add_shotgun_ammo(count: int) -> void:
	if shotgun and "ammo" in shotgun:
		if shotgun.has_method("add_shells"):
			shotgun.add_shells(count)
		else:
			shotgun.ammo += count
		if shotgun.has_method("on_ammo_added"):
			shotgun.on_ammo_added()
		ammo_updated.emit("SHOTGUN", shotgun.ammo)
