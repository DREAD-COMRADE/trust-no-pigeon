extends Node3D

@export var duration: float = 0.6
var timer: float = 0.0

@onready var light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null
@onready var particles: GPUParticles3D = $GPUParticles3D if has_node("GPUParticles3D") else null
@onready var flash_mesh: MeshInstance3D = $FlashMesh if has_node("FlashMesh") else null
@onready var explosion_sound: AudioStreamPlayer3D = $ExplosionSound if has_node("ExplosionSound") else null

func _ready() -> void:
	add_to_group("effects")
	if particles:
		particles.emitting = true
	
	if explosion_sound:
		explosion_sound.play()

func _process(delta: float) -> void:
	timer += delta
	if light:
		light.light_energy = lerp(light.light_energy, 0.0, delta * 10.0)
	if flash_mesh:
		flash_mesh.scale += Vector3.ONE * delta * 5.0

	if timer >= duration:
		queue_free()
