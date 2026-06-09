# scripts/ground_rain.gd
# Lluvia que sigue a la cámara: gotas pesadas que caen del cielo y, al tocar el
# suelo, dejan una onda de impacto.
#
# Diseño para NO molestar al jugador: todo se dibuja en z -8 (detrás de orcos y
# del jugador, por encima del suelo), con trazos finos y semitransparentes. Las
# gotas se reciclan dentro del rect de la cámara, así llueve en toda la vista
# sin importar dónde esté el jugador.
extends Node2D

@export var rain_enabled: bool = true

@export_group("Gotas que caen")
@export var drop_count: int = 240                 # gotas en vuelo a la vez (área = pantalla completa)
@export var drop_fall_height_min: float = 60.0    # altura del trazo de caída (px de mundo)
@export var drop_fall_height_max: float = 110.0
@export var drop_fall_time_min: float = 0.12      # cuánto tarda en caer (corto: lluvia rápida)
@export var drop_fall_time_max: float = 0.20
@export var drop_length_min: float = 34.0         # largo del trazo (gota pesada = trazo largo)
@export var drop_length_max: float = 58.0
@export var drop_thickness: float = 4.0           # grosor del trazo
@export var drop_wind: float = 22.0               # desplazamiento horizontal durante la caída
@export var drop_color: Color = Color(0.62, 0.74, 0.86, 0.42)

@export_group("Ondas de impacto")
@export var impact_chance: float = 0.35           # fracción de gotas que dejan onda (el resto solo cae)
@export var active_impact_cap: int = 280
@export var impact_lifetime_min: float = 0.22
@export var impact_lifetime_max: float = 0.5
@export var impact_radius_min: float = 2.0
@export var impact_radius_max: float = 7.0
@export var impact_color: Color = Color(0.55, 0.65, 0.75, 0.28)
@export var splash_wind: Vector2 = Vector2(10.0, 4.0)

@export var rain_area_padding: float = 96.0

var drops: Array[Dictionary] = []
var impacts: Array[Dictionary] = []

func _ready() -> void:
	z_index = -8

func _process(delta: float) -> void:
	if not rain_enabled:
		return

	var rect := _get_spawn_rect()
	_update_drops(delta, rect)
	_update_impacts(delta)
	queue_redraw()

# === Gotas ===

func _update_drops(delta: float, rect: Rect2) -> void:
	# Mantener la cantidad objetivo de gotas en vuelo.
	while drops.size() < drop_count:
		# randomize_age = true reparte las fases iniciales para que no caigan todas juntas.
		drops.append(_create_drop(rect, true))
	while drops.size() > drop_count:
		drops.pop_back()

	for drop in drops:
		drop.age += delta
		if drop.age >= drop.fall_time:
			# La gota tocó el suelo: solo una fracción deja onda (el piso no se
			# satura) y se recicla dentro del rect actual.
			if randf() < impact_chance:
				_spawn_impact(drop.landing)
			_reset_drop(drop, rect, false)

func _create_drop(rect: Rect2, randomize_age: bool) -> Dictionary:
	var drop := {}
	_reset_drop(drop, rect, randomize_age)
	return drop

func _reset_drop(drop: Dictionary, rect: Rect2, randomize_age: bool) -> void:
	drop.landing = Vector2(
		randf_range(rect.position.x, rect.position.x + rect.size.x),
		randf_range(rect.position.y, rect.position.y + rect.size.y)
	)
	drop.fall_time = randf_range(drop_fall_time_min, drop_fall_time_max)
	drop.fall_height = randf_range(drop_fall_height_min, drop_fall_height_max)
	drop.length = randf_range(drop_length_min, drop_length_max)
	drop.wind = drop_wind * randf_range(0.6, 1.2)
	drop.age = randf_range(0.0, drop.fall_time) if randomize_age else 0.0

func _get_spawn_rect() -> Rect2:
	# El nodo vive dentro del SubViewport low-res (426x240) pero la cámara está
	# alejada (zoom < 1), así que en ese viewport entran ~1280x720 unidades de
	# mundo. El área visible real en unidades de mundo es viewport_size / zoom;
	# sin dividir por el zoom la lluvia solo cubriría ~1/3 del centro.
	var center := global_position
	var zoom := Vector2.ONE
	var camera := get_viewport().get_camera_2d()
	if camera:
		center = camera.global_position
		zoom = camera.zoom

	var world_size := get_viewport_rect().size / zoom

	return Rect2(
		center - world_size * 0.5 - Vector2.ONE * rain_area_padding,
		world_size + Vector2.ONE * rain_area_padding * 2.0
	)

# === Ondas de impacto ===

func _spawn_impact(impact_position: Vector2) -> void:
	if impacts.size() >= active_impact_cap:
		impacts.pop_front()
	impacts.append({
		"position": impact_position,
		"age": 0.0,
		"lifetime": randf_range(impact_lifetime_min, impact_lifetime_max),
		"max_radius": randf_range(impact_radius_min, impact_radius_max),
		"satellite_count": randi_range(0, 2),
		"satellite_offset": splash_wind.rotated(randf_range(-0.7, 0.7)) * randf_range(0.4, 1.3),
	})

func _update_impacts(delta: float) -> void:
	for i in range(impacts.size() - 1, -1, -1):
		impacts[i].age += delta
		if impacts[i].age >= impacts[i].lifetime:
			impacts.remove_at(i)

# === Dibujo ===

func _draw() -> void:
	_draw_drops()
	_draw_impacts()

func _draw_drops() -> void:
	for drop in drops:
		var progress: float = clamp(drop.age / drop.fall_time, 0.0, 1.0)
		# La gota arranca arriba (y hacia el lado del viento) y baja hasta el landing.
		var start: Vector2 = drop.landing + Vector2(-drop.wind, -drop.fall_height)
		var pos: Vector2 = start.lerp(drop.landing, progress)
		# Dirección de caída para orientar el trazo (la cola queda detrás, hacia arriba).
		var fall_dir: Vector2 = (drop.landing - start).normalized()
		var tail: Vector2 = pos - fall_dir * drop.length

		# Fade-in rápido al entrar y fade-out al impactar, para que no aparezcan/corten de golpe.
		var alpha: float = drop_color.a * clamp(progress * 4.0, 0.0, 1.0) * (1.0 - progress * 0.35)
		var color := Color(drop_color.r, drop_color.g, drop_color.b, alpha)
		draw_line(to_local(tail), to_local(pos), color, drop_thickness)

func _draw_impacts() -> void:
	for impact in impacts:
		var progress: float = clamp(impact.age / impact.lifetime, 0.0, 1.0)
		var radius: float = impact.max_radius * (0.35 + progress * 0.65)
		var alpha: float = impact_color.a * (1.0 - progress)
		var color := Color(impact_color.r, impact_color.g, impact_color.b, alpha)
		var local_pos: Vector2 = to_local(impact.position)

		draw_arc(local_pos, radius, 0.0, TAU, 14, color, 1.0)

		for i in range(impact.satellite_count):
			var satellite_progress := float(i + 1) / float(impact.satellite_count + 1)
			var satellite_pos: Vector2 = local_pos + impact.satellite_offset * satellite_progress
			draw_circle(satellite_pos, max(radius * 0.18, 1.0), color)
