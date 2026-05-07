# scripts/blood_splat.gd
extends Node2D

@export var splat_count_min: int = 10
@export var splat_count_max: int = 25
@export var splat_size_min: float = 2.5
@export var splat_size_max: float = 9.0

# Velocidad y distancia (más disparado)
@export var fly_speed_min: float = 700.0
@export var fly_speed_max: float = 500.0
@export var fly_duration_min: float = 0.25
@export var fly_duration_max: float = 0.55

# Trail: cada gota deja una "cola" de N puntos detrás
@export var trail_length: int = 4
@export var trail_segment_min: float = 4.0  # distancia mínima entre puntos del trail

# Forma: las gotas se elongan en dirección del movimiento
@export var stretch_factor: float = 3.5  # cuánto se estira en dirección del movimiento

@export var fade_after: float = 8.0
@export var fade_duration: float = 4.0

@export var directional_spread: float = 0.6

var droplets: Array = []
var splat_color: Color

func setup(base_color: Color) -> void:
	# Charco asentado: gotas lentas, cortas, en todas direcciones
	_setup_internal(base_color, Vector2.ZERO, true, 30.0, 100.0, 0.15, 0.3)

func setup_directional(base_color: Color, direction: Vector2) -> void:
	# Splash direccional: gotas rápidas, largas, en la dirección dada
	_setup_internal(base_color, direction.normalized(), false, fly_speed_min, fly_speed_max, fly_duration_min, fly_duration_max)

func _setup_internal(base_color: Color, direction: Vector2, all_directions: bool, speed_min: float, speed_max: float, dur_min: float, dur_max: float) -> void:
	splat_color = base_color.darkened(0.5)
	splat_color.a = 0.9
	
	var count := randi_range(splat_count_min, splat_count_max)
	var base_angle := direction.angle() if not all_directions else 0.0
	var spread_radians := directional_spread * PI
	
	for i in range(count):
		var angle: float
		if all_directions:
			angle = randf() * TAU
		else:
			angle = base_angle + randf_range(-spread_radians / 2.0, spread_radians / 2.0)
		
		var droplet_radius := randf_range(splat_size_min, splat_size_max)
		var droplet_duration := randf_range(dur_min, dur_max)
		var droplet_speed := randf_range(speed_min, speed_max)
		var distance := droplet_speed * droplet_duration
		var direction_vec := Vector2(cos(angle), sin(angle))
		
		var droplet := {
			"position": Vector2.ZERO,
			"start": Vector2.ZERO,
			"target": direction_vec * distance,
			"radius": droplet_radius,
			"time": 0.0,
			"duration": droplet_duration,
			"done": false,
			"direction": direction_vec,
			"trail_points": [],
		}
		droplets.append(droplet)
	
	set_process(true)
	queue_redraw()
	
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
		var eased := 1.0 - pow(1.0 - t, 3.0)
		var new_pos: Vector2 = droplet.start.lerp(droplet.target, eased)
		
		# Agregar al trail si nos movimos suficiente desde el último punto
		if droplet.trail_points.is_empty() or new_pos.distance_to(droplet.trail_points[-1]) >= trail_segment_min:
			droplet.trail_points.append(new_pos)
			# Limitar el trail a N puntos
			if droplet.trail_points.size() > trail_length:
				droplet.trail_points.pop_front()
		
		droplet.position = new_pos
		
		if t >= 1.0:
			droplet.done = true
		else:
			any_animating = true
	queue_redraw()
	if not any_animating:
		set_process(false)

func _draw() -> void:
	for droplet in droplets:
		# Dibujar trail (gotitas más chicas atrás)
		for i in range(droplet.trail_points.size()):
			var trail_pos: Vector2 = droplet.trail_points[i]
			# Las gotas del trail se hacen más chicas hacia atrás
			var trail_factor: float = float(i + 1) / float(droplet.trail_points.size())
			var trail_radius: float = droplet.radius * trail_factor * 0.7
			var trail_color := splat_color
			trail_color.a = splat_color.a * trail_factor * 0.6
			draw_circle(trail_pos, trail_radius, trail_color)
		
		# Dibujar la gota principal estirada en dirección del movimiento
		_draw_elongated_droplet(droplet.position, droplet.direction, droplet.radius)

func _draw_elongated_droplet(pos: Vector2, direction: Vector2, radius: float) -> void:
	# Una gota estirada se aproxima dibujando 3 círculos: principal + dos extensiones
	# La elongación va en la dirección del movimiento
	var stretch_offset: Vector2 = direction * radius * (stretch_factor - 1.0) * 0.5
	# Círculo central (cabeza de la gota, más grande)
	draw_circle(pos + stretch_offset * 0.5, radius, splat_color)
	# Círculo del medio
	draw_circle(pos, radius * 0.85, splat_color)
	# Círculo de la cola (más chico)
	draw_circle(pos - stretch_offset * 0.7, radius * 0.6, splat_color)
