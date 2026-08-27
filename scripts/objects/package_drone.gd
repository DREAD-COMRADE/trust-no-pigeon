extends Area3D
class_name PackageDrone

signal drone_destroyed(rocket_ammo: int, shotgun_ammo: int)

@export var speed: float = 9.0
@export var max_health: int = 2
@export var rocket_ammo_reward: int = 3
@export var shotgun_ammo_reward: int = 4

@onready var visual: Node3D = $Visual
@onready var rotors: Node3D = $Visual/Rotors if has_node("Visual/Rotors") else null
@onready var beacon_light: OmniLight3D = $Visual/BeaconLight if has_node("Visual/BeaconLight") else null

var health: int = 2
var start_pos: Vector3
var target_pos: Vector3
var time_alive: float = 0.0
var is_destroyed: bool = false
var explosion_scene: PackedScene = preload("res://scenes/effects/GovernmentPigeonHit.tscn")

func _ready() -> void:
	add_to_group("drones")
	add_to_group("targets")
	health = max_health

func setup(from: Vector3, to: Vector3, rockets: int = 3, shells: int = 4) -> void:
	start_pos = from
	target_pos = to
	rocket_ammo_reward = rockets
	shotgun_ammo_reward = shells
	health = max_health

	if is_inside_tree():
		global_position = from
	else:
		position = from

func _process(delta: float) -> void:
	if is_destroyed or (get_tree() and get_tree().paused):
		return

	time_alive += delta

	# Spin rotors fast
	if rotors:
		rotors.rotation.y += delta * 35.0

	# Blink beacon strobe light
	if beacon_light:
		beacon_light.light_energy = 8.0 if int(time_alive * 5.0) % 2 == 0 else 0.5

	# Bobbing and flight forward
	var cur_pos = global_position if is_inside_tree() else position
	var dir = (target_pos - cur_pos).normalized()
	if dir != Vector3.ZERO and is_inside_tree():
		look_at(cur_pos + dir, Vector3.UP)

	cur_pos += dir * speed * delta
	cur_pos.y += sin(time_alive * 2.0) * 0.02

	if is_inside_tree():
		global_position = cur_pos
	else:
		position = cur_pos

	if cur_pos.distance_to(target_pos) < 2.0:
		queue_free()

func take_hit(damage: int = 1) -> void:
	if is_destroyed:
		return

	health -= damage

	# First hit effect (sparks / smoke)
	if health > 0:
		if beacon_light:
			beacon_light.light_color = Color(1.0, 0.2, 0.1, 1.0)
			beacon_light.light_energy = 15.0

		var camera = get_viewport().get_camera_3d() if get_viewport() else null
		if camera and camera.has_method("add_trauma"):
			camera.add_trauma(0.12)

		if explosion_scene and is_inside_tree():
			var fx = explosion_scene.instantiate()
			get_tree().root.add_child(fx)
			fx.global_position = global_position if is_inside_tree() else position
		return

	# Fatal hit (drone destroyed)
	is_destroyed = true

	var camera = get_viewport().get_camera_3d() if get_viewport() else null
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.25)

	if explosion_scene and is_inside_tree():
		var fx = explosion_scene.instantiate()
		get_tree().root.add_child(fx)
		fx.global_position = global_position if is_inside_tree() else position

	# Award player ammo
	var main = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
	if main:
		var player_ctrl = main.find_child("Player", true, false)
		if player_ctrl:
			if player_ctrl.has_method("add_rocket_ammo"):
				player_ctrl.add_rocket_ammo(rocket_ammo_reward)
			if player_ctrl.has_method("add_shotgun_ammo"):
				player_ctrl.add_shotgun_ammo(shotgun_ammo_reward)

		var hud = main.find_child("HUD", true, false)
		if hud and hud.has_method("show_event_banner"):
			hud.show_event_banner("SUPPLY SECURED: +%d ROCKETS, +%d SHOTGUN" % [rocket_ammo_reward, shotgun_ammo_reward])

	drone_destroyed.emit(rocket_ammo_reward, shotgun_ammo_reward)
	if is_inside_tree():
		queue_free()
