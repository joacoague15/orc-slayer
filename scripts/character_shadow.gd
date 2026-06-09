# scripts/character_shadow.gd
# Sombra elíptica negra semitransparente bajo un personaje VIVO, para separarlo
# del suelo y de los cadáveres. Va como hija del CharacterBody (no del sprite que
# rota), así queda centrada y quieta bajo la unidad en la vista top-down.
#
# Se auto-oculta cuando el personaje muere (lee `is_dead` del padre, que comparten
# player.gd y orc.gd + herederos), así los cadáveres NO tienen sombra: la sombra
# es una señal de "esta unidad está viva".
extends Node2D

@export var shadow_radius: float = 58.0          # radio en unidades de mundo
@export var shadow_squash: float = 0.4           # achatado vertical (elipse)
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.42)

func _ready() -> void:
	# El achatado se logra con la escala vertical del nodo (draw_circle -> elipse).
	scale = Vector2(1.0, shadow_squash)
	queue_redraw()

func _process(_delta: float) -> void:
	var parent := get_parent()
	if parent and parent.get("is_dead"):
		hide()
		set_process(false)  # ya es cadáver: no hace falta seguir chequeando

func _draw() -> void:
	draw_circle(Vector2.ZERO, shadow_radius, shadow_color)
