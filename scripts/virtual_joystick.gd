# scripts/virtual_joystick.gd
# Joystick virtual de origen dinámico: la base aparece donde el dedo toca dentro
# de la región del control y el nub la sigue, clampeado a max_radius. Es un
# componente "tonto": no escucha input por sí mismo (lo arbitra touch_controls.gd
# para resolver el multitouch sin que dos sticks se peleen el mismo dedo).
extends Control

@export var max_radius: float = 95.0       # px de recorrido máximo del nub
@export var deadzone: float = 0.2          # fracción del radio ignorada (centro muerto)
@export var base_color: Color = Color(1, 1, 1, 0.10)
@export var ring_color: Color = Color(1, 1, 1, 0.22)
@export var nub_color: Color = Color(1, 1, 1, 0.32)

var output: Vector2 = Vector2.ZERO         # -1..1 por eje; ZERO dentro del deadzone
var is_active: bool = false

var _origin: Vector2 = Vector2.ZERO        # local (donde tocó el dedo)
var _current: Vector2 = Vector2.ZERO       # local (posición actual del dedo, clampeada)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # touch_controls.gd maneja el input

func begin(global_pos: Vector2) -> void:
	is_active = true
	_origin = global_pos - global_position
	_current = _origin
	_recompute()
	queue_redraw()

func update_drag(global_pos: Vector2) -> void:
	_current = global_pos - global_position
	_recompute()
	queue_redraw()

func end() -> void:
	is_active = false
	output = Vector2.ZERO
	queue_redraw()

func _recompute() -> void:
	var d := _current - _origin
	var dist := d.length()
	if dist > max_radius:
		d = d / dist * max_radius
		_current = _origin + d
	var raw := d / max_radius
	output = Vector2.ZERO if raw.length() < deadzone else raw

func _draw() -> void:
	if not is_active:
		return
	draw_circle(_origin, max_radius, base_color)
	draw_arc(_origin, max_radius, 0.0, TAU, 48, ring_color, 3.0)
	draw_circle(_current, max_radius * 0.42, nub_color)
