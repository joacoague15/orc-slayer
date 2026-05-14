# scripts/ground_variations.gd
extends Node2D

@export var tile_variations: Array[Texture2D] = []
@export var variation_count: int = 200
@export var area_size: float = 4000.0
@export var tile_size: float = 64.0  # tamaño visual de cada tile

func _ready() -> void:
	_spawn_variations()

func _spawn_variations() -> void:
	if tile_variations.is_empty():
		return
	
	for i in range(variation_count):
		var sprite := Sprite2D.new()
		# Elegir una textura random de las variaciones
		sprite.texture = tile_variations.pick_random()
		# Posición random dentro del área
		sprite.position = Vector2(
			randf_range(-area_size, area_size),
			randf_range(-area_size, area_size)
		)
		# Alinear a la grilla de tiles (opcional, queda más prolijo)
		sprite.position = sprite.position.snapped(Vector2(tile_size, tile_size))
		sprite.z_index = -9  # arriba de GroundBase pero debajo de todo lo demás
		add_child(sprite)
