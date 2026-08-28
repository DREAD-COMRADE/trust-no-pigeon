extends Area3D
class_name UFO

signal ufo_destroyed
@warning_ignore("unused_signal")
signal ufo_escaped
signal ufo_damaged(remaining_health: int)


enum State { ENTERING, SHIELDED, SPAWNING, VULNERABLE, RECHARGING, DESTROYED }

@export var max_health: int = 3
@export var score_reward: int = 2500
@export var base_speed: float = 14.0

@onready var visual: Node3D = $Visual
@onready var dome_light: OmniLight3D = $Visual/DomeLight if has_node("Visual/DomeLight") else null
@onready var beam_light: SpotLight3D = $Visual/BeamLight if has_node("Visual/BeamLight") else null
@onready var shield_mesh: MeshInstance3D = $Visual/ShieldMesh if has_node("Visual/ShieldMesh") else null
@onready var hatch_door: MeshInstance3D = $Visual/HatchDoor if has_node("Visual/HatchDoor") else null

var health: int = 3
var current_state: State = State.ENTERING
var state_timer: float = 0.0
var time_alive: float = 0.0
var current_cycle: int = 1

var entry_target: Vector3 = Vector3(0.0, 18.5, -38.0)
var hover_origin: Vector3 = Vector3(0.0, 18.5, -38.0)

var explosion_scene: PackedScene = preload("res://scenes/effects/GovernmentPigeonPlayerExplosion.tscn")
var hit_spark_scene: PackedScene = preload("res://scenes/effects/GovernmentPigeonHit.tscn")
var gov_pigeon_scene: PackedScene = preload("res://scenes/pigeons/GovernmentPigeon_v2.tscn")

var shield_material: ShaderMaterial

func _ready() -> void:
	add_to_group("ufo")
	add_to_group("targets")
	health = max_health
	current_state = State.ENTERING

	if shield_mesh and shield_mesh.get_active_material(0) is ShaderMaterial:
		shield_material = shield_mesh.get_active_material(0) as ShaderMaterial

func setup(start_pos: Vector3, center_pos: Vector3, _duration: float = 40.0, start_health: int = 3) -> void:
	max_health = start_health
	health = start_health
	if is_inside_tree():
		global_position = start_pos
	else:
		position = start_pos
	entry_target = center_pos
	hover_origin = center_pos
	current_cycle = 1

func _process(delta: float) -> void:
	if get_tree() and get_tree().paused:
		return

	time_alive += delta

	# Saucer rotation
	if visual:
		visual.rotation.y += delta * (2.5 + float(current_cycle) * 0.5)

	# Light pulsing
	var pulse = (sin(time_alive * 5.0) + 1.0) * 0.5
	if dome_light:
		dome_light.light_energy = lerp(4.0, 12.0, pulse)
	if beam_light:
		beam_light.light_energy = lerp(3.0, 8.0, pulse)

	match current_state:
		State.ENTERING:
			_process_entering(delta)
		State.SHIELDED:
			_process_shielded(delta)
		State.SPAWNING:
			_process_spawning(delta)
		State.VULNERABLE:
			_process_vulnerable(delta)
		State.RECHARGING:
			_process_recharging(delta)
		State.DESTROYED:
			pass

func _process_entering(delta: float) -> void:
	_set_shield_visual(true, 1.0)
	var cur_pos = global_position if is_inside_tree() else position
	cur_pos = cur_pos.move_toward(entry_target, base_speed * delta * 1.5)
	if is_inside_tree():
		global_position = cur_pos

	if cur_pos.distance_to(entry_target) < 1.0:
		current_state = State.SHIELDED
		state_timer = 5.0 # Fly shielded for 5s before first spawn phase

func _process_shielded(delta: float) -> void:
	_set_shield_visual(true, 1.0)
	_move_hover_pattern(delta)

	state_timer -= delta
	if state_timer <= 0.0:
		start_spawning_phase()

func start_spawning_phase() -> void:
	current_state = State.SPAWNING
	state_timer = 2.0 # Spawning animation duration

	_notify_hud("⚠️ UFO OPENING HATCH - PREPARE ATTACK!")
	_spawn_surveillance_pigeons()

func _process_spawning(delta: float) -> void:
	# Shield flickers rapidly during hatch opening
	var flicker = (sin(time_alive * 35.0) + 1.0) * 0.5
	_set_shield_visual(true, flicker)

	# Hatch door opens downward
	if hatch_door:
		hatch_door.position.y = lerp(hatch_door.position.y, -1.8, delta * 5.0)

	state_timer -= delta
	if state_timer <= 0.0:
		start_vulnerable_phase()

func start_vulnerable_phase() -> void:
	current_state = State.VULNERABLE
	# Vulnerability window shrinks per cycle (3.5s -> 2.5s -> 1.8s)
	state_timer = max(1.8, 3.5 - float(current_cycle - 1) * 0.7)

	_notify_hud("🎯 UFO SHIELD DOWN! ATTACK NOW!")

func _process_vulnerable(delta: float) -> void:
	# Shield is completely OFF
	_set_shield_visual(false, 0.0)

	# Hatch door glows exposed warning red
	if dome_light:
		dome_light.light_color = Color(1.0, 0.2, 0.1, 1.0)

	state_timer -= delta
	if state_timer <= 0.0:
		start_recharging_phase()

