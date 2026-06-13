# scripts/cleave_telegraph.gd
# Telegraph del CLEAVE del Warlord. Reemplaza al abanico plano por un telegraph
# profesional de tres capas:
# - Zona de peligro: cono rojo tenue (el área total del golpe).
# - Relleno de carga LINEAL desde el centro: cuando el frente brillante alcanza
#   el borde, cae el golpe. Timer honesto y legible (mismo criterio que la onda
#   del pisotón: lineal = se puede leer y planear).
# - Borde del cono pulsante que se intensifica a medida que se acerca el golpe.
# Forward local = +Y (igual que _make_wedge del boss); el boss lo rota a committed_rot.
extends Node2D

var reach: float = 230.0
var half_arc: float = 1.2
var duration: float = 0.38

var _elapsed: float = 0.0

func setup(p_reach: float, p_half_arc: float, p_duration: float) -> void:
	reach = p_reach
	half_arc = p_half_arc
	duration = p_duration

func _ready() -> void:
	z_index = 1   # en el piso, debajo de las unidades

func _physics_process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()

func _wedge_points(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var segs := 24
	for i in range(segs + 1):
		var a := lerpf(PI / 2.0 - half_arc, PI / 2.0 + half_arc, float(i) / float(segs))
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _draw() -> void:
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	var fade_in := clampf(_elapsed / (duration * 0.2), 0.0, 1.0)

	# Zona total del golpe: rojo tenue.
	draw_colored_polygon(_wedge_points(reach), Color(1.0, 0.12, 0.07, 0.11 * fade_in))

	# Relleno de carga: avanza lineal del centro al borde, con frente brillante.
	if t > 0.02:
		draw_colored_polygon(_wedge_points(reach * t), Color(1.5, 0.16, 0.08, 0.26 * fade_in))
		draw_arc(Vector2.ZERO, reach * t, PI / 2.0 - half_arc, PI / 2.0 + half_arc,
				32, Color(2.0, 0.45, 0.25, 0.85 * fade_in), 3.0)

	# Borde del cono: pulso rápido que gana intensidad con la carga.
	var pulse := 0.65 + 0.35 * sin(_elapsed * 22.0)
	var rim := Color(1.9, 0.25, 0.12, (0.35 + 0.5 * t) * pulse * fade_in)
	draw_arc(Vector2.ZERO, reach, PI / 2.0 - half_arc, PI / 2.0 + half_arc, 40, rim, 2.5)
	var e1 := Vector2(cos(PI / 2.0 - half_arc), sin(PI / 2.0 - half_arc)) * reach
	var e2 := Vector2(cos(PI / 2.0 + half_arc), sin(PI / 2.0 + half_arc)) * reach
	draw_line(Vector2.ZERO, e1, rim, 2.5)
	draw_line(Vector2.ZERO, e2, rim, 2.5)
