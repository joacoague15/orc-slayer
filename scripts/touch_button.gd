# scripts/touch_button.gd
# Botón táctil circular (dash). Solo dibuja y guarda su estado de presión; la
# detección de toque la hace touch_controls.gd (arbitraje de multitouch).
extends Control

@export var label_text: String = "DASH"
@export var idle_color: Color = Color(1, 1, 1, 0.12)
@export var pressed_color: Color = Color(1.0, 0.85, 0.35, 0.5)
@export var ring_color: Color = Color(1, 1, 1, 0.32)
@export var font_size: int = 30

var _pressed: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_pressed(v: bool) -> void:
	_pressed = v
	queue_redraw()

func contains_point(global_pos: Vector2) -> bool:
	# Círculo real (no el rect cuadrado del control) para no robar toques de las esquinas.
	var c := global_position + size * 0.5
	return global_pos.distance_to(c) <= minf(size.x, size.y) * 0.5

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, pressed_color if _pressed else idle_color)
	draw_arc(c, r, 0.0, TAU, 40, ring_color, 3.0)
	var f := ThemeDB.fallback_font
	var ts := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(f, c - ts * 0.5 + Vector2(0.0, ts.y * 0.32), label_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, ring_color)
