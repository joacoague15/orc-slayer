# scripts/corpse.gd
extends Node2D
class_name Corpse

@export var lifetime: float = 90.0
@export var fade_duration: float = 5.0

# Empuje: el cuerpo se desliza un toque en la dirección del slice antes de quedarse quieto
@export var push_distance: float = 35.0
@export var push_duration: float = 0.18

@onready var visual: ColorRect = $ColorRect

# Para identificar al cuerpo en la escena (el cap usa esto)
var spawn_time: float = 0.0

func setup(base_color: Color, base_scale: Vector2, push_direction: Vector2, blood_splat_scene: PackedScene = null) -> void:
	# Color más oscuro para diferenciarlo de un orco vivo
	visual.color = base_color.darkened(0.5)
	# Misma escala que el orco que murió
	scale = base_scale
	
	# Spawn time para el cap de cuerpos
	spawn_time = Time.get_ticks_msec() / 1000.0
	
	# Empuje visual en dirección del slice
	var target_pos := position + push_direction.normalized() * push_distance
	var push_tween := create_tween()
	push_tween.tween_property(self, "position", target_pos, push_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Cuando el cuerpo se queda quieto, generamos el charco final si nos pasaron la escena
	if blood_splat_scene:
		push_tween.tween_callback(_spawn_resting_blood.bind(blood_splat_scene, base_color))
	
	# Lifetime: dura 90 segundos, después fade out de 5 segundos
	await get_tree().create_timer(lifetime - fade_duration).timeout
	if not is_instance_valid(self):
		return
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	fade_tween.tween_callback(queue_free)

func _spawn_resting_blood(splat_scene: PackedScene, base_color: Color) -> void:
	if not is_instance_valid(self):
		return
	var splat := splat_scene.instantiate()
	splat.position = global_position
	splat.z_index = -2
	get_parent().add_child(splat)
	if splat.has_method("setup"):
		splat.setup(base_color)

func force_fade_out() -> void:
	# Llamado desde el cap: hace fade rápido y se libera
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
