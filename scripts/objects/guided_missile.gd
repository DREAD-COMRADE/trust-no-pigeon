extends Area3D
class_name GuidedMissile

signal missile_detonated(hit_ufo: bool)

@export var speed: float = 36.0
@export var turn_speed: float = 10.0
@export var max_lifetime: float = 7.5
@export var ufo_proximity_radius: float = 4.8

@onready var visual: Node3D = $Visual
@onready var thrust_light: OmniLight3D = $ThrustLight if has_node("ThrustLight") else null
@onready var smoke_trail: GPUParticles3D = $SmokeTrail if has_node("SmokeTrail") else null

var trail_audio: AudioStreamPlayer3D
var trail_sound_stream: AudioStream = preload("res://assets/Audio/Missile_trail.mp3")

var target_aim_point: Vector3
var time_alive: float = 0.0
var has_detonated: bool = false
var explosion_scene: PackedScene = preload("res://scenes/effects/GovernmentPigeonPlayerExplosion.tscn")

func _ready() -> void:
	time_alive = 0.0
	add_to_group("missiles")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Setup looping missile flight sound
	if trail_sound_stream:
		trail_audio = AudioStreamPlayer3D.new()
		trail_audio.stream = trail_sound_stream
		trail_audio.volume_db = 4.0
		trail_audio.unit_size = 15.0
		trail_audio.autoplay = true
		add_child(trail_audio)

func _physics_process(delta: float) -> void:
	if has_detonated or (get_tree() and get_tree().paused):
		return

	time_alive += delta
	if time_alive >= max_lifetime:
		_detonate(false)
		return

	# Query Camera Aim Direction & Target Lock
	var camera = get_viewport().get_camera_3d() if get_viewport() else null
	if camera and camera.is_inside_tree():
		var cam_pos = camera.global_position
		var cam_dir = -camera.global_transform.basis.z
		target_aim_point = cam_pos + cam_dir * 120.0

		# Raycast from camera crosshair
		var space_state = get_world_3d().direct_space_state if is_inside_tree() else null
		if space_state:
			var query = PhysicsRayQueryParameters3D.create(cam_pos, target_aim_point)
			query.collide_with_areas = true
			query.collide_with_bodies = true
			var cam_hit = space_state.intersect_ray(query)
			if cam_hit:
				target_aim_point = cam_hit.position

		# Check for UFO aim assist / homing guidance
		var ufos = get_tree().get_nodes_in_group("ufo") if (is_inside_tree() and get_tree()) else []
		for ufo in ufos:
			if is_instance_valid(ufo) and ufo.is_inside_tree() and ufo.get("current_state") != UFO.State.DESTROYED:
				var ufo_pos = ufo.global_position
				var to_ufo = ufo_pos - cam_pos
				var proj = to_ufo.dot(cam_dir)
				if proj > 0:
					var closest_cam_point = cam_pos + cam_dir * proj
					if closest_cam_point.distance_to(ufo_pos) < 12.0:
						target_aim_point = ufo_pos
						break
	else:
		target_aim_point = global_position - global_transform.basis.z * 50.0

	# Steer rocket towards target aim point
	var cur_pos = global_position if is_inside_tree() else position
	var to_target = (target_aim_point - cur_pos).normalized()
	if to_target.length_squared() > 0.01:
		var current_fwd = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
		var new_fwd = current_fwd.lerp(to_target, delta * turn_speed).normalized()
		var up = Vector3.UP
		if abs(new_fwd.dot(up)) > 0.98:
			up = Vector3.RIGHT
		if is_inside_tree():
			global_transform = global_transform.looking_at(cur_pos + new_fwd, up)

	# 1. Proximity Check for UFO
	if is_inside_tree() and get_tree():
		var ufos = get_tree().get_nodes_in_group("ufo")
		for ufo in ufos:
			if is_instance_valid(ufo) and ufo.is_inside_tree() and ufo.get("current_state") != UFO.State.DESTROYED:
				if cur_pos.distance_to(ufo.global_position) <= ufo_proximity_radius:
					_handle_hit_target(ufo)
					return

		# Proximity Check for Drones
		var drones = get_tree().get_nodes_in_group("drones")
		for drone in drones:
			if is_instance_valid(drone) and drone.is_inside_tree() and not drone.get("is_destroyed"):
				if cur_pos.distance_to(drone.global_position) <= 2.8:
					_handle_hit_target(drone)
					return

	# 2. Continuous Raycast Step Check
	var move_dist = speed * delta
	var from_pos = cur_pos
	var fwd_vec = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
	var to_pos = from_pos + fwd_vec * move_dist

	var space_state = get_world_3d().direct_space_state if is_inside_tree() else null
	if space_state:
		var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var hit = space_state.intersect_ray(query)
		if hit:
			if is_inside_tree():
				global_position = hit.position
			else:
				position = hit.position
			_handle_hit_target(hit.collider)
			return

	if is_inside_tree():
		global_position = to_pos
	else:
		position = to_pos

	# Thruster flicker
	if thrust_light:
		thrust_light.light_energy = randf_range(4.0, 8.0)

func _on_area_entered(area: Area3D) -> void:
	if has_detonated or area == self:
		return
	_handle_hit_target(area)

func _on_body_entered(body: Node) -> void:
	if has_detonated or body == self:
		return
	_handle_hit_target(body)

func _handle_hit_target(hit_obj: Object) -> void:
	if has_detonated:
		return

	var is_ufo_hit = false

	if hit_obj:
		if hit_obj is UFO or (hit_obj.has_method("is_in_group") and hit_obj.is_in_group("ufo")):
			is_ufo_hit = true
			if hit_obj.has_method("take_missile_hit"):
				hit_obj.take_missile_hit()
			elif hit_obj.has_method("take_hit"):
				hit_obj.take_hit()
		elif hit_obj.has_method("take_hit"):
			hit_obj.take_hit()
		elif hit_obj.get_parent() and hit_obj.get_parent().has_method("take_hit"):
			if hit_obj.get_parent() is UFO:
				is_ufo_hit = true
				hit_obj.get_parent().take_missile_hit()
			else:
				hit_obj.get_parent().take_hit()

	_detonate(is_ufo_hit)

func _detonate(hit_ufo: bool) -> void:
	if has_detonated:
		return
	has_detonated = true

	if trail_audio and is_instance_valid(trail_audio):
		trail_audio.stop()

	# Smoothly detach smoke trail so existing puffs finish fading
	if smoke_trail and is_inside_tree() and get_tree():
		smoke_trail.emitting = false
		var target_parent = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
		var trail_pos = smoke_trail.global_position
		remove_child(smoke_trail)
		target_parent.add_child(smoke_trail)
		smoke_trail.global_position = trail_pos
		get_tree().create_timer(0.8).timeout.connect(func():
			if is_instance_valid(smoke_trail):
				smoke_trail.queue_free()
		)

	var camera = get_viewport().get_camera_3d() if get_viewport() else null
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.5 if hit_ufo else 0.25)

	if explosion_scene and is_inside_tree():
		var fx = explosion_scene.instantiate()
		var target_parent = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root
		target_parent.add_child(fx)
		fx.global_position = global_position if is_inside_tree() else position

	missile_detonated.emit(hit_ufo)
	if is_inside_tree():
		queue_free()
