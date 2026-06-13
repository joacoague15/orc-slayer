# scripts/shockwave_ring.gd
# Onda expansiva del pisotón del boss. Crece desde un centro fijo; cuando su
# frente cruza la posición del jugador, lo mata (player.die() respeta i-frames/dash).
# Pasado el jugador o fuera de radio máximo, es inofensiva.
#
# Visual: halo ancho + anillo principal + núcleo blanco brillante en el frente,
# para que el borde LETAL se lea claro durante toda la expansión. Al completar
# el radio hace un fade-out corto en lugar de desaparecer de golpe.
extends Node2D

var max_radius: float = 260.0
var expand_time: float = 0.6
var line_width: float = 9.0
var ring_color: Color = Color(1.5, 0.62, 0.3, 0.9)
var lethal: bool = true
var start_delay: float = 0.0
var ease_out: bool = true     # true: arranca rápido y frena (FX). false: LINEAL (muro constante)

const FADE_OUT_TIME := 0.14   # desvanecimiento tras completar la expansión

var _elapsed: float = 0.0
var _radius: float = 0.0
var _prev_radius: float = 0.0
var _player: Node2D = null
var _embers: CPUParticles2D = null   # brasas crepitando sobre el frente letal

func setup(center: Vector2, p_max_radius: float, p_expand_time: float, p_delay: float, p_color: Color, p_lethal: bool, p_ease_out: bool = true) -> void:
	global_position = center
	max_radius = p_max_radius
	expand_time = p_expand_time
	start_delay = p_delay
	ring_color = p_color
	lethal = p_lethal
	ease_out = p_ease_out
	_elapsed = -p_delay

func _ready() -> void:
	z_index = 1   # en el piso, detrás de las unidades
	_player = get_tree().get_first_node_in_group("player")
	if lethal:
		_spawn_embers()

func _spawn_embers() -> void:
	# Brasas que crepitan a lo largo de todo el frente: junto al rojo y el pulso,
	# la onda se lee inequívocamente como PELIGRO y no como decoración.
	_embers = CPUParticles2D.new()
	_embers.amount = 70
	_embers.lifetime = 0.35
	_embers.local_coords = true   # el centro es fijo: el anillo de emisión sigue al frente
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_embers.emission_sphere_radius = 1.0
	_embers.spread = 180.0
	_embers.gravity = Vector2.ZERO
	_embers.initial_velocity_min = 25.0
	_embers.initial_velocity_max = 85.0
	_embers.scale_amount_min = 1.5
	_embers.scale_amount_max = 3.5
	_embers.color = Color(2.2, 0.9, 0.3, 1.0)
	_embers.z_index = 2
	add_child(_embers)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.0:
		return  # esperando su turno (ondas escalonadas)

	var t: float = clampf(_elapsed / expand_time, 0.0, 1.0)
	_prev_radius = _radius
	# Ease-out para bursts de FX; lineal para ondas letales lentas (velocidad
	# constante = el jugador puede leer y planear el cruce con dash).
	_radius = ((1.0 - pow(1.0 - t, 2.0)) if ease_out else t) * max_radius
	if is_instance_valid(_embers):
		_embers.emission_sphere_radius = maxf(_radius, 1.0)
		if t >= 1.0:
			_embers.emitting = false
	queue_redraw()

	# Letal: si el frente del anillo barrió al jugador este frame, muere.
	if lethal and is_instance_valid(_player) and _player.has_method("die"):
		var d := _player.global_position.distance_to(global_position)
		if _prev_radius < d and d <= _radius:
			_player.die()

	if _elapsed >= expand_time + FADE_OUT_TIME:
		queue_free()

func _draw() -> void:
	if _elapsed < 0.0 or _radius <= 0.0:
		return
	var t: float = clampf(_elapsed / expand_time, 0.0, 1.0)
	# El frente se mantiene visible casi hasta el final (es letal todo el camino)
	# y recién se apaga del todo en el fade-out posterior a la expansión.
	var alpha := 1.0 - t * 0.45
	if _elapsed > expand_time:
		alpha *= 1.0 - clampf((_elapsed - expand_time) / FADE_OUT_TIME, 0.0, 1.0)

	# Más segmentos cuanto más grande el anillo (las ondas cubren la ronda entera).
	var segs := clampi(int(_radius / 12.0), 32, 96)
	# El frente letal LATE (pulso rápido de grosor): se lee vivo y peligroso.
	var w := line_width * (1.0 + 0.22 * sin(_elapsed * 24.0)) if lethal else line_width

	# Halo exterior suave → anillo principal → núcleo blanco del frente.
	var halo := ring_color
	halo.a *= alpha * 0.3
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, segs, halo, w * 2.4)

	var col := ring_color
	col.a *= alpha
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, segs, col, w)

	var core := Color(1.9, 1.8, 1.5, alpha * 0.85 * ring_color.a)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, segs, core, w * 0.4)