func start_recharging_phase() -> void:
	current_state = State.RECHARGING
	state_timer = 1.5

	if dome_light:
		dome_light.light_color = Color(0.2, 0.9, 1.0, 1.0)

	_notify_hud("🛡️ UFO SHIELD RECHARGING...")

func _process_recharging(delta: float) -> void:
	# Shield flickers back ON
	var flicker = (sin(time_alive * 25.0) + 1.0) * 0.5
	_set_shield_visual(true, flicker)

	# Hatch door closes back up
	if hatch_door:
		hatch_door.position.y = lerp(hatch_door.position.y, -1.14, delta * 5.0)

	state_timer -= delta
	if state_timer <= 0.0:
		current_cycle += 1
		current_state = State.SHIELDED
		state_timer = max(4.0, 7.0 - float(current_cycle) * 0.8) # Shielded movement duration

func _move_hover_pattern(delta: float) -> void:
	# Speed increases per cycle
	var speed_mult = 1.0 + float(current_cycle - 1) * 0.25
	var offset_x = sin(time_alive * (0.8 * speed_mult)) * (14.0 + float(current_cycle) * 2.0)
	var offset_y = cos(time_alive * 1.6) * 2.5
	var offset_z = sin(time_alive * (1.2 * speed_mult)) * 6.0

	var target_pos = hover_origin + Vector3(offset_x, offset_y, offset_z)
	var cur_pos = global_position if is_inside_tree() else position
	cur_pos = cur_pos.lerp(target_pos, delta * 2.5 * speed_mult)

	if is_inside_tree():
		global_position = cur_pos

	if visual:
		visual.rotation.z = -sin(time_alive * 0.8) * 0.25
		visual.rotation.x = cos(time_alive * 1.2) * 0.15

func _spawn_surveillance_pigeons() -> void:
	if not gov_pigeon_scene or not is_inside_tree():
		return

	# Progressive pigeon count per cycle: Early = 2, Mid = 3-4, Late = 5-6
	var pigeon_count = min(6, 2 + (current_cycle - 1) * 2)
	var main = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_tree().root

	for i in range(pigeon_count):
		var pigeon = gov_pigeon_scene.instantiate() as PigeonBase
		if pigeon and main:
			main.add_child(pigeon)
			var offset = Vector3(randf_range(-4.0, 4.0), -2.0, randf_range(-4.0, 4.0))
			pigeon.global_position = global_position + offset

			# Direct attack mode: fly directly towards player to explode!
			if pigeon.has_method("start_attack"):
				pigeon.start_attack()

func take_hit(_damage: int = 1) -> void:
	# Small arms bullets deflect off shield with spark flare
	if current_state == State.SHIELDED or current_state == State.SPAWNING:
		if hit_spark_scene and is_inside_tree():
			var fx = hit_spark_scene.instantiate()
			var target_parent = get_tree().current_scene if get_tree() and get_tree().current_scene else get_tree().root
			target_parent.add_child(fx)
			fx.global_position = global_position

func take_missile_hit() -> void:
	if current_state == State.DESTROYED:
		return

	# If Shield is ON (SHIELDED or SPAWNING or RECHARGING): 0 DAMAGE & DEFLECT!
	if current_state == State.SHIELDED or current_state == State.SPAWNING or current_state == State.RECHARGING:
		_notify_hud("🛡️ ROCKET DEFLECTED! WAIT FOR SHIELD TO DROP!")
		if hit_spark_scene and is_inside_tree():
			var fx = hit_spark_scene.instantiate()
			var target_parent = get_tree().current_scene if get_tree() and get_tree().current_scene else get_tree().root
			target_parent.add_child(fx)
			fx.global_position = global_position
		return

	# Rocket hit during VULNERABLE state: TAKE DAMAGE!
	health -= 1

	var cam = get_viewport().get_camera_3d() if get_viewport() else null

	if health > 0:
		if dome_light:
			dome_light.light_energy = 35.0
			dome_light.light_color = Color(1.0, 0.1, 0.1, 1.0)

		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.5)

		_notify_hud("💥 DIRECT HIT ON UFO! [%d HITS LEFT]" % health)
		ufo_damaged.emit(health)
		return

	# Fatal rocket hit (UFO destroyed)
	current_state = State.DESTROYED
	_notify_hud("💥 UFO DESTROYED! +2500 PTS!")

	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.9)

	if explosion_scene and is_inside_tree():
		var fx = explosion_scene.instantiate()
		var target_parent = get_tree().current_scene if get_tree() and get_tree().current_scene else get_tree().root
		target_parent.add_child(fx)
		fx.global_position = global_position

	var main = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
	if main and main.has_node("Systems/ScoreManager"):
		var sm = main.get_node("Systems/ScoreManager")
		if sm and sm.has_method("add_score"):
			sm.add_score(score_reward, true)

	ufo_destroyed.emit()
	if is_inside_tree():
		queue_free()

func _set_shield_visual(active: bool, flicker_alpha: float = 1.0) -> void:
	if shield_mesh:
		shield_mesh.visible = active
	if shield_material:
		shield_material.set_shader_parameter("flicker_alpha", flicker_alpha if active else 0.0)

func _notify_hud(msg: String) -> void:
	var main = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
	if main:
		var hud = main.find_child("HUD", true, false)
		if hud and hud.has_method("show_event_banner"):
			hud.show_event_banner(msg)
