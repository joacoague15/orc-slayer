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

const FADE_OUT_TIME := 0.14   # desvanecimiento tras completar la expansión

var _elapsed: float = 0.0
var _radius: float = 0.0
var _prev_radius: float = 0.0
var _player: Node2D = null

func setup(center: Vector2, p_max_radius: float, p_expand_time: float, p_delay: float, p_color: Color, p_lethal: bool) -> void:
	global_position = center
	max_radius = p_max_radius
	expand_time = p_expand_time
	start_delay = p_delay
	ring_color = p_color
	lethal = p_lethal
	_elapsed = -p_delay

func _ready() -> void:
	z_index = 1   # en el piso, detrás de las unidades
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.0:
		return  # esperando su turno (ondas escalonadas)

	var t: float = clampf(_elapsed / expand_time, 0.0, 1.0)
	_prev_radius = _radius
	_radius = (1.0 - pow(1.0 - t, 2.0)) * max_radius   # ease-out
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

	# Halo exterior suave → anillo principal → núcleo blanco del frente.
	var halo := ring_color
	halo.a *= alpha * 0.3
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, halo, line_width * 2.4)

	var col := ring_color
	col.a *= alpha
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, col, line_width)

	var core := Color(1.9, 1.8, 1.5, alpha * 0.85 * ring_color.a)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, core, line_width * 0.4)
