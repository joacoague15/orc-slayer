# scripts/arcane_residue.gd
extends Node2D

@export var lifetime: float = 0.5

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)
