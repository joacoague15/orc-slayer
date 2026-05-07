# scripts/slice_effect.gd
extends Area2D

@export var lifetime: float = 0.15
@export var max_kill_distance: float = 80.0  # cap de seguridad

@onready var visual: Polygon2D = $Polygon2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D:
		return
	if not body.is_in_group("orcs"):
		return
	if not body.has_method("die"):
		return
	
	var dist := global_position.distance_to(body.global_position)
	if dist > max_kill_distance:
		return
	
	body.die()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("orcs"):
		var dist := global_position.distance_to(area.global_position)
		if dist > max_kill_distance:
			return
		area.die()
