# scripts/blood_splat.gd
extends Node2D

@export var splat_count_min: int = 8
@export var splat_count_max: int = 14
@export var splat_size_min: float = 3.0
@export var splat_size_max: float = 8.0

@export var fly_speed_min: float = 80.0
@export var fly_speed_max: float = 250.0
@export var fly_duration_min: float = 0.2
@export var fly_duration_max: float = 0.45

@export var fade_after: float = 8.0
@export var fade_duration: float = 4.0

# Cada gota: posición actual, posición target, tiempo, radio, color
var droplets: Array = []
var splat_color: Color

func setup(base_color: Color) -> void:
	splat_color = base_color.darkened(0.5)
	splat_color.a = 0.85
	
	var count := randi_range(splat_count_min, splat_count_max)
	
	for i in range(count):
		var droplet := {
			"position": Vector2.ZERO,
			"start": Vector2.ZERO,
			"target": Vector2.ZERO,
			"radius": randf_range(splat_size_min, splat_size_max),
			"time": 0.0,
			"duration": randf_range(fly_duration_min, fly_duration_max),
			"done": false,
		}
		var angle := randf() * TAU
		var distance = randf_range(fly_speed_min, fly_speed_max) * droplet.duration
		droplet.target = Vector2(cos(angle), sin(angle)) * distance
		droplets.append(droplet)
	
	set_process(true)
	queue_redraw()
	
	# Fade out después de un rato
	await get_tree().create_timer(fade_after).timeout
	if not is_instance_valid(self):
		return
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	fade_tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	var any_animating := false
	for droplet in droplets:
		if droplet.done:
			continue
		droplet.time += delta
		var t: float = clamp(droplet.time / droplet.duration, 0.0, 1.0)
		# Ease out (decelera al final)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		droplet.position = droplet.start.lerp(droplet.target, eased)
		if t >= 1.0:
			droplet.done = true
		else:
			any_animating = true
	queue_redraw()
	if not any_animating:
		set_process(false)

func _draw() -> void:
	for droplet in droplets:
		draw_circle(droplet.position, droplet.radius, splat_color)
