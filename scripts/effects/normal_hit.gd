extends Node3D

@export var duration: float = 0.5
var timer: float = 0.0

@onready var particles: GPUParticles3D = $GPUParticles3D if has_node("GPUParticles3D") else null
@onready var death_sound: AudioStreamPlayer3D = $DeathSound

func _ready() -> void:
	if particles:
		particles.emitting = true
	
	if death_sound:
		death_sound.play()

func _process(delta: float) -> void:
	timer += delta
	if timer >= duration:
		queue_free()
