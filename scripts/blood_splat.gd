# scripts/blood_splat.gd
extends Node2D

@export var splat_count_min: int = 8
@export var splat_count_max: int = 16
@export var splat_size_min: float = 3.0
@export var splat_size_max: float = 10.0
@export var pool_size_multiplier: float = 1.45

# Velocidad y distancia (más disparado)
@export var fly_speed_min: float = 700.0
@export var fly_speed_max: float = 500.0
@export var fly_duration_min: float = 0.25
@export var fly_duration_max: float = 0.55

# Trail: cada gota deja una "cola" de N puntos detrás
@export var trail_length: int = 3
@export var trail_segment_min: float = 6.0  # distancia mínima entre puntos del trail

# Forma: las gotas se elongan en dirección del movimiento
@export var stretch_factor: float = 3.5  # cuánto se estira en dirección del movimiento

@export var fade_after: float = 8.0
@export var fade_duration: float = 4.0

@export var directional_spread: float = 0.6
@export var pixel_grid_size: float = 3.0

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
		if all_directions:
			droplet_radius *= pool_size_multiplier
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
			"blob_index": randi() % BLOB_VARIANTS,
			"is_pool": all_directions,
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
		var new_pos: Vector2 = _snap_vector(droplet.start.lerp(droplet.target, eased))
		
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

# Cache estático: texturas pixeladas compartidas por todos los blood_splat.
static var pixel_blob_textures: Array[ImageTexture] = []
const TEXTURE_SIZE: int = 16
const BLOB_VARIANTS: int = 8

static func _get_pixel_blob_texture(index: int) -> ImageTexture:
	if pixel_blob_textures.is_empty():
		_generate_pixel_blob_textures()
	
	return pixel_blob_textures[index % pixel_blob_textures.size()]

static func _generate_pixel_blob_textures() -> void:
	for variant in range(BLOB_VARIANTS):
		var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		var center := Vector2(TEXTURE_SIZE / 2.0, TEXTURE_SIZE / 2.0)
		var radius_x := 5.6 + float(variant % 3) * 0.8
		var radius_y := 5.0 + float((variant + 1) % 3) * 0.7
		var notch_angle := float(variant) * TAU / float(BLOB_VARIANTS)
		var notch_dir := Vector2(cos(notch_angle), sin(notch_angle))
		var bulge_dir := notch_dir.rotated(PI * 0.72)
		
		for x in range(TEXTURE_SIZE):
			for y in range(TEXTURE_SIZE):
				var p := Vector2(float(x), float(y)) - center
				var ellipse_value := (p.x * p.x) / (radius_x * radius_x) + (p.y * p.y) / (radius_y * radius_y)
				var edge_noise := 0.14 * sin(float(x * 3 + variant * 5)) + 0.12 * cos(float(y * 4 - variant * 2))
				var notch := p.normalized().dot(notch_dir) > 0.72 and p.length() > 4.6
				var bulge := p.normalized().dot(bulge_dir) > 0.78 and p.length() < 7.2
				
				if ellipse_value <= 1.0 + edge_noise and not notch:
					img.set_pixel(x, y, Color.WHITE)
				elif bulge:
					img.set_pixel(x, y, Color.WHITE)
		
		pixel_blob_textures.append(ImageTexture.create_from_image(img))

func _draw() -> void:
	for droplet in droplets:
		var tex := _get_pixel_blob_texture(droplet.blob_index)
		var radius: float = _snap_float(droplet.radius)
		
		if droplet.is_pool:
			_draw_pixel_blob_textured(tex, droplet.position, radius, splat_color)
			_draw_pixel_blob_textured(tex, droplet.position + _snap_vector(droplet.direction * radius * 0.45), radius * 0.55, splat_color.darkened(0.12))
			continue
		
		# Trail
		for i in range(droplet.trail_points.size()):
			var trail_pos: Vector2 = droplet.trail_points[i]
			var trail_factor: float = float(i + 1) / float(droplet.trail_points.size())
			var trail_radius: float = _snap_float(radius * trail_factor * 0.62)
			var trail_color := splat_color.darkened(0.08)
			trail_color.a = splat_color.a * trail_factor * 0.58
			_draw_pixel_blob_textured(tex, trail_pos, trail_radius, trail_color)
		
		var stretch_offset: Vector2 = _snap_vector(droplet.direction * radius * (stretch_factor - 1.0) * 0.5)
		_draw_pixel_blob_textured(tex, droplet.position + stretch_offset * 0.5, radius, splat_color)
		_draw_pixel_blob_textured(tex, droplet.position - stretch_offset * 0.45, radius * 0.72, splat_color.darkened(0.1))

func _draw_pixel_blob_textured(tex: Texture2D, center: Vector2, radius: float, color: Color) -> void:
	var snapped_radius: float = maxf(_snap_float(radius), pixel_grid_size)
	var size: float = snapped_radius * 2.0
	var snapped_center := _snap_vector(center)
	var rect := Rect2(snapped_center.x - snapped_radius, snapped_center.y - snapped_radius, size, size)
	draw_texture_rect(tex, rect, false, color)

func _snap_vector(value: Vector2) -> Vector2:
	return Vector2(_snap_float(value.x), _snap_float(value.y))

func _snap_float(value: float) -> float:
	return round(value / pixel_grid_size) * pixel_grid_size

func _draw_elongated_droplet(pos: Vector2, direction: Vector2, radius: float) -> void:
	# Compatibilidad para pruebas desde el editor; el render principal usa blobs pixelados.
	var tex := _get_pixel_blob_texture(0)
	var stretch_offset: Vector2 = _snap_vector(direction * radius * (stretch_factor - 1.0) * 0.5)
	_draw_pixel_blob_textured(tex, pos + stretch_offset * 0.5, radius, splat_color)
	_draw_pixel_blob_textured(tex, pos - stretch_offset * 0.7, radius * 0.6, splat_color)
