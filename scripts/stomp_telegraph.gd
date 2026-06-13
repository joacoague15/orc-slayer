# scripts/stomp_telegraph.gd
# Telegraph del PISOTÓN del Warlord. Reemplaza al disco plano por:
# - Zona de peligro: disco rojo tenue + borde pulsante que se intensifica.
# - Anillo CONTRACTOR: parte del borde y se cierra lineal hacia el centro;
#   cuando llega, cae el pisotón. Timer honesto y legible.
# - Marcas radiales rotando en el borde: "impacto inminente".
# Al impactar, el boss llama a burst(): flash del área y fade-out rápido.
extends Node2D

var radius: float = 300.0
var duration: float = 0.5

var _elapsed: float = 0.0
var _bursting: bool = false

func setup(p_radius: float, p_duration: float) -> void:
	radius = p_radius
	duration = p_duration

func _ready() -> void:
	z_index = 1   # en el piso, debajo de las unidades

func _physics_process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()

func burst() -> void:
	# Impacto: flash del área completa y desvanecimiento rápido.
	_bursting = true
	set_physics_process(false)
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_callback(queue_free)

func _draw() -> void:
	if _bursting:
		draw_circle(Vector2.ZERO, radius, Color(1.8, 0.55, 0.28, 0.22))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(2.0, 0.7, 0.35, 0.8), 4.0)
		return

	var t := clampf(_elapsed / duration, 0.0, 1.0)
	var fade_in := clampf(_elapsed / (duration * 0.25), 0.0, 1.0)

	# Zona de peligro tenue.
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.14, 0.08, 0.10 * fade_in))

	# Borde pulsante que gana intensidad con la carga.
	var pulse := 0.6 + 0.4 * sin(_elapsed * 20.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64,
			Color(1.9, 0.3, 0.12, (0.3 + 0.5 * t) * pulse * fade_in), 3.0)

	# Anillo contractor: cuando llega al centro, cae el pisotón.
	var r := radius * (1.0 - t)
	if r > 4.0:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(2.0, 0.5, 0.22, 0.85 * fade_in), 3.5)

	# Marcas radiales cortas rotando en el borde.
	for i in range(8):
		var a := TAU * float(i) / 8.0 + _elapsed * 1.2
		var dirv := Vector2(cos(a), sin(a))
		draw_line(dirv * (radius - 14.0), dirv * radius, Color(1.8, 0.4, 0.18, 0.5 * fade_in), 2.0)
